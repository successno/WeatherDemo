//
//  GDMapService.swift
//  MyWeatherApp
//
//  Created by Star. on 2025/5/17.
//

import Foundation
import CoreLocation



// MARK: - 高德地图服务类
class AMapService {
    // MARK: - 缓存管理
    private static var geocodeCache = [String: String]()
    private static let cacheQueue = DispatchQueue(label: "com.weatherapp.geocodecache")
    
    /// 逆地理编码（通过经纬度获取地址信息）
    static func reverseGeocode(location: CLLocation) async throws -> String {
        print("📍 开始逆地理编码，经纬度：\(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        let coordinateKey = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
        
        // 检查缓存
        if let cachedName = getCachedRegionName(for: coordinateKey) {
            print("✅ 使用缓存的地区名称：\(cachedName)")
            return cachedName
        }
        
        do {
            let request = try AMapRegeoRequest(location: coordinateKey)
            let response = try await reverseGeocode(request: request)
            
            guard let addressComponent = response.regeocode.addressComponent else {
                throw LocationError.locationNotFound
            }
            
            let regionName = try buildRegionName(from: addressComponent)
            cacheRegionName(regionName, for: coordinateKey)
            
            return regionName
        } catch {
            print("❌ 逆地理编码失败：\(error.localizedDescription)")
            throw error
        }
    }
    
    /// 构建地区名称
    private static func buildRegionName(from addressComponent: AMapAddressComponent) throws -> String {
        let district = addressComponent.district
        let province = addressComponent.province
        
        let regionName: String
        if !district.isEmpty {
            regionName = district
        } else if !province.isEmpty {
            regionName = province
        } else {
            throw LocationError.locationNotFound
        }
        
        guard !regionName.isEmpty else {
            throw LocationError.locationNotFound
        }
        
        print("✅ 构建地区名称成功：\(regionName)")
        return regionName
    }
    
    /// 缓存管理方法
    private static func getCachedRegionName(for key: String) -> String? {
        cacheQueue.sync {
            return geocodeCache[key]
        }
    }
    
    private static func cacheRegionName(_ name: String, for key: String) {
        cacheQueue.async {
            geocodeCache[key] = name
        }
    }
    
    /// 逆地理编码（使用高德API）
    static func reverseGeocode(request: AMapRegeoRequest) async throws -> AMapRegeoResponse {
        guard let urlRequest = request.buildURLRequest() else {
            throw LocationError.locationServiceFailed
        }
        
        print("🚀 发送逆地理编码请求")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LocationError.locationServiceFailed
            }
            
            print("📡 API响应状态码: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                throw handleHTTPError(httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            let result = try decoder.decode(AMapRegeoResponse.self, from: data)
            
            guard result.status == "1", result.infocode == "10000" else {
                throw LocationError.apiError(result.info.isEmpty ? "API请求失败" : result.info)
            }
            
            guard result.regeocode.addressComponent != nil else {
                throw LocationError.locationNotFound
            }
            
            return result
        } catch let decodingError as DecodingError {
            print("❌ JSON解码失败：\(decodingError.localizedDescription)")
            throw LocationError.dataParsingError
        } catch {
            print("❌ 逆地理编码请求失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 处理HTTP错误
    private static func handleHTTPError(_ statusCode: Int) -> LocationError {
        switch statusCode {
        case 401:
            return LocationError.apiError("API密钥无效")
        case 429:
            return LocationError.apiError("请求频率超限")
        case 500...599:
            return LocationError.apiError("服务器错误")
        default:
            return LocationError.apiError("HTTP错误: \(statusCode)")
        }
    }
}

// MARK: - 辅助扩展
extension Bundle {
    var amapAPIKey: String? {
        object(forInfoDictionaryKey: "API_KEY") as? String
    }
}

// MARK: - 便捷方法
func getRegionName(from location: CLLocation) async throws -> String {
    return try await AMapService.reverseGeocode(location: location)
}
