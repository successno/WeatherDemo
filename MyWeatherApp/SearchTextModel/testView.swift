import SwiftUI

struct TestView: View {
    // 绑定父视图的搜索文本（用于双向数据同步）
    @Binding var searchText: String
    // 控制错误提示弹窗的显示状态
    @State private var showErrorAlert = false
    // 控制天气详情弹窗的显示状态
    @State private var showWeatherPopup = false
    // 视图模型（使用@StateObject保证生命周期与视图一致）
    @StateObject private var viewModel = WeatherViewModel()
    // 存储选中的天气数据模型（用于弹窗展示）
    @State private var selectedWeather: CityWeatherModel?
    // 存储选中城市的ADCode（用于API请求）
    @State private var selectedAdcode: String?
    // 绑定主页面的天气卡片数组（用于同步新增卡片）
    @Binding var weatherCards: [WeatherCardData]
    // 通过环境对象获取全局卡片管理器（用于操作主页面卡片列表）
    @EnvironmentObject private var mainCardManager: MainCardManager

    var body: some View {
        VStack(spacing: 20) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(searchText.isEmpty ? Color.white : Color.accentColor)
                
                TextField("搜索城市...", text: $searchText)
                    .foregroundColor(Color.accentColor)
                    .disableAutocorrection(true)
                    .overlay(
                        Image(systemName: "xmark.circle.fill")
                            .padding(.trailing)
                            .foregroundColor(Color.white)
                            .opacity(searchText.isEmpty ? 0.0 : 1.0)
                            .onTapGesture {
                                searchText = ""
                                UIApplication.shared.endEditing()
                            },
                        alignment: .trailing
                    )
                
                .padding()
                .disabled(searchText.isEmpty) // 无内容时禁用按钮
            }
            .padding(.horizontal)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.gray.opacity(0.7))
                    .shadow(radius: 10)
            )
            
            // 新增：搜索结果列表（基于数据库模糊查询）
            if !searchText.isEmpty {
                SearchResultList(query: searchText) { selectedName in
                    // 选中地区后获取ADCode
                    Task{
                        if let adcode = DatabaseManager.shared.getAdcode(forName: selectedName) {
                        self.selectedAdcode = adcode
                           await self.fetchAndAddWeatherCard(adcode: adcode) { result in
                                switch result {
                                    case .success(let cardData):
                                        // 可选：处理成功添加卡片后的逻辑
                                        print("成功添加卡片: \(cardData.city)")
                                    case .failure(let error):
                                        print("添加卡片失败: \(error)")
                                        self.showErrorAlert = true
                                }
                            }
                        } else {
                            showErrorAlert = true
                        }
                    }
                       
                }
            }
            
        }
        .alert("错误", isPresented: $showErrorAlert){
            Button("确定", role: .cancel) {
            }
     }message: {
            Text(viewModel.error?.localizedDescription ?? "未知错误")
     }
        
     .sheet(isPresented: $showWeatherPopup) {
         // 添加 Sheet 弹窗
         if let weather = selectedWeather { // 确保天气数据存在
             WeatherDetailPopup(
                weather: weather,
                isShowing: $showWeatherPopup, backgroundColor: .blue.opacity(0.75) // 绑定弹窗关闭状态
             )
             .environmentObject(mainCardManager) // 注入卡片管理器
            }
         
        }
    }

    
    /// 单独的天气数据获取方法（分离查询与弹窗逻辑）
    /// - Parameter city: 目标城市的ADCode
    private func fetchWeatherData(city: String) async {
        print("开始获取天气数据，ADCode: \(city)") // 添加日志
        await viewModel.fetchWeatherData(for: city) { result in
            switch result {
            case .success(let weather):
                // 保存获取到的天气数据并触发弹窗
                selectedWeather = weather
                print("selectedWeather被赋值为：\(weather)，对应城市：\(city)")
                showWeatherPopup = true // 显示弹窗
                
                // 调试日志（验证弹窗状态变更）
                print("showWeatherPopup被设置为true: \(showWeatherPopup)")
                DispatchQueue.main.asyncAfter(deadline:.now() + 1) {
                    print("1秒后showWeatherPopup的值: \(showWeatherPopup)")
                }
                print("获取数据成功，天气数据：\(weather)") // 添加日志
            case .failure(let error):
                // 数据获取失败时显示错误提示
                showErrorAlert = true
                print("天气数据获取失败: \(error)")
            }
        }
    }

    /// 获取天气数据并添加到主页面卡片列表
    /// - Parameters:
    ///   - adcode: 目标城市的ADCode
    ///   - completion: 结果回调（成功返回新卡片，失败返回错误）
    private func fetchAndAddWeatherCard(adcode: String, completion: @escaping (Result<WeatherCardData, WeatherError>) -> Void) async {
        await viewModel.fetchWeatherData(for: adcode){ result in
            switch result {
            case .success(let CityWeatherModel):
                // 创建天气卡片数据（需从数据库获取城市名称）
                if let cityName = DatabaseManager.shared.getCityNameByAdcode(adcode) {
                    let currentWeather = CityWeatherModel.live
                    let futureWeather = CityWeatherModel.future
                    let temperature = currentWeather.first?.temperature
                    let weatherCondition = currentWeather.first?.weather
                    let highTemperature = futureWeather.first?.daytemp_float
                    let lowTemperature = futureWeather.first?.nighttemp_float
                    
                    // 构建新卡片实例
                    let newCard = WeatherCardData(
                        city: cityName,
                        temperature: temperature!,
                        weatherCondition: weatherCondition!,
                        highTemperature: highTemperature,
                        lowTemperature: lowTemperature,
                        currentWeather: currentWeather,
                        futureWeather: futureWeather,
                        cityName: cityName,
                        adcode: adcode
                    )
                    
                    // 添加到主页面卡片列表（通过全局管理器）
                    mainCardManager.addCard(newCard)
                    print("已成功将卡片添加到列表，城市: \(newCard.cityName)")
                    showWeatherPopup = true // 显示天气详情（可选）
                    completion(.success(newCard)) // 传递正确实例 
                }
            case .failure(let error):
                // 数据获取失败时触发错误回调
                print("天气数据获取失败: \(error)")
                showErrorAlert = true
                completion(.failure(error)) // 传递错误结果
            }
        }
    }
}

    
#Preview {
    // 预览时使用环境对象（与视图内的 @StateObject 保持一致）
    let binding = Binding<[WeatherCardData]>(get: {
        MainCardManager().cards
    }, set: { newValue in
        // 这里可以添加保存新值的逻辑，如果需要的话
    })
    
    TestView(searchText: .constant("北京市") , weatherCards: binding)
        .environmentObject(WeatherViewModel())
        .environmentObject(MainCardManager())
}


