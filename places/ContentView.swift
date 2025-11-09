//
//  ContentView.swift
//  places
//
//  Created by Amarpreet Singh on 11/5/25.
//

import SwiftUI
import SwiftData
import CoreLocation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showPlaces = false

    var body: some View {
        CustomCameraView(modelContext: modelContext, showPlacesView: $showPlaces)
            .ignoresSafeArea()
            .fullScreenCover(isPresented: $showPlaces) {
                PlacesView()
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
