import SwiftUI


struct HomeslideView: View {
    let weatherText: String
    
    var body: some View {
        ZStack {
//            Color.blue
//                .ignoresSafeArea()
            VStack(alignment: .center) {
                Spacer()
                Text(weatherText)
                Divider()
                Rectangle()
                    .foregroundColor(Color.white)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(timeAndWeather, id: \.0) { item in
                            VStack {
                                Text(item.0)
                                    .font(.callout)
                                    .fontWeight(.bold)
                                Image(systemName: item.1)
                                    .resizable()
                                    .aspectRatio(contentMode:.fit)
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(getIconColor(for: item.1))
                                Text(item.2)
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            .frame(minWidth: 65)
                        }
                    }
                }
                Spacer()
            }
            .background(Color.white)
            .frame(height: 150)
            .cornerRadius(20)
            .padding(20)
        }
    }
    
    private func getIconColor(for iconName: String) -> Color {
        switch iconName {
            case "cloud.fill":
                return Color.blue
            case "sunset.fill":
                return Color.orange
            case "cloud.rain.fill":
                return Color.cyan
            default:
                return Color.primary
        }
    }
    
    // 示例数据，实际应用中应该从API获取
    private let timeAndWeather = [
        ("现在", "cloud.fill", "28°"),
        ("18时", "cloud.fill", "26°"),
        ("18:56", "sunset.fill", "日落"),
        ("19时", "cloud.fill", "26°"),
        ("20时", "cloud.fill", "25°"),
        ("21时", "cloud.fill", "24°"),
        ("22时", "cloud.rain.fill", "24°"),
        ("23时", "cloud.rain.fill", "23°"),
        ("0时", "cloud.rain.fill", "22°"),
        ("1时", "cloud.fill", "20°"),
        ("2时", "cloud.fill", "19°"),
        ("3时", "cloud.fill", "20°"),
        ("4时", "cloud.fill", "20°"),
        ("5时", "cloud.fill", "20°"),
        ("6时", "cloud.fill", "21°"),
        ("7时", "cloud.fill", "22°"),
        ("8时", "cloud.fill", "23°"),
        ("9时", "cloud.fill", "25°"),
        ("10时", "cloud.fill", "26°"),
        ("11时", "cloud.fill", "28°"),
        ("12时", "cloud.fill", "30°"),
        ("13时", "cloud.fill", "32°"),
        ("14时", "cloud.fill", "31°"),
        ("15时", "cloud.fill", "30°"),
        ("16时", "cloud.fill", "30°"),
        ("17时", "cloud.fill", "29°"),
    ]
}



//private func formatTime(_ time: String) -> String {
//    // 示例：将"2025-05-17T18:00:00"转换为"18时"
//    let formatter = DateFormatter()
//    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
//    guard let date = formatter.date(from: time) else { return time }
//    
//    let displayFormatter = DateFormatter()
//    displayFormatter.dateFormat = "HH时"
//    return displayFormatter.string(from: date)
//}

#Preview {
    HomeslideView(weatherText: "今天将持续多云。阵风风速最高25公里/时。")
        .frame(width: .infinity,height: 180)
}

