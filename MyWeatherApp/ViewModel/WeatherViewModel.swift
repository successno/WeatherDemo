import Foundation
import Combine
import SwiftUI
import CoreLocation

/// 天气视图模型（核心业务逻辑类）
/// 职责：
/// 1. 管理天气数据的网络请求与缓存
/// 2. 监控网络状态并处理重试逻辑
/// 3. 同步数据状态至SwiftUI视图（通过@Published属性）
/// 4. 处理定位与地理编码相关逻辑
/// 遵循ObservableObject协议，用于SwiftUI视图的状态管理
/// @MainActor 保证所有方法在主线程执行，避免UI更新冲突

/// 天气业务错误枚举（本地化错误描述）
/// 包含定位、网络、数据解析等常见错误类型
enum WeatherError: Error, LocalizedError {
    case locationNotFound       // 定位失败（无位置信息）
    case invalidAdcode          // 无效的行政区划编码（adcode）
    case networkError           // 网络请求失败
    case dataParsingError       // 数据解析失败（格式错误）
    case cityNotFound           // 城市未找到（数据库无记录）
    case multipleErrors([String: WeatherError])  // 批量请求时的多错误集合
    
    /// 本地化错误描述（用于UI提示）
    var errorDescription: String? {
        switch self {
        case .locationNotFound:
            return "未找到该地区"
        case .invalidAdcode:
            return "无效的地区编码"
        case .networkError:
            return "网络错误，请检查网络连接"
        case .dataParsingError:
            return "数据解析错误"
        case .cityNotFound:
            return "城市未找到"
        case .multipleErrors(let errorDict):
            var errorMsg = "多个错误："
            for (city, error) in errorDict {
                errorMsg += "\(city): \(error.errorDescription ?? "未知错误"); "
            }
            return errorMsg
        }
    }
}

/// 数据加载状态枚举（用于视图状态同步）
/// Equatable协议支持视图根据状态变化刷新
enum DataStatus: Equatable {
    // 状态比较逻辑（避免默认合成的低效比较）
    static func == (lhs: DataStatus, rhs: DataStatus) -> Bool {
        switch (lhs, rhs) {
        case (.locationNotFound, .locationNotFound),
             (.invalidAdcode, .invalidAdcode),
             (.networkError, .networkError),
             (.dataParsingError, .dataParsingError),
             (.cityNotFound, .cityNotFound):
            return true
        default:
            return false
        }
    }
    
    case locationNotFound      // 定位失败状态
    case invalidAdcode         // adcode无效状态
    case networkError          // 网络错误状态
    case dataParsingError      // 数据解析错误状态
    case cityNotFound          // 城市未找到状态
    case initial    // 初始状态（未开始加载）
    case loading    // 加载中状态
    case success    // 加载成功状态
    case failure(WeatherError) // 加载失败状态（关联具体错误）
}

/// 定位权限状态枚举（用于定位功能状态管理）
enum LocationStatus {
    case authorized    // 已授权
    case notDetermined // 未决定（首次请求）
    case denied        // 被拒绝
    case unknown       // 未知状态
}

@MainActor class WeatherViewModel: ObservableObject {
    // MARK: - 共享实例
    /// 单例实例（线程安全）
    /// 使用静态属性保证全局唯一，适用于跨视图数据共享场景
    static let shared = WeatherViewModel()
    
    // MARK: - 发布属性（与视图绑定的状态）
    /// 当前城市天气数据（主展示数据）
    @Published var currentCityWeather: CityWeatherModel?
    /// 所有城市天气数据（键：城市名，值：天气模型）
    @Published var allCitiesWeather: [String: CityWeatherModel] = [:]
    /// 整体数据加载状态（控制加载提示/错误提示）
    @Published var dataStatus: DataStatus = .initial
    /// 实时数据加载状态（细分状态控制）
    @Published var liveDataStatus: DataStatus = .initial
    /// 未来数据加载状态（细分状态控制）
    @Published var futureDataStatus: DataStatus = .initial
    /// 当前网络连接状态（布尔值简化判断）
    @Published var isNetworkConnected = false
    /// 实时天气原始数据（来自API）
    @Published var weatherLiveData: WeatherLiveModel?
    /// 未来天气原始数据（来自API）
    @Published var weatherFutureData: WeatherFutureModel?
    /// 当前定位城市名称（用于UI显示）
    @Published var currentCity: String?
    /// 搜索结果列表（城市名数组）
    @Published var searchResults = [String]()
    /// 全局加载状态（控制加载动画）
    @Published var isLoading = false
    /// 全局错误对象（用于错误提示）
    @Published var error: Error?
    
