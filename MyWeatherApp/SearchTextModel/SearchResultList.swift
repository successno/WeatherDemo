//
//  SearchResultList.swift
//  MyWeatherApp
//
//  Created by Star. on 2025/5/20.
//

import SwiftUI

struct SearchResultList: View {
    let query: String
    
    let onSelect: (String) -> Void // 选中地区回调
    
    var body: some View {
        // 从数据库获取模糊匹配结果
        let results = DatabaseManager.shared.searchRegionsName(query)
        
        if !results.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(results, id: \.self) { name in
                        Button(action: { onSelect(name) }) {
                            Text(name)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
