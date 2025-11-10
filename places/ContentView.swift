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
    @State private var showOnboarding = true

    var body: some View {
        ZStack {
            CustomCameraView(modelContext: modelContext, showPlacesView: $showPlaces)
                .ignoresSafeArea()
                .fullScreenCover(isPresented: $showPlaces) {
                    PlacesView()
                }

            if !hasSeenOnboarding && showOnboarding {
                OnboardingView(showOnboarding: $showOnboarding)
                    .transition(.opacity)
                    .onChange(of: showOnboarding) { oldValue, newValue in
                        if !newValue {
                            hasSeenOnboarding = true
                        }
                    }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
