//
//  WeatherIconView.swift
//  WeatherApp
//
//  Created by Star. on 2025/5/8.
import SwiftUI

// 假设获取到的天气情况字符串

struct WeatherIconView: View {
    
    let weather: String
    
    var body: some View {
        Image(systemName: weatherIcon(for: weather))
            .resizable()
            .aspectRatio(contentMode:.fit)
            .frame(width: 30, height: 30)
            .foregroundColor(weatherColor(for: weather))
    }
    
    func weatherIcon(for condition: String) -> String {
        switch condition {
            case "晴": return "sun.max.fill"
            case "少云": return "cloud.sun.fill"
            case "晴间多云": return "cloud.sun.bolt.fill"
            case "多云": return "cloud.sun.fill"
            case "阴": return "cloud.fill"
            case "阵雨": return "cloud.rain.fill"
            case "雷阵雨": return "cloud.bolt.rain.fill"
            case "雷阵雨并伴有冰雹": return "cloud.bolt.hail.fill"
            case "小雨": return "cloud.drizzle.fill"
            case "中雨": return "cloud.heavyrain.fill"
            case "大雨": return "cloud.heavyrain.fill"
            case "暴雨": return "cloud.heavyrain.fill"
            case "大暴雨": return "cloud.heavyrain.fill"
            case "特大暴雨": return "cloud.heavyrain.fill"
            case "强阵雨": return "cloud.heavyrain.fill"
            case "强雷阵雨": return "cloud.heavyrain.fill"
            case "极端降雨": return "cloud.heavyrain.fill"
            case "毛毛雨/细雨": return "cloud.drizzle.fill"
            case "雨": return "cloud.rain.fill"
            case "小雨-中雨": return "cloud.rain.fill"
            case "中雨-大雨": return "cloud.heavyrain.fill"
            case "大雨-暴雨": return "cloud.heavyrain.fill"
            case "暴雨-大暴雨": return "cloud.heavyrain.fill"
            case "大暴雨-特大暴雨": return "cloud.heavyrain.fill"
            case "雪": return "cloud.snow.fill"
            case "阵雪": return "cloud.snow.heavy.fill"
            case "小雪": return "cloud.snow.fill"
            case "中雪": return "cloud.snow.fill"
            case "大雪": return "cloud.snow.fill"
            case "暴雪": return "cloud.snow.bolt.fill"
            case "小雪-中雪": return "cloud.snow.fill"
            case "中雪-大雪": return "cloud.snow.fill"
            case "大雪-暴雪": return "cloud.snow.bolt.fill"
            case "浮尘": return "cloud.dust.fill"
            case "扬沙": return "cloud.dust.bolt.fill"
            case "沙尘暴": return "cloud.dust.bolt.fill"
            case "强沙尘暴": return "cloud.dust.bolt.fill"
            case "龙卷风": return "tornado.fill"
            case "雾": return "cloud.fog.fill"
            case "浓雾": return "cloud.fog.fill"
            case "强浓雾": return "cloud.fog.fill"
            case "轻雾": return "cloud.fog.fill"
            case "大雾": return "cloud.fog.fill"
            case "特强浓雾": return "cloud.fog.fill"
            case "热": return "sun.max.fill"
            case "冷": return "snowflake.fill"
            case "未知": return "questionmark.circle.fill"
            case "有风": return "wind"
            case "平静": return "wind"
            case "微风": return "wind"
            case "和风": return "wind"
            case "清风": return "wind"
            case "强风/劲风": return "wind"
            case "疾风": return "wind"
            case "大风": return "wind"
            case "烈风": return "wind"
            case "风暴": return "wind"
            case "狂爆风": return "wind"
            case "飓风": return "wind"
            case "热带风暴": return "wind"
            case "霾": return "cloud.fog.fill"
            case "中度霾": return "cloud.fog.fill"
            case "重度霾": return "cloud.fog.fill"
            case "严重霾": return "cloud.fog.fill"
            case "雨雪天气": return "cloud.rain.snow.fill"
            case "雨夹雪": return "cloud.rain.snow.fill"
            case "阵雨夹雪": return "cloud.rain.snow.fill"
            case "冻雨": return "cloud.rain.snow.fill"
            default: return "questionmark.circle.fill"
        }
    }
    
    func weatherColor(for condition: String) -> Color {
        switch condition {
            case "晴", "热":
                return .yellow
            case "少云", "晴间多云":
                return .orange.opacity(0.7)
            case "多云", "阴", "雾", "浓雾", "强浓雾", "轻雾", "大雾", "特强浓雾", "霾", "中度霾", "重度霾", "严重霾":
                return .gray
            case "阵雨", "雷阵雨", "雷阵雨并伴有冰雹", "小雨", "中雨", "大雨", "暴雨", "大暴雨", "特大暴雨", "强阵雨", "强雷阵雨", "极端降雨", "毛毛雨/细雨", "雨", "小雨-中雨", "中雨-大雨", "大雨-暴雨", "暴雨-大暴雨", "大暴雨-特大暴雨", "雨雪天气", "雨夹雪", "阵雨夹雪", "冻雨":
                return .blue
            case "雪", "阵雪", "小雪", "中雪", "大雪", "暴雪", "小雪-中雪", "中雪-大雪", "大雪-暴雪":
                return .white
            case "冷":
                return .cyan
            case "浮尘", "扬沙", "沙尘暴", "强沙尘暴":
                return .brown
            case "龙卷风", "有风", "平静", "微风", "和风", "清风", "强风/劲风", "疾风", "大风", "烈风", "风暴", "狂爆风", "飓风", "热带风暴":
                return .gray
            case "未知":
                return .secondary
            default:
                return .secondary
        }
    }
    
}

#Preview {
    WeatherIconView(weather: "多云")
}
