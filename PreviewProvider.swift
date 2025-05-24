//
//  PreviewProvider.swift
//  WeatherApp
//
//  Created by Star. on 2025/5/6.
//

import Foundation
import SwiftUI

// MARK: - Preview Provider扩展
/// 为SwiftUI预览提供开发数据的扩展
extension PreviewProvider {
    
    /// 开发预览实例的快捷访问方式
    static var dev: DeveloperPreview {
        return DeveloperPreview.instance
    }
}

// MARK: - 开发预览类
/// 开发预览数据容器类，用于SwiftUI预览和测试
class DeveloperPreview {
    // MARK: - 单例实例
    static let instance = DeveloperPreview()
    private init() {} // 私有化初始化方法确保单例
    
    // MARK: - 视图模型
    let WeatherVM = WeatherViewModel() // 天气视图模型实例
    
    // MARK: - 天气数据模型
    /// API整体响应数据模型
    struct LiveWeatherResponse: Codable {
        let status: String
        let count: String
        let info: String
        let infocode: String
        let lives: [LiveWeather]
    }
    
    // 实况天气信息模型
    struct LiveWeather: Codable {
        let province: String
        let city: String
        let adcode: String
        let weather: String
        let temperature: String
        let winddirection: String
        let windpower: String
        let humidity: String
        let reporttime: String
    }
    
    // 预报天气响应模型
    struct ForecastWeatherResponse: Codable {
        let status: String
        let count: String
        let info: String
        let infocode: String
        let lives: [LiveWeather]
        let forecast: [ForecastInfo]
    }
    
    // 预报天气信息模型
    struct ForecastInfo: Codable {
        let city: String
        let adcode: String
        let province: String
        let reporttime: String
        let casts: [CastInfo]
    }
    
    // 具体预报信息模型
    struct CastInfo: Codable {
        let date: String
        let week: String
        let dayweather: String
        let nightweather: String
        let daytemp: String
        let nighttemp: String
        let daywind: String
        let nightwind: String
        let daypower: String
        let nightpower: String
    }
    
}