    // MARK: - 网络状态相关属性（内部状态管理）
    /// 网络稳定计数器（连续成功检查次数）
    private var networkStableCount = 0
    /// 网络稳定判定阈值（需连续N次成功检查）
    private let requiredStableCount = 2  // 降低稳定要求到2次
    /// 当前网络是否稳定（核心判断条件）
    private var isNetworkStable = false
    /// 网络检查定时器（定期检测网络质量）
    private var networkCheckTimer: Timer?
    /// 上次网络检查时间（防频繁检查）
    private var lastNetworkCheckTime: Date?
    /// 网络检查时间间隔（1秒/次）
    private let networkCheckInterval: TimeInterval = 1.0  // 缩短检查间隔到1秒
    /// 当前重试次数（网络不稳定时使用）
    private var retryCount = 0
    /// 最大重试次数（超过则使用缓存）
    private let maxRetryCount = 5  // 增加重试次数
    /// 上次成功请求时间（用于超时重试）
    private var lastSuccessfulRequest: Date?
    /// 请求超时时间（10秒无响应则重试）
    private let requestTimeout: TimeInterval = 10.0  // 请求超时时间
    
    // MARK: - 数据存储相关属性（缓存管理）
    /// 天气数据缓存管理器（泛型实现，仅缓存CityWeatherModel）
    /// 键：城市名，值：CityWeatherModel实例
    private let cache = CacheManager<CityWeatherModel>()
    /// 上次请求的城市名（用于重试）
    private var lastRequestedCity: String?
    /// 当前正在执行的任务（用于取消旧任务）
    private var currentTask: Task<Void, Never>?
    /// 当前请求的完成回调（延迟执行）
    private var currentCompletion: ((Result<CityWeatherModel, WeatherError>) -> Void)?
    
    // MARK: - 私有属性（内部逻辑使用）
    /// 当前搜索文本（用于搜索结果过滤）
    private var searchText: String = ""
    /// Combine取消令牌集合（管理订阅生命周期）
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 定位相关属性（定位服务依赖）
    /// 定位管理器（系统定位服务）
    private let locationManager = CLLocationManager()
    /// 地理编码器（经纬度转地址）
    private let geocoder = CLGeocoder()
    
    // MARK: - 初始化与析构
    /// 初始化方法（首次创建时调用）
    /// 职责：
    /// 1. 启动网络监控
    /// 2. 加载本地缓存数据
    init() {
        setupNetworkMonitoring()
        loadCachedCities()
    }
    
    /// 析构方法（对象销毁时调用）
    /// 职责：
    /// 1. 停止网络检查定时器
    /// 2. 取消当前任务
    /// 3. 清理Combine订阅
    deinit {
        networkCheckTimer?.invalidate()
        networkCheckTimer = nil
        currentTask?.cancel()
        cancellables.removeAll()
    }
    
    // MARK: - 缓存操作
    /// 从本地加载已缓存的城市数据（初始化时调用）
    private func loadCachedCities() {
        self.allCitiesWeather = cache.getAllItems()
    }
    
    /// 获取指定城市的缓存数据
    /// - Parameter city: 城市名称
    /// - Returns: 缓存的CityWeatherModel实例（可能为nil）
    private func getCachedWeatherData(for city: String) -> CityWeatherModel? {
        return cache.getItem(forKey: city)
    }
    
