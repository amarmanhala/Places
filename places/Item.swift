//
//  Item.swift
//  places
//
//  Created by Amarpreet Singh on 11/5/25.
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

@Model
final class CapturedPhoto: Identifiable {
    var id: Date { timestamp }
    var timestamp: Date
    var imageData: Data
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var city: String?
    var state: String?
    var country: String?

    init(timestamp: Date, imageData: Data, latitude: Double, longitude: Double, altitude: Double, city: String? = nil, state: String? = nil, country: String? = nil) {
        self.timestamp = timestamp
        self.imageData = imageData
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.city = city
        self.state = state
        self.country = country
    }
}
