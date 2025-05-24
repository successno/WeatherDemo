//
//  NetworkingService.swift
//  WeatherApp
//
//  Created by Star. on 2025/5/6.
//

import Foundation
import Combine

// 天气API可能出现的错误类型
enum WeatherAPIError: Error {
    case locationUnavailable //位置不可用
    case cityNotFound        // 城市未找到
    case invalidURL          // URL无效错误
    case decodingFailed      // 解码失败错误
    case networkError(Error) // 网络错误(包含具体错误信息)
    case networkUnavailable //天气模块错误
    case locationAuthorizationTimeout //超时
}


// 定义成功状态码范围
private let successStatusCodeRange = 200...299

class NetworkingService {
    // 单例实例
    static let shared = NetworkingService()
    
    // 请求缓冲字典，键为请求URL，值为上次请求时间
    private var requestBuffer: [String: Date] = [:]
    // 最小请求间隔（秒）
    private let minRequestInterval: TimeInterval = 2.0
    // 请求队列
    private let requestQueue = DispatchQueue(label: "com.weatherapp.networking", qos: .utility)
    // 正在进行的请求字典
    private var activeRequests: [String: Task<Data, Error>] = [:]
    // 最大并发请求数
    private let maxConcurrentRequests = 4
    // 请求信号量
    private let requestSemaphore: DispatchSemaphore
    // 网络会话配置
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: config)
    }()
    
    // 自定义枚举错误
    enum DataServiceError: LocalizedError {
        case badURLResponse(url: URL)
        case unknown
        case decodingError
        case networkError(Error)
        case requestThrottled
        
        var errorDescription: String? {
            switch self {
                case .badURLResponse(url: let url):
                    return "Bad response from URL: \(url)"
                case .unknown:
                    return "Unknown error occurred"
                case .decodingError:
                    return "Decoding error"
                case .networkError(let error):
                    return "Network error: \(error.localizedDescription)"
                case .requestThrottled:
                    return "请求过于频繁，请稍后再试"
            }
        }
    }
    
    // 检查响应状态码
    static func handleURLResponse(output: URLSession.DataTaskPublisher.Output, url: URL) throws -> Data {
        guard let httpResponse = output.response as? HTTPURLResponse else {
            print("非 HTTP 响应，URL: \(url)")
            throw NetworkingService.DataServiceError.badURLResponse(url: url)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            print("响应状态码异常，URL: \(url)，状态码: \(httpResponse.statusCode)")
            throw NetworkingService.DataServiceError.badURLResponse(url: url)
        }
        
        return output.data
    }
    
    // 静态下载方法
    static func downLoad(url: URL) -> AnyPublisher<Data, Error> {
        print("开始下载数据: \(url.absoluteString)")
        
        // 检查请求频率
        if let lastRequestTime = shared.requestBuffer[url.absoluteString] {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequestTime)
            if timeSinceLastRequest < shared.minRequestInterval {
                print("⏳ 请求过于频繁，等待 \(shared.minRequestInterval - timeSinceLastRequest) 秒")
                return Fail(error: DataServiceError.requestThrottled).eraseToAnyPublisher()
            }
        }
        
        return shared.session.dataTaskPublisher(for: url)
            .tryMap { output in
                // 更新请求时间
                shared.requestBuffer[url.absoluteString] = Date()
                let data = try handleURLResponse(output: output, url: url)
                return data
            }
            .receive(on: DispatchQueue.main)
            .mapError { error in
                print("网络请求失败: \(error.localizedDescription)")
                return error
            }
            .eraseToAnyPublisher()
    }
    
    // 发送网络请求（带缓冲和防重复）
    func fetchData(from url: URL) async throws -> Data {
        let urlString = url.absoluteString
        
        // 检查是否有相同的请求正在进行
        if let existingTask = activeRequests[urlString] {
            print("📡 复用已存在的请求: \(urlString)")
            return try await existingTask.value
        }
        
        // 检查请求频率
        if let lastRequestTime = requestBuffer[urlString] {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequestTime)
            if timeSinceLastRequest < minRequestInterval {
                print("⏳ 请求过于频繁，等待 \(minRequestInterval - timeSinceLastRequest) 秒")
                throw DataServiceError.requestThrottled
            }
        }
        
        // 等待信号量
        Task.detached(priority: .background) {
            self.requestSemaphore
        }
        
        // 创建新的请求任务
        let task = Task {
            defer {
                // 释放信号量
                requestSemaphore.signal()
            }
            
            do {
                print("🚀 发起新请求: \(urlString)")
                let (data, response) = try await session.data(from: url)
                let validatedData = try NetworkingService.handleURLResponse(output: (data, response), url: url)
                return validatedData
            } catch {
                print("❌ 请求失败: \(error.localizedDescription)")
                throw error
            }
        }
        
        // 记录活动请求
        activeRequests[urlString] = task
        
        do {
            let data = try await task.value
            // 更新请求时间
            requestBuffer[urlString] = Date()
            // 清理活动请求
            activeRequests.removeValue(forKey: urlString)
            return data
        } catch {
            // 清理活动请求
            activeRequests.removeValue(forKey: urlString)
            throw error
        }
    }
    
    // 批量请求方法
    func fetchMultipleData(from urls: [URL]) async throws -> [Data] {
        try await withThrowingTaskGroup(of: Data.self) { group in
            for url in urls {
                group.addTask {
                    try await self.fetchData(from: url)
                }
            }
            
            var results: [Data] = []
            for try await data in group {
                results.append(data)
            }
            return results
        }
    }
    
    // 清理过期的缓冲数据
    private func cleanupBuffer() {
        let now = Date()
        requestBuffer = requestBuffer.filter { _, timestamp in
            now.timeIntervalSince(timestamp) < 300 // 5分钟过期
        }
    }
    
    // 定期清理缓冲
    private func startBufferCleanup() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.cleanupBuffer()
        }
    }
    
    // 清理网络会话
    private func cleanupSession() {
        session.invalidateAndCancel()
        session = URLSession(configuration: session.configuration)
    }
    
    // 取消所有活动请求
    func cancelAllRequests() {
        activeRequests.values.forEach { $0.cancel() }
        activeRequests.removeAll()
    }
    
    private init() {
        requestSemaphore = DispatchSemaphore(value: maxConcurrentRequests)
        startBufferCleanup()
        // 定期清理网络会话
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.cleanupSession()
        }
    }
    
    deinit {
        cancelAllRequests()
        session.invalidateAndCancel()
    }
}
