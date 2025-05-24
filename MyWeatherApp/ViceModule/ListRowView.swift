//
//  ListRowView.swift
//  WeatherApp
//
//  Created by Star. on 2025/5/8.
//
import SwiftUI

struct ListRowView: View {
    let forecasts: [WeatherFutureModel.ForecastData.DailyForecast]? // 接收预报数据作为参数
    let title: String

    var body: some View {
        ZStack {
            VStack {
                if let forecasts = forecasts {
                    List {
                        Text(title)  // 使用传入的标题
                            .font(.headline)
                        
                        ForEach(forecasts, id: \.date) { forecast in
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(forecast.displayWeekday)
                                    Spacer()
                                    WeatherIconView(weather: forecast.dayweather)
                                    Spacer()
                                    Text("夜: \(forecast.nighttemp)°")
                                        .foregroundColor(.gray)
                                    Text("日: \(forecast.daytemp)°")
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                } else {
                    // 数据为空时的占位符
                    Text("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 220)
            .scrollIndicators(.never)
            .cornerRadius(20)
            .padding(20)
        }
    }
}

#Preview {
    // 创建模拟的 DailyForecast 数据
    let mockForecasts: [WeatherFutureModel.ForecastData.DailyForecast] = [
        .init(
            date: "2025-05-20",
            week: "2",
            dayweather: "晴",
            nightweather: "晴",
            daytemp: "30",
            nighttemp: "22",
            daywind: "东南风",
            nightwind: "东南风",
            daypower: "3-4级",
            nightpower: "3-4级",
            daytemp_float: "30.0",
            nighttemp_float: "22.0"
        ),
        .init(
            date: "2025-05-21",
            week: "3",
            dayweather: "多云",
            nightweather: "阴",
            daytemp: "28",
            nighttemp: "20",
            daywind: "东北风",
            nightwind: "东北风",
            daypower: "2-3级",
            nightpower: "2-3级",
            daytemp_float: "28.0",
            nighttemp_float: "20.0"
        ),
        .init(
            date: "2025-05-22",
            week: "4",
            dayweather: "小雨",
            nightweather: "中雨",
            daytemp: "25",
            nighttemp: "18",
            daywind: "北风",
            nightwind: "北风",
            daypower: "4-5级",
            nightpower: "4-5级",
            daytemp_float: "25.0",
            nighttemp_float: "18.0"
        ),
        .init(
            date: "2025-05-23",
            week: "5",
            dayweather: "大风",
            nightweather: "中雨",
            daytemp: "23",
            nighttemp: "18",
            daywind: "北风",
            nightwind: "北风",
            daypower: "7-8级",
            nightpower: "8-9级",
            daytemp_float: "23.0",
            nighttemp_float: "18.0"
        )
        
    ]
    
    return ListRowView(
        forecasts: mockForecasts,
        title: "未来三日天气预报"
    )
    .environmentObject(WeatherViewModel()) // 注入环境对象（如果需要）
}

