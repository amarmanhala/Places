//
//  placesApp.swift
//  places
//
//  Created by Amarpreet Singh on 11/5/25.
//

import SwiftUI
import SwiftData

@main
struct placesApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            CapturedPhoto.self,
        ])

        // CloudKit sync disabled - requires paid Apple Developer account ($99/year)
        // TODO: Enable when ready: cloudKitDatabase: .automatic
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
