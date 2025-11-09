//
//  Item.swift
//  places
//
//  Created by Amarpreet Singh on 11/5/25.
//

import Foundation
import SwiftData
import MapKit

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
    var address: String?
    var phoneNumber: String?
    var extractedText: String?
    var category: String?

    init(timestamp: Date, imageData: Data, latitude: Double, longitude: Double, altitude: Double, city: String? = nil, state: String? = nil, country: String? = nil, address: String? = nil, phoneNumber: String? = nil, extractedText: String? = nil, category: String? = nil) {
        self.timestamp = timestamp
        self.imageData = imageData
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.city = city
        self.state = state
        self.country = country
        self.address = address
        self.phoneNumber = phoneNumber
        self.extractedText = extractedText
        self.category = category
    }
}

// Category Helper
class CategoryHelper {
    static func categorize(poiCategory: MKPointOfInterestCategory?, extractedText: String?) -> String {
        // Try MapKit POI category first
        if let poi = poiCategory {
            return mapPOICategory(poi)
        }

        // Fallback to keyword matching
        if let text = extractedText?.lowercased() {
            return categorizeByKeyword(text)
        }

        return "Other"
    }

    private static func mapPOICategory(_ poi: MKPointOfInterestCategory) -> String {
        switch poi {
        // Food & Drink
        case .restaurant, .bakery, .brewery, .winery:
            return "Food"
        case .cafe:
            return "Cafe"
        case .foodMarket:
            return "Food"

        // Entertainment
        case .movieTheater, .theater, .nightlife, .amusementPark, .aquarium, .museum, .zoo:
            return "Entertainment"

        // Shopping
        case .store, .laundry, .library, .pharmacy, .postOffice:
            return "Shopping"

        // Travel & Transport
        case .airport, .hotel, .gasStation, .evCharger, .parking, .carRental, .publicTransport:
            return "Travel"

        // Health & Fitness
        case .hospital, .pharmacy, .fitnessCenter:
            return "Health"

        // Services
        case .bank, .atm, .restroom:
            return "Services"

        // Nature & Parks
        case .park, .beach, .campground, .nationalPark:
            return "Nature"

        default:
            return "Other"
        }
    }

    private static func categorizeByKeyword(_ text: String) -> String {
        // Food keywords
        let foodKeywords = ["restaurant", "food", "pizza", "burger", "sushi", "taco", "bbq", "grill", "kitchen", "dining", "eat", "buffet", "deli", "bistro"]
        if foodKeywords.contains(where: text.contains) {
            return "Food"
        }

        // Cafe keywords
        let cafeKeywords = ["cafe", "coffee", "starbucks", "espresso", "latte", "tea", "bakery"]
        if cafeKeywords.contains(where: text.contains) {
            return "Cafe"
        }

        // Entertainment keywords
        let entertainmentKeywords = ["cinema", "theater", "movie", "concert", "club", "bar", "pub", "arcade", "bowling", "museum", "gallery"]
        if entertainmentKeywords.contains(where: text.contains) {
            return "Entertainment"
        }

        // Shopping keywords
        let shoppingKeywords = ["store", "shop", "market", "mall", "boutique", "outlet"]
        if shoppingKeywords.contains(where: text.contains) {
            return "Shopping"
        }

        // Travel keywords
        let travelKeywords = ["hotel", "motel", "inn", "resort", "airport", "station"]
        if travelKeywords.contains(where: text.contains) {
            return "Travel"
        }

        return "Other"
    }
}
