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
    @State private var lockManager = AppLockManager()
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer

    init() {
        let container = ModelContainerFactory.makeContainer()
        self.container = container
        try? ContextTagSeeder.seedIfNeeded(context: ModelContext(container))
    }

    var body: some Scene {
        WindowGroup {
            DebugRootView()
                .modelContainer(container)
                .overlay {
                    if lockManager.requiresUnlock {
                        AppLockOverlayView(lockManager: lockManager)
                    } else if scenePhase != .active {
                        SnapshotShieldView()
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                lockManager.lock()
            }
        }
    }
}
