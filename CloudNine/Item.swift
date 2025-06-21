//
//  Item.swift
//  CloudNine
//
//  Created by Mia on 6/21/25.
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
