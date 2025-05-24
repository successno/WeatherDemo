import SwiftUI


struct WeatherDetailPopup: View {
    
    // 要展示的天气数据模型（由父视图传入）
    let weather: CityWeatherModel
    
    // 绑定父视图的弹窗显示状态（用于关闭弹窗）
    @Binding var isShowing: Bool
    
    // 注入全局卡片管理器（用于添加新卡片）
    @EnvironmentObject private var mainCardManager: MainCardManager
    
    // 注入天气视图模型（用于可能的后续操作）
    @EnvironmentObject private var viewModel: WeatherViewModel
    
    // 控制更多选项视图的显示状态（预留扩展）
    @State var showMoreOptions = false
    
    // 控制地图视图的显示状态（预留扩展）
    @State var showMap = false
    
    // 控制添加成功提示的显示状态
    @State private var showAddSuccess = false
    
    // 弹窗背景颜色（由父视图指定）
    let backgroundColor: Color
    
    // 获取系统提供的展示模式（用于关闭弹窗）
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("取消")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            
                    }
 
                    Spacer()
                    
                    Button(action: {
                        addWeatherCard()
                        showAddSuccess = true
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("添加")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            
                    }
                }
                .padding(20)
                
                ScrollView(showsIndicators: false) {
                    // 实时天气模块
                    if let liveData = weather.live.first,
                       let futureData = weather.future.first {
                        HomemoduleView(
                            currentWeather: CurrentWeather(
                                city: liveData.city,
                                temperature: liveData.temperature,
                                weatherCondition: liveData.weather,
                                highTemperature: futureData.daytemp,
                                lowTemperature: futureData.nighttemp
                            ),
                            isInWidget: false
                        )
                    } else {
                        HomemoduleView(currentWeather: nil, isInWidget: false)
                    }
                    
                    VStack(spacing: -20) {
                        // 湿度模块
                        if let liveData = weather.live.first {
                            HumidityView(
                                humidity: liveData.humidity,
                                temperature: liveData.temperature
                            )
                        }
                        
                        // 风力模块
                        if let windData = weather.live.first {
                            WindView(
                                windDirection: windData.winddirection,
                                windPower: windData.windpower,
                                textColor: .blue
                            )
                        }
                        
                        // 小时预报
                        if let liveData = weather.live.first {
                            HomeslideView(
                                weatherText: "\(liveData.city)今天\(liveData.weather)，\(liveData.winddirection)风\(liveData.windpower)级。"
                            )
                        }
                        
                        // 未来天气预报
                        ListRowView(
                            forecasts: weather.future.prefix(4).compactMap { $0 },
                            title: "未来三日天气预报"
                        )
                    }
                }
            }
        }
        .alert("添加成功", isPresented: $showAddSuccess) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("已添加到我的城市")
        }
        .onTapGesture {
            isShowing = false
        }
    }
    
    /// 添加天气卡片到主页的核心交互方法
    /// 步骤说明：
    /// 1. 验证实时天气数据、未来天气数据和城市名称是否存在
    /// 2. 基于验证通过的数据构建新卡片实例
    /// 3. 通过全局卡片管理器将新卡片添加到主页面列表
    private func addWeatherCard() {
        // 数据验证（任意一项缺失则终止操作）
        guard let liveData = weather.live.first,
              let futureData = weather.future.first,
              let cityName = DatabaseManager.shared.getCityNameByAdcode(liveData.adcode) else {
            return
        }
        
        // 构建新卡片实例（使用验证通过的数据）
        let newCard = WeatherCardData(
            city: cityName,
            temperature: liveData.temperature,
            weatherCondition: liveData.weather,
            highTemperature: futureData.daytemp,
            lowTemperature: futureData.nighttemp,
            currentWeather: weather.live,
            futureWeather: [futureData],
            cityName: cityName,
            adcode: liveData.adcode
        )
        
        // 通过全局管理器添加卡片（自动去重）
        mainCardManager.addCard(newCard)
    }
}

func mockCombinedWeatherModel() -> CityWeatherModel {
    return CityWeatherModel(
        city: ["city"],
        live: [WeatherLiveModel.LiveData(
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

        )],
        future:
            [WeatherFutureModel.ForecastData.DailyForecast (
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
            )]
        
    )
}

#Preview {
    @Previewable @State var isShowingPopup = false
    let viewModel = WeatherViewModel()
    let cardManager = MainCardManager()
    let cityWeatherModel = mockCombinedWeatherModel()
    
    VStack {
        WeatherDetailPopup(weather: cityWeatherModel, isShowing: $isShowingPopup, backgroundColor: .blue.opacity(0.75))
            .environmentObject(viewModel)
            .environmentObject(cardManager)
    }
}

//// 扩展：为 Date 添加 ISO8601 格式转换（若模型需要）
//extension Date {
//    var iso8601String: String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
//        return formatter.string(from: self)
//    }
//}

