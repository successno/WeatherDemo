////
////  AMapRegeoResponse.swift
////  MyWeatherApp
////
////  Created by Star. on 2025/5/17.
////
//
import Foundation

/// 顶层响应结构体
struct AMapRegeoResponse: Codable {
    let status: String
    let regeocode: Regeocode
    let info: String
    let infocode: String
    
    enum CodingKeys: String, CodingKey {
        case status, info, regeocode,infocode
    }
}

// 逆地理编码结果结构体
struct Regeocode: Codable {
    let addressComponent: AMapAddressComponent?
    let formattedAddress: String  // 对应JSON中的formatted_address（使用CodingKeys适配下划线命名）
    
    enum CodingKeys: String, CodingKey {
        case addressComponent = "addressComponent"
        case formattedAddress = "formatted_address"
    }
}

// 地址组件结构体
struct AMapAddressComponent: Codable {
    let city: [String]          // JSON中为[]，用空数组表示
    let province: String
    let adcode: String
    let district: String
    let towncode: [String]      // JSON中为[]
    let streetNumber: StreetNumber
    let country: String
    let township: [String]      // JSON中为[]
    let seaArea: String
    let businessAreas: [[String]]  // JSON中为[[]]
    let building: Building
    let neighborhood: Neighborhood
    let citycode: String

    var safeCity: String {
        city.isEmpty ? "" : city.first ?? ""
    }
}

// 街道号码信息结构体
struct StreetNumber: Codable {
    let number: String
    let location: String  // 经纬度字符串（如"114.158303,22.284686"）
    let direction: String
    let distance: String
    let street: String
}

// 建筑物信息结构体
struct Building: Codable {
    let name: String
    let type: String
}

// 社区信息结构体
struct Neighborhood: Codable {
    let name: [String]  // JSON中为[]
    let type: [String]  // JSON中为[]
}
