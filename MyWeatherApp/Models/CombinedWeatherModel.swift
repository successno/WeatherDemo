//
//  CombinedWeatherModel.swift
//  MyWeatherApp
//
//  Created by Star. on 2025/5/13.
//

import Foundation

// MARK: - 组合天气模型（实时+未来）
struct CombinedWeatherModel {
    let liveWeather: WeatherLiveModel.LiveData
    let futureWeather: [WeatherFutureModel.ForecastData.DailyForecast]
    let city: String
    let province: String
    
    /// 初始化组合天气模型
    /// - Parameters:
    ///   - live: 实时天气数据
    ///   - future: 未来天气数据数组
    init(live: WeatherLiveModel.LiveData, future: [WeatherFutureModel.ForecastData.DailyForecast]) {
        self.liveWeather = live
        self.futureWeather = future
        self.city = live.city          // 从实时数据获取城市名称
        self.province = live.province   // 从实时数据获取省份名称
    }
}

// MARK: - 城市天气模型
struct CityWeatherModel: Codable {
    let city: [String]
    let live: [WeatherLiveModel.LiveData]
    let future: [WeatherFutureModel.ForecastData.DailyForecast]
    
    init(city: [String], live: [WeatherLiveModel.LiveData], future: [WeatherFutureModel.ForecastData.DailyForecast]) {
        self.city = city
        self.live = live
        self.future = future
    }
}

// MARK: - 未来天气模型
struct WeatherFutureModel: Codable {
    let status: String      // 请求状态码
    let count: String       // 返回结果数量
    let info: String        // 状态信息
    let infocode: String    // 状态代码
    let forecasts: [ForecastData] // 天气预报数据数组
    
    
}

// MARK: - 单城市预报数据
extension WeatherFutureModel {
    struct ForecastData: Codable {
        let city: String        // 城市名称
        let adcode: String      // 区域编码
        let province: String    // 省份名称
        let reporttime: String  // 数据发布时间
        let casts: [DailyForecast] // 每日预报数组
    }
    
}

// MARK: - 每日天气预报详情（含日期处理扩展）
extension WeatherFutureModel.ForecastData {
    struct DailyForecast: Codable {
        let date: String         // 预报日期（格式：yyyy-MM-dd）
        let week: String         // 星期几(数字)
        let dayweather: String   // 白天天气现象
        let nightweather: String // 夜间天气现象
        let daytemp: String      // 白天温度(字符串)
        let nighttemp: String    // 夜间温度(字符串)
        let daywind: String      // 白天风向
        let nightwind: String    // 夜间风向
        let daypower: String     // 白天风力
        let nightpower: String   // 夜间风力
        let daytemp_float: String // 白天温度(浮点数)
        let nighttemp_float: String // 夜间温度(浮点数)
        
        // MARK: - 计算属性（日期/星期处理）
        /// 转换为中文星期（含"今天"判断）
        var displayWeekday: String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            guard let date = dateFormatter.date(from: date) else {
                return "未知日期"
            }
            
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                return "今天"
            }
            
            dateFormatter.locale = Locale(identifier: "zh_CN")
            dateFormatter.dateFormat = "EEE"  // 获取简写星期（如"周一"）
            return dateFormatter.string(from: date)
        }
        
        /// 数字星期转中文（备用方案）
        var weekday: String {
            switch week {
            case "1": return "星期一"
            case "2": return "星期二"
            case "3": return "星期三"
            case "4": return "星期四"
            case "5": return "星期五"
            case "6": return "星期六"
            case "7": return "星期日"
            default: return week
            }
        }
    }
}

// MARK: - 实时天气模型
struct WeatherLiveModel: Codable {
    let status: String
    let count: String
    let info: String
    let infocode: String
    let lives: [LiveData]
    
}

// MARK: - 实时天气详情（含扩展计算）
extension WeatherLiveModel {
    struct LiveData: Codable {
        let province: String
        let city: String
        let adcode: String
        let weather: String
        let temperature: String
        let winddirection: String
        let windpower: String
        let humidity: String
        let reporttime: String
        let temperature_float: String
        let humidity_float: String
        
        /// 计算露点温度（简化逻辑）
        /// - Returns: 露点温度字符串（保留1位小数）或nil（数据无效时）
        func calculateDewPoint() -> String? {
            guard let temp = Double(temperature),
                  let humidityValue = Double(humidity),
                  humidityValue > 1 else {  // 湿度大于1%才计算
                return nil
            }
            
            let dewPoint = temp - (1 - humidityValue / 100) / 0.05
            return String(format: "%.1f", dewPoint)
        }
    }
}

