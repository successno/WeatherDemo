//
//  HumidityView.swift
//  MyWeatherApp
//
//  Created by Star. on 2025/5/9.
//

import SwiftUI

struct HumidityView: View {
    
    let humidity: String
    let temperature: String
    @State private var dewPoint: String?
    
    init(humidity: String, temperature: String) {
        self.humidity = humidity
        self.temperature = temperature
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .cornerRadius(10)
                .foregroundColor(Color.white)
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "humidity.fill")
                                Text("湿度:")
                                    .fontWeight(.bold)
                                    .font(.headline)
                                
                                    Text("\(humidity)%")
                                
                                    Spacer()
                                
                                Text("目前露点温度为\(dewPoint ?? "")°")
                            }
                            .padding(5)
                            .foregroundColor(Color.gray)
                    }
                    .padding()
                }
        }
        .frame(height: 25)
        .padding(20)
        .onAppear {
            calculateDewPoint()
        }
    }
    
    private func calculateDewPoint() {
        guard let temperature = Double(temperature),
              let humidity = Double(humidity),
              humidity / 100.0 > 0.01 else {
            dewPoint = nil
            return
        }
            let num = temperature - (1 - humidity / 100.0) / 0.05
        dewPoint = String(format: "%.1f", num)
    }
}
