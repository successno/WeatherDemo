//
//  MyWeatherAppApp.swift
//  MyWeatherApp
//
//  Created by Star. on 2025/5/9.
//

import SwiftUI
import CoreData

// 定义自定义环境键
private struct ManagedObjectContextKey: EnvironmentKey {
    static let defaultValue: NSManagedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
}

extension EnvironmentValues {
    var managedObjectContext: NSManagedObjectContext {
        get { self[ManagedObjectContextKey.self] }
        set { self[ManagedObjectContextKey.self] = newValue }
    }
}

@main
struct MyWeatherAppApp: App {
    
    
    @StateObject private var weatherViewModel = WeatherViewModel()
    @StateObject private var cardManager = MainCardManager() // 卡片管理器单例
    
    @State var showMoreOptions = false
    @State var showMap = false
 
    
    let binding = Binding<[WeatherCardData]>(get: {
        MainCardManager().cards
    }, set: { newValue in
        // 这里可以添加保存新值的逻辑，如果需要的话
    })
    
    
    // 创建WeatherLiveModel.LiveData实例
    let liveData = WeatherLiveModel.LiveData(
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
    
    // 创建WeatherFutureModel.ForecastData.DailyForecast实例
    let dailyForecast = WeatherFutureModel.ForecastData.DailyForecast(
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
    
    var body: some Scene {

        WindowGroup {
            NavigationStack {
                WeatherView(
                    title: "",
                    viewModel: weatherViewModel,
                    cardManager: cardManager,
                    showMoreOptions: $showMoreOptions,
                    showMap: $showMap,
                    bottomMenu: { onMore, onMap in
                        AnyView(BottomMenuView(onShowMoreOptions: onMore, onShowMap: onMap))
                    }
                )
                .environmentObject(weatherViewModel)
                .environmentObject(cardManager)
                .onAppear {

                    _ = LocationService.shared
                    _ = NetworkMonitor.shared
                }
            }
        }
    }
}
