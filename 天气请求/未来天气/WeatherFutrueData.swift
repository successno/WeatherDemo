//
//  WeatherFutrueData.swift
//  MyWeatherApp
//
//  Created by Star. on 2025/5/13.
//

import Foundation
import Combine

class WeatherFutrueData:ObservableObject {
    
    
    @Published var weatherlivedata:[ WeatherFutureModel] = []
    
    private var cancellables = Set<AnyCancellable>() // Combine订阅集合
    
    
    private let token = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String ?? ""
    private let baseURL = "https://restapi.amap.com/v3/weather/weatherInfo"
    
    func getFutruedata(location: String) -> AnyPublisher<WeatherFutureModel, Error> {
        print("开始构建未来天气请求URL，location: \(location)")
        
        guard var urlComponents = URLComponents(string: baseURL) else {
            print("URL组件初始化失败")
            return Fail(error: WeatherAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let queryItem = [
            URLQueryItem(name: "key", value: token),
            URLQueryItem(name: "city", value: location),
            URLQueryItem(name: "extensions", value: "all")
        ]
        
        urlComponents.queryItems = queryItem
        
        guard let url = urlComponents.url else {
            print("URL构建失败")
            return Fail(error: WeatherAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        print("未来天气请求URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30 // 设置30秒超时
        
        return NetworkingService.downLoad(url: url)
            .decode(type: WeatherFutureModel.self, decoder: JSONDecoder())
            .mapError { error in
                print("未来天气数据解码或网络请求失败: \(error.localizedDescription)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .dataCorrupted(let context):
                        print("数据损坏: \(context.debugDescription)")
                    case .keyNotFound(let key, let context):
                        print("找不到键: \(key.stringValue), 上下文: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("类型不匹配: 期望 \(type), 上下文: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("值不存在: 期望 \(type), 上下文: \(context.debugDescription)")
                    @unknown default:
                        print("未知解码错误")
                    }
                }
                return error
            }
            .eraseToAnyPublisher()
    }
    
}

class DailyForecastModel {
    @Published private var dailyForecasts:[ WeatherFutureModel.ForecastData.DailyForecast]
    
    init(dailyForecasts: [ WeatherFutureModel.ForecastData.DailyForecast]) {
        self.dailyForecasts = dailyForecasts
    }
    
}

extension DailyForecastModel {
    var displayDate: String {
        guard let firstForecast = dailyForecasts.first else {
            return ""
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let forecastDate = dateFormatter.date(from: firstForecast.date),
              let today = dateFormatter.date(from: dateFormatter.string(from: Date())) else {
            return firstForecast.date
        }
        return Calendar.current.isDate(forecastDate, inSameDayAs: today) ? "今天" : firstForecast.date
    }
}
