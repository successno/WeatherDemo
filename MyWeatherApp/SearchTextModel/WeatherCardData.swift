import Foundation
import Combine

class MainCardManager: ObservableObject {
    // 串行队列（保证线程安全的卡片操作）
    private let queue = DispatchQueue(label: "com.example.MainCardManagerQueue")
    // 主页面卡片列表（@Published实现数据绑定）
    @Published var cards: [WeatherCardData] = [] {
        didSet {
            saveCards()
        }
    }
    
    init() {
        loadCards()
    }
    
    private func saveCards() {
        if let encoded = try? JSONEncoder().encode(cards) {
            UserDefaults.standard.set(encoded, forKey: "savedCards")
        }
    }
    
    private func loadCards() {
        if let savedCards = UserDefaults.standard.data(forKey: "savedCards"),
           let decodedCards = try? JSONDecoder().decode([WeatherCardData].self, from: savedCards) {
            cards = decodedCards
        }
    }

    /// 添加天气卡片（自动去重）
    /// - Parameter newCard: 要添加的新卡片实例
    func addCard(_ newCard: WeatherCardData) {
        // 在串行队列中执行去重检查（避免多线程冲突）
        queue.sync {
            // 检查是否已存在相同ADCode的卡片（ADCode是城市唯一标识）
            guard !cards.contains(where: { $0.adcode == newCard.adcode }) else { return }
            // 插入到列表头部（新添加的卡片显示在最前面）
            cards.insert(newCard, at: 0)
        }
    }

    /// 删除指定索引的天气卡片
    /// - Parameter offsets: 要删除的索引集合
    func removeCard(at offsets: IndexSet) {
        for index in offsets {
            // 检查索引是否有效（防止数组越界）
            if index < cards.count {
                cards.remove(at: index)
            } else {
                print("尝试删除的索引超出范围，索引：\(index)，卡片数组长度：\(cards.count)")
            }
        }
    }

    /// 移动卡片位置（支持拖拽排序）
    /// - Parameters:
    ///   - source: 原索引集合
    ///   - destination: 目标索引
    func moveCard(from source: IndexSet, to destination: Int) {
        cards.move(fromOffsets: source, toOffset: destination)
    }
}
