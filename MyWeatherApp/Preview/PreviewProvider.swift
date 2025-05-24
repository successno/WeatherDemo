//
//  PreviewProvider.swift
//  MyWeatherApp
//
//  Created by Star. on 2025/5/21.
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
    private init() {}// 私有化初始化方法确保单例
    
    
    static let dailyForecast = WeatherFutureModel.ForecastData.DailyForecast(
            date: "2025-01-01",
            week: "1",
            dayweather: "晴",
            nightweather: "晴",
            daytemp: "28",
            nighttemp: "18",
            daywind: "南",
            nightwind: "南",
            daypower: "2",
            nightpower: "2",
            daytemp_float: "28.0",
            nighttemp_float: "18.0"
        )
        
    static let liveData = WeatherLiveModel.LiveData(
            province: "示例省份",
            city: "示例城市",
            adcode: "123456",
            weather: "晴",
            temperature: "25",
            winddirection: "南",
            windpower: "2",
            humidity: "60",
            reporttime: "2025-01-01 12:00:00",
            temperature_float: "25.0",
            humidity_float: "60.0"
        )

    let weather = CityWeatherModel(city: ["city"], live: [liveData], future: [dailyForecast])
   
}
