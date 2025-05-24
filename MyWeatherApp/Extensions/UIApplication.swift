//
//  UIApplication.swift
//  MyWeatherApp
//
//  Created by Star. on 2025/5/13.
//

import Foundation
import SwiftUI

extension UIApplication {
    
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
}
