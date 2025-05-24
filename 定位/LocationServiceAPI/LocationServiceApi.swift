//
//  LocationServiceApi.swift
//  MyWeatherApp
//
//  Created by Star. on 2025/5/17.
//

import Foundation
import CoreLocation
import Combine
import Network
import UIKit



// MARK: - 高德地图API模型
/// 高德逆地理编码请求模型
/// - 封装高德API请求参数和构建逻辑
struct AMapRegeoRequest {
    let key: String
    let location: String
    let output: String = "JSON"
    let extensions: String = "base"
    
    /// 初始化方法
    /// - Parameter location: 经纬度坐标字符串（格式："经度,纬度"）
    /// - Throws: 当缺少API密钥时抛出missingAPIKey错误
    init(location: String) throws {
        guard let apiKey = Bundle.main.amapAPIKey else {
            throw LocationError.missingAPIKey
        }
        self.key = apiKey
        self.location = location
    }
    
    /// 构建URLRequest对象
    /// - Returns: 配置完成的URLRequest对象，失败时返回nil
    func buildURLRequest() -> URLRequest? {
        guard let url = URL(string: "https://restapi.amap.com/v3/geocode/regeo") else {
            print("❌ URL构建失败")
            return nil
        }
        
        let params = [
            "output": output,
            "location": location,
            "key": key,
            "extensions": extensions
        ]
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let finalURL = components?.url else {
            print("❌ URL组件生成失败")
            return nil
        }
        
        print("🚀 发起坐标转换请求")
        print("🔗 URL: \(finalURL.absoluteString)")
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        return request
    }
}

// MARK: - 系统定位服务类
/// 系统定位服务核心类
/// - 负责设备定位、权限管理、坐标转换等核心功能
/// - 封装CLLocationManager实现单例模式
class LocationService: NSObject, CLLocationManagerDelegate {
    /// 单例实例（线程安全）
    static let shared = LocationService()
    private let locationManager = CLLocationManager()
    private var locationTimer: Timer?
    private var lastKnownLocation: CLLocation?
    
    var onLocationUpdate: ((CLLocation?, Error?) -> Void)?
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func authorizationStatus() -> CLAuthorizationStatus {
        return CLLocationManager.authorizationStatus()
    }
    
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        print("📍 请求定位，当前授权状态：\(CLLocationManager.authorizationStatus())")
        
        guard NetworkMonitor.shared.isConnected else {
            print("❌ 网络未连接")
            onLocationUpdate?(nil, LocationError.networkUnavailable)
            return
        }
        
        locationTimer?.invalidate()
        
        switch CLLocationManager.authorizationStatus() {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
            setupLocationTimeout()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            onLocationUpdate?(nil, LocationError.locationAuthorizationDenied)
        @unknown default:
            onLocationUpdate?(nil, LocationError.locationServiceFailed)
        }
    }
    
    private func setupLocationTimeout() {
        locationTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            self?.onLocationUpdate?(nil, LocationError.locationServiceFailed)
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    /// 定位更新回调
    /// - 处理新获取的位置数据
    /// - 执行逆地理编码转换坐标到具体地址
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("📍 获取到 \(locations.count) 个位置")
        
        guard let location = locations.last else {
            print("❌ 未获取到位置数据")
            onLocationUpdate?(nil, LocationError.locationNotFound)
            return
        }
        
        if let lastLocation = lastKnownLocation,
           abs(location.timestamp.timeIntervalSince(lastLocation.timestamp)) < 1.0 {
            return
        }
        
        lastKnownLocation = location
        locationTimer?.invalidate()
        
        Task {
            do {
                let regionName = try await AMapService.reverseGeocode(location: location)
                print("✅ 地址解析成功：\(regionName)")
                onLocationUpdate?(location, nil)
            } catch {
                print("❌ 地址解析失败：\(error.localizedDescription)")
                onLocationUpdate?(nil, error)
            }
        }
    }
    
    /// 定位失败回调
    /// - 转换CLError到自定义错误类型
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationTimer?.invalidate()
        print("❌ 定位失败：\(error.localizedDescription)")
        
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                onLocationUpdate?(nil, LocationError.locationAuthorizationDenied)
            default:
                onLocationUpdate?(nil, LocationError.locationServiceFailed)
            }
        } else {
            onLocationUpdate?(nil, error)
        }
    }
    
    /// 定位权限变更回调
    /// - 当用户修改定位权限时自动触发新定位
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("📍 定位权限状态改变: \(manager.authorizationStatus.rawValue)")
        
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}

// MARK: - AppDelegate
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        NetworkMonitor.shared.startMonitoring()
        return true
    }
}