    // MARK: - 核心数据获取（单城市）
    /// 获取指定城市的天气数据（核心方法）
    /// - Parameters:
    ///   - city: 目标城市名称
    ///   - completion: 异步回调（返回Result类型）
    func fetchWeatherData(for city: String, completion: @escaping (Result<CityWeatherModel, WeatherError>) -> Void) async {
        // 1. 优先使用缓存数据
        if let cachedModel = getCachedWeatherData(for: city) {
            print("🌐 [Network] 使用网络缓存数据 - 城市：\(city)")
            handleCachedData(cachedModel, city: city)
            completion(.success(cachedModel))
            return
        }
        
        // 2. 网络不稳定时的重试逻辑
        guard isNetworkStable else {
            print("❌ [Network] 网络不稳定，等待网络稳定后再请求")
            if retryCount < maxRetryCount {
                retryCount += 1
                print("🔄 [Network] 尝试重试 (\(retryCount)/\(maxRetryCount))")
                try? await Task.sleep(nanoseconds: 1_000_000_000)  // 等待1秒后重试
                return await fetchWeatherData(for: city, completion: completion)
            } else {
                retryCount = 0  // 重置重试计数
                if let cachedModel = getCachedWeatherData(for: city) {  // 重试失败后降级使用缓存
                    print("🌐 [Network] 使用网络缓存数据（重试失败后）- 城市：\(city)")
                    handleCachedData(cachedModel, city: city)
                    completion(.success(cachedModel))
                } else {
                    completion(.failure(.networkError))  // 无缓存时返回网络错误
                }
                return
            }
        }
        
        // 3. 取消旧任务并启动新任务
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self = self else { return }
            print("🌐 [Network] 开始获取天气数据 - 城市：\(city)")
            
            // 4. 基础校验（城市名不能为空）
            guard !city.isEmpty else {
                print("❌ [Network] 城市名称为空")
                completion(.failure(.locationNotFound))
                return
            }
            
            // 5. 记录当前请求状态
            lastRequestedCity = city
            currentCompletion = completion
            isLoading = true
            searchText = city
            
            // 6. 获取城市adcode（关键参数）
            guard let adcode = DatabaseManager.shared.getAdcode(forName: city) else {
                print("❌ [Network] 未找到城市\(city)的adcode")
                handleError(.cityNotFound, message: "未找到城市\(city)的adcode")
                return
            }
            print("✅ [Network] 获取到adcode：\(adcode)")
            
            // 7. 并行请求实时和未来天气数据
            do {
                print("🌐 [Network] 开始并行请求实时和未来天气数据...")
                async let liveResult = fetchLiveData(adcode: adcode)
                async let futureResult = fetchFutureData(adcode: adcode)
                
                let (liveData, futureData) = try await (liveResult.get(), futureResult.get())
                print("✅ [Network] 成功获取实时和未来天气数据")
                
                // 8. 任务取消检查
                if Task.isCancelled {
                    print("❌ [Network] 任务被取消")
                    return
                }
                
                // 9. 数据有效性校验（实时数据）
                guard let live = liveData.lives.first else {
                    print("❌ [Network] 实时天气数据为空")
                    throw WeatherError.dataParsingError
                }
                print("✅ [Network] 获取到实时天气数据：\(String(describing: live))")
                
                // 10. 数据有效性校验（未来数据）
                guard let future = futureData.forecasts.first?.casts else {
                    print("❌ [Network] 未来天气数据为空")
                    throw WeatherError.dataParsingError
                }
                print("✅ [Network] 获取到未来天气数据，数量：\(future.count)")
                
                // 11. 构建综合天气模型
                print("🌐 [Network] 开始构建CityWeatherModel...")
                let weatherModel = CityWeatherModel(
                    city: [city],
                    live: [live],
                    future: future
                )
                print("✅ [Network] CityWeatherModel构建成功")
                
                // 12. 更新本地缓存
                print("🌐 [Network] 开始更新缓存...")
                updateWeatherCache(city: city, weatherModel: weatherModel)
                print("✅ [Network] 缓存更新完成")
                
                // 13. 处理完整数据
                handleCompleteData(city: city, weatherModel: weatherModel)
                
            } catch {
                print("❌ [Network] 获取天气数据失败：\(error.localizedDescription)")
                handleError(.networkError, message: "获取天气数据失败")
            }
        }
    }
    
    // MARK: - 核心数据获取（批量城市）
    /// 批量获取多个城市的天气数据（最大并发3）
    /// - Parameters:
    ///   - cities: 城市名称数组
    ///   - completion: 异步回调（返回Result类型）
    func fetchWeatherData(for cities: [String], completion: @escaping (Result<Void, WeatherError>) -> Void) async {
        let maxConcurrent = 3  // 最大并发任务数
        var failedCities = [String: WeatherError]()  // 失败城市字典（城市名: 错误）
        var allResults: [(String, Result<CityWeatherModel, WeatherError>)] = []  // 所有结果数组
        var cityIterator = cities.makeIterator()  // 城市迭代器（用于任务补充）
        
        // 1. 启动任务组（控制并发）
        await withTaskGroup(of: (String, Result<CityWeatherModel, WeatherError>).self) { group in
            // 2. 初始化最大并发任务
            for _ in 0..<maxConcurrent {
                if let city = cityIterator.next() {
                    group.addTask { [weak self] in
                        guard let self = self else { return (city, .failure(.networkError)) }
                        return await withCheckedContinuation { continuation in
                            Task {
                                await self.fetchWeatherData(for: city) { result in
                                    continuation.resume(returning: (city, result))
                                }
                            }
                        }
                    }
                }
            }
            
            // 3. 任务完成后补充新任务
            for await result in group {
                allResults.append(result)
                if let city = cityIterator.next() {
                    group.addTask { [weak self] in
                        guard let self = self else { return (city, .failure(.networkError)) }
                        return await withCheckedContinuation { continuation in
                            Task {
                                await self.fetchWeatherData(for: city) { result in
                                    continuation.resume(returning: (city, result))
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // 4. 处理所有结果（更新全局数据/记录失败）
        for (city, result) in allResults {
            switch result {
            case .success(let weatherModel):
                self.allCitiesWeather[city] = weatherModel
            case .failure(let error):
                failedCities[city] = error
            }
        }
        
        // 5. 回调最终结果（成功或多错误）
        if failedCities.isEmpty {
            completion(.success(()))
        } else {
            completion(.failure(.multipleErrors(failedCities)))
        }
    }
    
    // MARK: - 缓存数据处理
    /// 处理缓存数据（同步至视图状态）
    /// - Parameters:
    ///   - cachedModel: 缓存的天气模型
    ///   - city: 城市名称
    private func handleCachedData(_ cachedModel: CityWeatherModel, city: String) {
        // 1. 同步实时天气数据到发布属性
        self.weatherLiveData = cachedModel.live.first.map { live in
            WeatherLiveModel(status: "1", count: "1", info: "OK", infocode: "10000", lives: [live])
        }
        // 2. 同步未来天气数据到发布属性
        self.weatherFutureData = WeatherFutureModel(
            status: "1", count: "1", info: "OK", infocode: "10000",
            forecasts: [WeatherFutureModel.ForecastData(
                city: city,
                adcode: DatabaseManager.shared.getAdcode(forName: city) ?? "",
                province: cachedModel.live.first?.province ?? "",
                reporttime: cachedModel.live.first?.reporttime ?? "",
                casts: cachedModel.future
            )]
        )
        self.currentCity = city
        self.isLoading = false
        currentCompletion?(.success(cachedModel))
    }
    
    // 处理新数据
    private func handleCompleteData(city: String, weatherModel: CityWeatherModel) {
        print("=== 开始处理完整数据 ===")
        print("城市：\(city)")
        print("实时天气数据：\(weatherModel.live.count) 条")
        print("未来天气数据：\(weatherModel.future.count) 条")
        
        self.currentCity = city
        self.isLoading = false
        self.allCitiesWeather[city] = weatherModel
        self.weatherLiveData = WeatherLiveModel(
            status: "1",
            count: "1",
            info: "OK",
            infocode: "10000",
            lives: weatherModel.live
        )
        self.weatherFutureData = WeatherFutureModel(
            status: "1",
            count: "1",
            info: "OK",
            infocode: "10000",
            forecasts: [WeatherFutureModel.ForecastData(
                city: city,
                adcode: DatabaseManager.shared.getAdcode(forName: city) ?? "",
                province: weatherModel.live.first?.province ?? "",
                reporttime: weatherModel.live.first?.reporttime ?? "",
                casts: weatherModel.future
            )]
        )
        currentCompletion?(.success(weatherModel))
        print("✅ 数据处理完成")
    }
    
    private func handleError(_ error: WeatherError, message: String) {
        print("错误：\(message)")
        self.error = error
        self.isLoading = false
        self.dataStatus = .failure(error)
        currentCompletion?(.failure(error))
    }
    
    // 更新缓存
    private func updateWeatherCache(city: String, weatherModel: CityWeatherModel) {
        cache.setItem(forKey: city, item: weatherModel)
        print("天气缓存已更新，城市：\(city)")
    }
    
    private func fetchLiveData(adcode: String) async -> Result<WeatherLiveModel, Error> {
        print("开始获取实时天气数据，adcode: \(adcode)")
        return await withCheckedContinuation { continuation in
            let cancellable = WeatherLiveData().getLivedata(location: adcode)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        if case let .failure(error) = completion {
                            print("❌ 实时天气数据请求失败: \(error.localizedDescription)")
                            continuation.resume(returning: .failure(error))
                        }
                    },
                    receiveValue: { [weak self] liveData in
                        print("✅ 实时天气数据请求成功")
                        print("数据内容：\(String(describing: liveData))")
                        print("lives数组数量：\(liveData.lives.count)")
                        if let firstLive = liveData.lives.first {
                            print("第一条数据：\(String(describing: firstLive))")
                        }
                        self?.weatherLiveData = liveData
                        continuation.resume(returning: .success(liveData))
                    }
                )
            // 存储取消令牌，防止内存泄漏
            self.cancellables.insert(cancellable)
        }
    }
    
    private func fetchFutureData(adcode: String) async -> Result<WeatherFutureModel, Error> {
        print("开始获取未来天气数据，adcode: \(adcode)")
        return await withCheckedContinuation { continuation in
            let cancellable = WeatherFutrueData().getFutruedata(location: adcode)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        if case let .failure(error) = completion {
                            print("❌ 未来天气数据请求失败: \(error.localizedDescription)")
                            continuation.resume(returning: .failure(error))
                        }
                    },
                    receiveValue: { [weak self] futureData in
                        print("✅ 未来天气数据请求成功")
                        print("数据内容：\(String(describing: futureData))")
                        print("forecasts数组数量：\(futureData.forecasts.count)")
                        if let firstForecast = futureData.forecasts.first {
                            print("第一条数据：\(String(describing: firstForecast))")
                            print("casts数组数量：\(firstForecast.casts.count)")
                        }
                        self?.weatherFutureData = futureData
                        continuation.resume(returning: .success(futureData))
                    }
                )
            cancellables.insert(cancellable)
        }
    }
    
    private func retryLocationRequest() async {
        guard let city = lastRequestedCity else { return }
            await fetchWeatherData(for: city) { [weak self] result in
                switch result {
                    case .success:
                        print("重试请求成功获取天气数据")
                    case .failure(let error):
                        print("重试请求失败，错误: \(error.localizedDescription)")
                        self?.handleError(error, message: "重试请求失败")
                }
            }
    }
    
    // MARK: - 缓存管理器（通用实现）
    private class CacheManager<T: Codable> {
        private let cacheKey = "WeatherApp_Cache"
        private let userDefaults = UserDefaults.standard
        
        func getItem(forKey key: String) -> T? {
            guard let data = userDefaults.data(forKey: "\(cacheKey)_\(key)") else {
                return nil
            }
            return try? JSONDecoder().decode(T.self, from: data)
        }
        
        func setItem(forKey key: String, item: T) {
            if let data = try? JSONEncoder().encode(item) {
                userDefaults.set(data, forKey: "\(cacheKey)_\(key)")
            }
        }
        
        func getAllItems() -> [String: T] {
            var items = [String: T]()
            let userDefaultsDict = userDefaults.dictionaryRepresentation()
            
            for (key, value) in userDefaultsDict where key.hasPrefix(cacheKey) {
                guard let data = value as? Data,
                      let item = try? JSONDecoder().decode(T.self, from: data) else {
                    continue
                }
                
                let cityKey = key.replacingOccurrences(of: "\(cacheKey)_", with: "")
                items[cityKey] = item
            }
            
            return items
        }
        
        func removeItem(forKey key: String) {
            userDefaults.removeObject(forKey: "\(cacheKey)_\(key)")
        }
    }
    
    
    private func setupNetworkMonitoring() {
        NetworkMonitor.shared.startMonitoring()
        
        // 启动定时器定期检查网络状态
        networkCheckTimer = Timer.scheduledTimer(withTimeInterval: networkCheckInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.checkNetworkStability()
            }
        }
        
        NetworkMonitor.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                
                let now = Date()
                if let lastCheck = self.lastNetworkCheckTime,
                   now.timeIntervalSince(lastCheck) < self.networkCheckInterval {
                    return  // 忽略过于频繁的状态变化
                }
                
                self.lastNetworkCheckTime = now
                
                if isConnected {
                    self.networkStableCount += 1
                    if self.networkStableCount >= self.requiredStableCount {
                        self.isNetworkStable = true
                        self.retryCount = 0  // 重置重试计数
                        print("✅ 网络已稳定")
                        // 网络恢复后，检查是否需要重试
                        if let lastRequest = self.lastSuccessfulRequest,
                           Date().timeIntervalSince(lastRequest) > self.requestTimeout {
                            Task { [weak self] in
                                await self?.retryLocationRequest()
                            }
                        }
                    }
                } else {
                    self.networkStableCount = 0
                    self.isNetworkStable = false
                    print("❌ 网络不稳定")
                }
                
                NetworkMonitor.shared.isConnected = isConnected
            }
            .store(in: &cancellables)
    }
    
    private func checkNetworkStability() {
        guard NetworkMonitor.shared.isConnected else {
            networkStableCount = 0
            isNetworkStable = false
            return
        }
        
        // 使用更快的网络检测方法
        let url = URL(string: "https://www.baidu.com")!
        let task = URLSession.shared.dataTask(with: url) { [weak self] _, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if error == nil, let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    self.networkStableCount += 1
                    if self.networkStableCount >= self.requiredStableCount {
                        self.isNetworkStable = true
//                        print("✅ 网络质量良好")
                    }
                } else {
                    self.networkStableCount = 0
                    self.isNetworkStable = false
                    print("❌ 网络质量不佳")
                }
            }
        }
        task.resume()
    }
}

