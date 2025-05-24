//
//  HomemoduleView.swift
//  WeatherApp
//
//  Created by Star. on 2025/5/7.
//
struct CurrentWeather: Identifiable {
    let id = UUID()
    let city: String
    let temperature: String
    let weatherCondition: String
    let highTemperature: String?
    let lowTemperature: String?
    
}

import SwiftUI

struct HomemoduleView: View {
    let currentWeather: CurrentWeather?
    let isInWidget: Bool
    @State private var textColor: Color = .white
    
    init(
        currentWeather: CurrentWeather?,
        isInWidget: Bool = false
    ) {
        self.currentWeather = currentWeather
        self.isInWidget = isInWidget
    }
    
    var body: some View {
        ZStack {
            if isInWidget {
                Color.blue
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 10) {
                if let weather = currentWeather {
                    Text(weather.city)
                        .font(.title2)
                        .foregroundColor(textColor)
                    
                    Text("\(weather.temperature)°")
                        .font(.system(size: 60))
                        .fontWeight(.heavy)
                        .offset(x: 17)
                        .foregroundColor(textColor)
                    
                    HStack(spacing: 10) {
                        VStack(spacing: -2) {
                            Text("最")
                                .font(.headline)
                                .fontWeight(.heavy)
                                .foregroundColor(textColor)
                            Text("高")
                                .font(.headline)
                                .fontWeight(.heavy)
                                .foregroundColor(textColor)
                        }
                        
                        if let highTemp = weather.highTemperature {
                            Text("\(highTemp)°")
                                .font(.title)
                                .foregroundColor(textColor)
                        }
                        
                        VStack(spacing: -2) {
                            Text("最")
                                .font(.headline)
                                .fontWeight(.heavy)
                                .foregroundColor(textColor)
                            Text("低")
                                .font(.headline)
                                .fontWeight(.heavy)
                                .foregroundColor(textColor)
                        }
                        
                        if let lowTemp = weather.lowTemperature {
                            Text("\(lowTemp)°")
                                .font(.title)
                                .foregroundColor(textColor)
                                
                        }
                    }
                    
                    Text(weather.weatherCondition)
                        .foregroundColor(textColor)
                        .font(.headline)
                        .fontWeight(.bold)
                        .opacity(0.6)
                } else {
                    // 数据加载中或失败的提示
                    Text("加载中...")
                        .foregroundColor(textColor)
                        .font(.headline)
                }
            }
            .padding()
        }
    }
}
