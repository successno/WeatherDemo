//
//  BottomMenuView.swift
//  MyWeatherApp
//
//  Created by Star. on 2025/5/13.
//

import SwiftUI

struct MapView: View {
    var body: some View {
        Text("天气")
    }
}



struct BottomMenuView: View {

    @EnvironmentObject var viewModel: WeatherViewModel
    var onShowMoreOptions: () -> Void
    var onShowMap: () -> Void
    
    var body: some View {
        HStack {
            
            Button(action: onShowMap) {
                Image(systemName: "map.fill")
                    .foregroundColor(.gray)
                    .font(.title2)
            }
            Spacer()
            Button(action: onShowMoreOptions) {
                Image(systemName: "ellipsis.rectangle.fill")
                    .foregroundColor(.gray)
                    .font(.title2)
            }
            
        }
        .frame(height: 30) // 调整高度更合理
        .padding(16) // 调整内边距
        .background(Color.white.opacity(0.9)) // 添加背景色

    }
}

#Preview {
    BottomMenuView(onShowMoreOptions:{  print("点击了更多选项按钮")}, onShowMap: {print("点击了地图按钮")})
        .environmentObject(WeatherViewModel())
       
}
