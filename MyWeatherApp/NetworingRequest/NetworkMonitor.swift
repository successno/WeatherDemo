//
//  NetworkMonitor.swift
//  MyWeatherApp
//
//  Created by Star. on 2025/5/17.
//

import Foundation
import Network
import Combine

class NetworkMonitor: NSObject, ObservableObject {
    
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private var lastConnectionState: Bool?
    
    @Published var isConnected = false {
        didSet {
            // 只在状态真正改变时输出日志
            if lastConnectionState != isConnected {
                print("📡 网络状态：\(isConnected ? "已连接" : "未连接")")
                lastConnectionState = isConnected
            }
        }
    }

    
    private override init() {
        super.init()
        startMonitoring()
    }

    func startMonitoring() {
        let queue = DispatchQueue(label: "NetworkMonitorQueue")
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
