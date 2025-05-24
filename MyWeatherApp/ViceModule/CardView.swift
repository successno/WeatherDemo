//
//  CardView.swift
//  MyWeatherApp
//
//  Created by Star. on 2025/5/18.
//

import SwiftUI

struct CardView: View {
    let weather: CurrentWeather? // 接收可选的 CurrentWeather 对象
    @State var vm = WeatherViewModel()
    var onTap: () -> Void = {} // 添加点击回调闭包
    @EnvironmentObject private var cardManager: MainCardManager // 添加卡片管理器
    
    var body: some View {
        if let weather = weather {
                ZStack {
                    Rectangle()
                        .foregroundColor(Color.blue.opacity(0.8))
                        .cornerRadius(20)
                    
                    VStack (spacing:0){
                        HStack {
                            VStack(alignment:.leading) {
                                Text(weather.city)
                                    .font(.title2)
                                    .fontWeight(.heavy)
                                    .foregroundColor(.white.opacity(0.9))
                                
                                if vm.currentCity == weather.city{
                                    Text("我的位置")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.caption)
                                    .fontWeight(.heavy)
                                }else{
                                    LocalizedTimeView()
                                }
                            }
                            Spacer()
                            Text("\(weather.temperature)°")
                                .foregroundColor(.white)
                                .font(.system(size: 35))
                        }
                        HStack {
                            Text("\(weather.weatherCondition)")
                                .font(.headline)
                                .fontWeight(.heavy)
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            if let highTemp = weather.highTemperature,
                               let lowTemp = weather.lowTemperature{
                                Text("最高\(highTemp)  最低\(lowTemp)°")
                                    .foregroundColor(.white)
                                    .font(.headline)
                            }
                        }
                    }
                    .padding()
                }
                .frame(height: 70)
                .padding()
                .onTapGesture(perform: onTap)
        }
    }
}

#Preview {
    let mockWeather = CurrentWeather(
        city: "广州市",
        temperature: "28",
        weatherCondition: "多云",
        highTemperature: "30",
        lowTemperature: "25"
    )
    return CardView(weather: mockWeather)
    
}

struct LocalizedTimeView: View {
    @State private var currentTime = Date()
    
    var body: some View {
        VStack {
            Text(timeString)
                .foregroundColor(.white.opacity(0.7))
                .font(.callout)
                .fontWeight(.heavy)
        }
    }
    
    // 使用LocalizedStringKey自动格式化时间
    private var timeString: LocalizedStringKey {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: currentTime)
        guard let hour = components.hour, let minute = components.minute else { return "未知时间" }
        
        // 自动适配系统语言的时间格式
        return LocalizedStringKey("\(hour):\(minute < 10 ? "0\(minute)" : "\(minute)")")
    }
}
