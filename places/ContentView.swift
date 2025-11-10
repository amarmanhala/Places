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
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            if hasSeenOnboarding {
                CustomCameraView(modelContext: modelContext, showPlacesView: $showPlaces)
                    .ignoresSafeArea()
                    .fullScreenCover(isPresented: $showPlaces) {
                        PlacesView()
                    }
            } else {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
