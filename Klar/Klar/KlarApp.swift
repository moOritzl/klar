//
//  KlarApp.swift
//  Klar
//
//  Created by Moritz Lenhard on 13.07.26.
//

import SwiftUI
import SwiftData

@main
struct KlarApp: App {
    @State private var settings: AppSettings
    private let container: ModelContainer

    init() {
        #if DEBUG
        // Must run before the store is opened and before `AppSettings` reads UserDefaults —
        // a property initializer would have run too early for both.
        if UITestSupport.isResetRequested {
            UITestSupport.reset()
        }
        #endif

        _settings = State(initialValue: AppSettings())

        let container = ModelContainerFactory.makeContainer()
        self.container = container
        try? ContextTagSeeder.seedIfNeeded(context: ModelContext(container))
    }

    var body: some Scene {
        WindowGroup {
            // `RootView` owns the gating (panic façade → app lock → onboarding → tabs).
            // `DebugRootView` is still in the target and can be swapped in here when
            // exercising the persistence layer by hand.
            RootView()
                .modelContainer(container)
                .environment(settings)
        }
    }
}
