//
//  LocationExtension.swift
//  MyWeatherApp
//
//  Created by Star. on 2025/5/21.
//

import Foundation
import CoreLocation


extension WeatherViewModel {
    // MARK: - 定位逻辑
    func loadDefaultLocation() async {
        isLoading = true
        
        do {
            let status = try await checkLocationAuthorization()
            switch status {
            case .authorized:
                try await fetchLocation()
            case .notDetermined:
                try await requestAuthorizationWithRetry(maxRetries: 3)
            case .denied:
                throw LocationError.locationAuthorizationDenied
            case .unknown:
                throw WeatherAPIError.locationUnavailable
            }
        } catch {
            await handleLocationError(error)
        }
    }
    
    // 检查定位权限状态
    private func checkLocationAuthorization() async throws -> LocationStatus {
        let status = LocationService.shared.authorizationStatus()
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .restricted, .denied:
            return .denied
        @unknown default:
            return .unknown
        }
    }
    
    // 请求定位权限并处理重试逻辑
    private func requestAuthorizationWithRetry(maxRetries: Int) async throws {
        var retryCount = 0
        
        while retryCount < maxRetries {
            LocationService.shared.requestAuthorization()
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            
            let status = LocationService.shared.authorizationStatus()
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                return
            }
            
            retryCount += 1
            if retryCount < maxRetries {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 重试前等待1秒
            }
        }
        
        throw WeatherAPIError.locationAuthorizationTimeout
    }
    
    // 获取位置并转换为城市
    private func fetchLocation() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let locationService = LocationService.shared
            
            // 保存原始回调
            let originalCallback = locationService.onLocationUpdate
            
            // 设置新的回调
            locationService.onLocationUpdate = { [weak self] location, error in
                // 恢复原始回调
                locationService.onLocationUpdate = originalCallback
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let location = location else {
                    continuation.resume(throwing: WeatherAPIError.locationUnavailable)
                    return
                }
                
                // 使用Task.detached避免任务取消问题
                Task.detached { [weak self] in
                    guard let self = self else {
                        continuation.resume(throwing: WeatherAPIError.locationUnavailable)
                        return
                    }
                    
                    do {
                        let cityName = try await self.convertLocationToCity(location: location)
                        await self.fetchWeatherData(for: cityName) { result in
                            switch result {
                            case .success:
                                continuation.resume()
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // 请求位置
            locationService.requestLocation()
        }
    }
    
    // 处理定位错误
    private func handleLocationError(_ error: Error) async {
        print("定位错误: \(error.localizedDescription)")
        self.error = error
        self.isLoading = false
        
        // 使用默认城市
        await fetchWeatherData(for: "番禺区") { [weak self] result in
            self?.isLoading = false
        }
    }
    
    // MARK: - 坐标转换
    private func convertLocationToCity(location: CLLocation) async throws -> String {
        print("开始将经纬度 (\(location.coordinate.latitude), \(location.coordinate.longitude)) 转换为地区名称")
        isLoading = true
        
        do {
            let cityName = try await getRegionName(from: location)
            print("坐标转换成功，地区名称: \(cityName)")
            
            guard let adcode = DatabaseManager.shared.getAdcode(forName: cityName) else {
                throw WeatherAPIError.cityNotFound
            }
            print("数据库查询成功，adcode: \(adcode)")
            
            await fetchWeatherData(for: cityName) { [weak self] result in
                self?.isLoading = false
            }
            
            return cityName
        } catch {
            print("坐标转换失败: \(error.localizedDescription)，将使用默认城市")
            self.error = error
            await fetchWeatherData(for: "番禺区") { [weak self] _ in
                self?.isLoading = false
            }
            throw error
        }
    }
}
