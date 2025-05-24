//
//  MoreOptionsView.swift
//  MyWeatherApp
//
//  Created by Star. on 2025/5/16.
//

import SwiftUI

struct MoreOptionsView: View {
    // 注入天气视图模型（用于获取实时/未来天气数据）
    @EnvironmentObject var viewModel: WeatherViewModel
    // 注入全局卡片管理器（用于操作主页面卡片列表）
    @EnvironmentObject private var cardManager: MainCardManager
    // 关闭当前视图的回调（由父视图提供）
    var dismiss: () -> Void
    // 搜索框文本状态（用于双向绑定输入内容）
    @State private var searchText = ""
    // 是否显示搜索结果列表的状态（根据搜索文本是否为空控制）
    @State private var showSearchResults = false
    // 控制天气详情弹窗的显示状态
    @State private var showWeatherPopup = false
    // 存储选中的天气数据模型（用于弹窗展示）
    @State private var selectedWeather: CityWeatherModel?
    // 标记是否是从搜索添加
    @State private var isFromSearch = false
    // 存储默认定位的天气数据
    @State private var defaultLocationWeather: CurrentWeather?
    // 控制视图动画
    @State private var isAppeared = false
    
    var body: some View {
        ZStack {
            BackgroundView()
            VStack(alignment: .leading, spacing: 20) {
                TitleView()
                SearchBarView(searchText: $searchText, showSearchResults: $showSearchResults)
                SearchResultsView(
                    showSearchResults: showSearchResults,
                    searchText: searchText,
                    onCitySelected: handleCitySelected
                )
                WeatherCardsList(
                    defaultLocationWeather: defaultLocationWeather,
                    cardManager: _cardManager,
                    viewModel: _viewModel,
                    dismiss: dismiss
                )
            }
            .scaleEffect(isAppeared ? 1 : 0.5)
            .opacity(isAppeared ? 1 : 0)
        }
        .sheet(isPresented: $showWeatherPopup) {
            WeatherDetailSheet(
                weather: selectedWeather,
                showWeatherPopup: $showWeatherPopup,
                cardManager: _cardManager,
                isFromSearch: $isFromSearch
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: handleOnAppear)
    }
    
    // MARK: - 私有方法
    private func handleCitySelected(_ selectedName: String) {
        Task {
            if DatabaseManager.shared.getAdcode(forName: selectedName) != nil {
                await fetchWeatherData(city: selectedName)
                searchText = ""
                showSearchResults = false
            }
        }
    }
    
    private func handleOnAppear() {
        Task {
            await viewModel.loadDefaultLocation()
            if let weather = createWeatherModel() {
                defaultLocationWeather = weather
            }
            withAnimation(.spring(response: 0.65, dampingFraction: 0.8)) {
                isAppeared = true
            }
        }
    }
    
    /// 异步获取指定城市的天气数据
    /// - Parameter city: 目标城市名称
    private func fetchWeatherData(city: String) async {
        print("开始获取天气数据，城市：\(city)")
        isFromSearch = true
        await viewModel.fetchWeatherData(for: city) { result in
            switch result {
            case .success(let weather):
                selectedWeather = weather
                showWeatherPopup = true
                print("获取数据成功，天气数据：\(weather)")
            case .failure(let error):
                print("天气数据获取失败: \(error)")
            }
        }
    }

    /// 创建当前定位城市的天气模型（用于展示默认卡片）
    /// - Returns: CurrentWeather实例（若数据完整）/nil（数据缺失时）
    private func createWeatherModel() -> CurrentWeather? {
        // 验证实时数据和未来数据是否存在
        guard let liveData = viewModel.weatherLiveData?.lives.first,
              let futureData = viewModel.weatherFutureData?.forecasts.first?.casts.first else {
            return nil
        }
        // 构建并返回天气模型
        return CurrentWeather(
            city: liveData.city,
            temperature: liveData.temperature,
            weatherCondition: liveData.weather,
            highTemperature: futureData.daytemp,
            lowTemperature: futureData.nighttemp
        )
    }

    private func fetchLocation() async {
        print("开始获取位置信息")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            LocationService.shared.requestLocation()
            LocationService.shared.onLocationUpdate = { location, error in
                if let error = error {
                    print("位置获取失败: \(error)")
                    continuation.resume()
                    return
                }
                
                guard let location = location else {
                    print("未获取到位置信息")
                    continuation.resume()
                    return
                }
                
                print("位置获取成功：\(location)")
                Task {
                    do {
                        let cityName = try await getRegionName(from: location)
                        await viewModel.fetchWeatherData(for: cityName) { _ in
                            continuation.resume()
                        }
                    } catch {
                        print("地址解析失败: \(error)")
                        continuation.resume()
                    }
                }
            }
        }
    }
}

