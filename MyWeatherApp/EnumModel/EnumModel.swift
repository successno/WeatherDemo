//
//  EnumModel.swift
//  MyWeatherApp
//
//  Created by Star. on 2025/5/23.
//

import Foundation

// MARK: 数据库错误类型
/// 定义数据库操作中可能出现的错误类型
enum DatabaseError: Swift.Error {
    case connectionFailed  // 数据库连接失败
    case fileNotFound      // CSV文件未找到
    case queryFailed(String)  // 查询失败（携带具体错误信息）
}


// MARK: - 自定义错误类型
/// 定位服务错误枚举
/// - 包含定位服务全流程可能出现的错误类型
enum LocationError: Error {
    case dataParsingError
    case locationServiceFailed
    case networkUnavailable
    case locationAuthorizationDenied
    case locationNotFound
    case apiError(String)
    case invalidCoordinate
    case missingAPIKey
    case unknownError(code: Int)
    
    /// 本地化错误描述（用户可见信息）
    var localizedDescription: String {
        switch self {
            case .dataParsingError:
                return "数据解析错误"
            case .locationNotFound:
                return "未找到位置信息"
            case .locationAuthorizationDenied:
                return "定位权限被拒绝"
            case .locationServiceFailed:
                return "定位服务失败"
            case .unknownError(let code):
                return "未知错误，错误码：\(code)"
            case .apiError(let message):
                return "API错误：\(message)"
            case .missingAPIKey:
                return "API密钥缺失"
            case .invalidCoordinate:
                return "无效坐标"
            case .networkUnavailable:
                return "网络连接不可用"
        }
    }
}
