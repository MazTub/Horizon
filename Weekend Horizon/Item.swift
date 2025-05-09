//
//  Item.swift
//  Weekend Horizon
//
//  Created by Thomas Mazhar-Elstub on 09/05/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
