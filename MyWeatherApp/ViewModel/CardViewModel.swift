//
//  WeatherCardView.swift
//  MyWeatherApp
//
//  Created by Star. on 2025/5/16.
//

import SwiftUI

struct WeatherCardData: Identifiable, Hashable, Codable {
    
    let city: String
    let temperature: String
    let weatherCondition: String
    let highTemperature: String?
    let lowTemperature: String?
    
    let currentWeather: [WeatherLiveModel.LiveData]
    let futureWeather: [WeatherFutureModel.ForecastData.DailyForecast]
    
    var id = UUID()
    let cityName: String
    let adcode: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: WeatherCardData, rhs: WeatherCardData) -> Bool {
        return lhs.id == rhs.id
    }
    
}

//struct WeatherCardView: View {
//    let weatherCardData: WeatherCardData
//    
//    @State private var showDetail = false // 控制是否显示详情页，若复用场景不需要可移除
//    
//    var body: some View {
//        ZStack {
//            Rectangle()
//                .foregroundColor(Color.blue.opacity(0.8))
//                .cornerRadius(20)
//            VStack {
//                HStack {
//                    VStack(alignment:.leading) {
//                        Text(weatherCardData.city)
//                            .font(.subheadline)
//                            .foregroundColor(.white)
//                        Text("我的位置")
//                            .foregroundColor(.white.opacity(0.7))
//                            .font(.caption)
//                    }
//                    Spacer()
//                    Text("\(weatherCardData.temperature)°")
//                        .foregroundColor(.white)
//                        .font(.largeTitle)
//                }
//                HStack {
//                    Text(weatherCardData.weatherCondition)
//                        .foregroundColor(.white)
//                        .font(.headline)
//                    Spacer()
//                    if let high = weatherCardData.highTemperature,
//                        let low = weatherCardData.lowTemperature {
//                        Text("最高\(high) 最低\(low)°")
//                            .foregroundColor(.white)
//                            .font(.headline)
//                    }
//                }
//            }
//            .padding()
//        }
//        .frame(height: 100)
//        .padding()
//    }
//}
