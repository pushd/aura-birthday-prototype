//
//  Aura_Birthday_PrototypeApp.swift
//  Aura Birthday Prototype
//
//  Created by Kunal Bhat on 5/1/26.
//

import SwiftUI
import SwiftData

@main
struct Aura_Birthday_PrototypeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

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
