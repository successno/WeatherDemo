import SwiftUI


struct WeatherView: View {
    // MARK: - 可配置参数
    let title: String
    
    @ObservedObject var viewModel: WeatherViewModel
    @ObservedObject var cardManager: MainCardManager
    
    // MARK: - 状态控制
    @Binding var showMoreOptions: Bool
    @Binding var showMap: Bool
    
    // MARK: - 可自定义内容
    let bottomMenu: (@escaping () -> Void, @escaping () -> Void) -> AnyView
    
    var body: some View {
        VStack {
            WeatherModule(
                viewModel: viewModel,
                backgroundColor: .blue
            )
            
            bottomMenu(
                { showMoreOptions = true },
                { showMap = true }
            )
        }
        .fullScreenCover(isPresented: $showMoreOptions) {
            MoreOptionsView(dismiss: { showMoreOptions = false })
                .environmentObject(viewModel)
                .environmentObject(cardManager)
                .transition(.scale(scale: 0.6)) // 添加滑动过渡动画
        }
        .sheet(isPresented: $showMap) {
            MapView()
        }
        .onAppear {
            Task {
                await viewModel.loadDefaultLocation()
            }
        }
    }
}

#Preview {
    @Previewable @State var showMoreOptions = false
    @Previewable @State var showMap = false
    let viewModel = WeatherViewModel()
    let cardManager = MainCardManager()
    
    WeatherView(
        title: "",
        viewModel: viewModel,
        cardManager: cardManager,
        showMoreOptions: $showMoreOptions,
        showMap: $showMap,
        bottomMenu: { onMore, onMap in
            AnyView(BottomMenuView(onShowMoreOptions: onMore, onShowMap: onMap))
        }
    )
    .environmentObject(WeatherViewModel())
}

struct WeatherModule: View {
    @ObservedObject var viewModel: WeatherViewModel
    let backgroundColor: Color
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            VStack {
                Text(viewModel.currentCity ?? "我的位置")
                    .foregroundColor(.white)
                    .font(.title)
                
                ScrollView(showsIndicators: false) {
                    // 实时天气模块
                    if let liveData = viewModel.weatherLiveData?.lives.first,
                       let futureData = viewModel.weatherFutureData?.forecasts.first?.casts.first {
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
                        if let liveData = viewModel.weatherLiveData?.lives.first {
                            HumidityView(
                                humidity: liveData.humidity,
                                temperature: liveData.temperature
                            )
                        }
                        
                        // 风力模块
                        if let windData = viewModel.weatherLiveData?.lives.first {
                            WindView(
                                windDirection: windData.winddirection,
                                windPower: windData.windpower,
                                textColor: .blue
                            )
                        }
                        
                        // 小时预报
                        if let liveData = viewModel.weatherLiveData?.lives.first {
                            HomeslideView(
                                weatherText: "\(liveData.city)今天\(liveData.weather)。\(liveData.winddirection)风\(liveData.windpower)级。"
                            )
                        }
                        
                        // 未来天气预报
                        ListRowView(
                            forecasts: viewModel.weatherFutureData?.forecasts.first?.casts.prefix(4).compactMap { $0 } ?? [],
                            title: "未来三日天气预报"
                        )
                    }
                }
            }
        }
    }
}