// MARK: - 子视图
private struct BackgroundView: View {
    var body: some View {
        Color.blue.ignoresSafeArea().opacity(0.3)
    }
}

private struct TitleView: View {
    var body: some View {
        Text("天气☁️")
            .font(.system(size: 40))
            .fontWeight(.heavy)
            .foregroundColor(.white)
            .padding()
    }
}

private struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var showSearchResults: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(searchText.isEmpty ? Color.white : Color.accentColor)
            
            TextField("搜索城市...", text: $searchText)
                .foregroundColor(Color.accentColor)
                .disableAutocorrection(true)
                .onChange(of: searchText, initial: searchText.isEmpty) { newValue, _ in
                    showSearchResults = !newValue.isEmpty
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    showSearchResults = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(30)
        .padding(.horizontal)
    }
}

private struct SearchResultsView: View {
    let showSearchResults: Bool
    let searchText: String
    let onCitySelected: (String) -> Void
    
    var body: some View {
        if showSearchResults {
            SearchResultList(query: searchText, onSelect: onCitySelected)
                .frame(height: 10)
        }
    }
}

private struct WeatherCardsList: View {
    let defaultLocationWeather: CurrentWeather?
    @EnvironmentObject var cardManager: MainCardManager
    @EnvironmentObject var viewModel: WeatherViewModel
    let dismiss: () -> Void
    
    var body: some View {
        ScrollView {
            Spacer()
            VStack(spacing: 100) {
                if let currentWeather = defaultLocationWeather {
                    SwipeableCardView(weather: currentWeather) {
                        withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                            viewModel.currentCity = currentWeather.city
                            dismiss()
                        }
                    }
                }
                
                ForEach(cardManager.cards) { card in
                    SwipeableCardView(weather: CurrentWeather(
                        city: card.city,
                        temperature: card.temperature,
                        weatherCondition: card.weatherCondition,
                        highTemperature: card.highTemperature,
                        lowTemperature: card.lowTemperature
                    )) {
                        withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                            viewModel.currentCity = card.city
                            dismiss()
                        }
                    }
                }
            }
        }
        .background(Color.clear)
    }
}

private struct WeatherDetailSheet: View {
    let weather: CityWeatherModel?
    @Binding var showWeatherPopup: Bool
    @EnvironmentObject var cardManager: MainCardManager
    @Binding var isFromSearch: Bool
    
    var body: some View {
        if let weather = weather {
            WeatherDetailPopup(
                weather: weather,
                isShowing: $showWeatherPopup,
                backgroundColor: .blue.opacity(0.75)
            )
            .environmentObject(cardManager)
            .onDisappear {
                isFromSearch = false
            }
        }
    }
}

struct SwipeableCardView: View {
    let weather: CurrentWeather
    var onTap: () -> Void
    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    @EnvironmentObject private var cardManager: MainCardManager
    @EnvironmentObject private var viewModel: WeatherViewModel
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 删除按钮背景
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            if let index = cardManager.cards.firstIndex(where: { $0.city == weather.city }) {
                                cardManager.removeCard(at: IndexSet(integer: index))
                            }
                        }
                    }){
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.red)
                                .frame(width: offset < 0 ? -offset : 0, height: 100)  // 宽度跟随offset变化
                            
                            VStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.white)
                                    .font(.title3)
                            }
                        }
                    }
                    .padding(.trailing, 15)
                    .opacity(offset < 0 ? 1 : 0)
                    .animation(.spring(duration: 0.35, bounce: 0.7, blendDuration: 0.8), value: offset)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)  // 固定在右侧
                // 天气卡片
                CardView(weather: weather, onTap: {
                        Task {
                            await viewModel.fetchWeatherData(for: weather.city) { _ in
                                viewModel.currentCity = weather.city
                                onTap()
                            }
                        }
                })
                .frame(height: 100)
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if gesture.translation.width < 0 {
                                self.offset = gesture.translation.width
                            }
                        }
                        .onEnded { gesture in
                            let threshold = geometry.size.width * 0.5
                            let smallThreshold = geometry.size.width * 0.1
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if gesture.translation.width < -threshold {
                                    if let index = cardManager.cards.firstIndex(where: { $0.city == weather.city }) {
                                        cardManager.removeCard(at: IndexSet(integer: index))
                                    }
                                } else if gesture.translation.width < -smallThreshold {
                                    self.offset = -geometry.size.width * 0.2  // 使用相对宽度（20%）而非固定值
                                    self.isSwiped = true
                                } else {
                                    self.offset = 0
                                    self.isSwiped = false
                                }
                            }
                        }
                )
            }
        }
    }
}

#Preview {
    let viewModel = WeatherViewModel()
    return MoreOptionsView(dismiss: {
        print("视图关闭操作")
    })
    .environmentObject(viewModel)
    .environmentObject(MainCardManager())
}


