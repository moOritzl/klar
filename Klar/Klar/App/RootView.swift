import SwiftUI
import SwiftData

enum KlarTab: Hashable {
    case today, history, limits, help
}

/// The app shell. Gates, in priority order:
///
/// 1. **App lock** (J1) — Face ID / device passcode.
/// 2. **Onboarding** (A1–A4) — one-time.
/// 3. The four tabs.
struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var lockManager = AppLockManager()
    @State private var selectedTab: KlarTab = .today
    /// Bumped only after this view has finished applying a `.active` scenePhase change to
    /// `lockManager` — the signal `MainTabView` waits for before re-checking whether to present
    /// „Der Morgen danach". See the comment on `MainTabView.foregroundTick` for why this exists
    /// instead of `MainTabView` listening to `scenePhase` itself.
    @State private var foregroundTick = 0

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        ZStack {
            if settings.hasCompletedOnboarding {
                MainTabView(selectedTab: $selectedTab, lockManager: lockManager, foregroundTick: foregroundTick)
            } else {
                OnboardingFlowView()
            }
        }
        .overlay {
            if settings.isAppLockEnabled && lockManager.requiresUnlock {
                AppLockOverlayView(lockManager: lockManager)
            } else if scenePhase != .active {
                // App-switcher snapshot protection: iOS screenshots the window when we
                // resign active, so the real content must already be gone by then.
                SnapshotShieldView()
            }
        }
        .background(WindowAppearance(style: settings.appearance.uiStyle))
        .tint(Klar.accent)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                if settings.isAppLockEnabled {
                    lockManager.scheduleLock(after: TimeInterval(settings.autoLockDelay.rawValue))
                }
            } else if newPhase == .active {
                if settings.isAppLockEnabled {
                    lockManager.cancelPendingLockIfStillWithinGrace()
                }
                // Only now — the lock decision above, if any, is final. `MainTabView` must not
                // re-check on `scenePhase` itself: SwiftUI runs a child's `.onChange(of:)` for a
                // shared observed value *before* the parent's, so a listener there would read
                // `lockManager` before the line above ever ran. Bumping this afterwards, from a
                // single ordered place, makes the dependency explicit instead of relying on
                // handler-dispatch order.
                foregroundTick += 1
            }
        }
        .task {
            if !settings.isAppLockEnabled {
                lockManager.unlockWithoutAuthentication()
            }
        }
    }
}

// MARK: - Tabs

struct MainTabView: View {
    @Binding var selectedTab: KlarTab
    /// Read directly rather than as a passed-in `Bool`, so `isLocked` below always reflects
    /// `lockManager`'s current state at the moment it's read.
    let lockManager: AppLockManager
    /// Bumped by `RootView` on every return to `.active`, strictly *after* it has applied that
    /// scenePhase change to `lockManager` (see `RootView.body`'s `.onChange(of: scenePhase)`).
    ///
    /// This view used to listen to `scenePhase` itself for the same purpose, but that races
    /// `RootView`'s own handler: SwiftUI runs a child's `.onChange(of:)` for a shared observed
    /// value *before* the parent's, so with an auto-lock delay ("Nach 1 Minute") this view's
    /// handler fired first, read `isLocked == false` — the deferred lock hadn't been applied yet —
    /// and presented the card; only afterwards did `RootView` lock, leaving the card above the
    /// lock screen. Reading `lockManager` live does not fix that particular race: the problem
    /// isn't a stale *value*, it's that the parent's write plainly had not happened yet when this
    /// view's handler ran. `foregroundTick` is a value `RootView` only changes after that write,
    /// so this view reacting to it is necessarily ordered after — a real data dependency instead
    /// of an assumption about `onChange` dispatch order.
    let foregroundTick: Int
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    /// Lives here rather than in `TodayView` because the button that sets it does too — the
    /// bottom accessory is a property of the `TabView`, not of any one tab.
    @State private var isEntrySheetPresented = false
    /// „Der Morgen danach" is the one moment the app speaks unprompted. Presented here, on top
    /// of the tabs, so whichever tab is showing cannot swallow it.
    @State private var dueMorning: DueMorning?
    /// Kept apart from `dueMorning`, which is already `nil` by the time `onDismiss` runs.
    @State private var presentedMorningKey: String?

    private var store: KlarStore { KlarStore(context: modelContext) }

    /// Whether the app-lock overlay (`RootView`) is currently in front of everything, including
    /// this view's own `.sheet`s — a `.sheet` draws in its own window above a parent's `.overlay`,
    /// so the card must not go up while this is true or it is readable without unlocking.
    private var isLocked: Bool { settings.isAppLockEnabled && lockManager.requiresUnlock }

    var body: some View {
        TabView(selection: $selectedTab) {
            // The tab label matches the screen's `navigationTitle`, as it does in every
            // first-party app. The case stays `.today` — the file, the screen IDs (B1–B3) and
            // the docs all still call this the Heute screen; only what the user reads changed.
            TodayView()
                .tabItem { Label("Übersicht", systemImage: "house") }
                .tag(KlarTab.today)

            HistoryView()
                .tabItem { Label("Verlauf", systemImage: "chart.bar") }
                .tag(KlarTab.history)

            LimitsView()
                .tabItem { Label("Grenzen", systemImage: "gauge.with.dots.needle.33percent") }
                .tag(KlarTab.limits)

            HelpView()
                .tabItem { Label("Hilfe", systemImage: "lifepreserver") }
                .tag(KlarTab.help)
        }
        // Logging is the app's one recurring action, and it is reachable from every tab rather
        // than only from Übersicht — which is what the accessory slot is for, and a small gain
        // over the corner button it replaces.
        .tabViewBottomAccessory {
            KlarLogEntryAccessory { isEntrySheetPresented = true }
        }
        // No `tabBarMinimizeBehavior`. It was tried and it strands the user: once the bar has
        // minimized, scrolling back to the top does not bring it back on these screens, and three
        // of the four tabs are simply gone. Trading permanent access to Verlauf, Grenzen and Hilfe
        // for a bit of scroll polish is not a trade worth making on a four-tab app.
        .sheet(isPresented: $isEntrySheetPresented) {
            EntrySheetView()
        }
        .sheet(item: $dueMorning, onDismiss: {
            // Swiping the card away is a skip. After „Fertig" the record exists and this is a no-op.
            if let key = presentedMorningKey { store.skipMorningAfter(dayKey: key) }
            presentedMorningKey = nil
        }) { due in
            MorningAfterCardView(dayKey: due.dayKey)
                .presentationBackground(.clear)
        }
        .task { presentDueMorning() }
        .onChange(of: foregroundTick) { _, _ in
            // The morning after usually starts with the app still in the background from the
            // night before, so checking only at launch would miss it. Driven by `RootView`'s
            // counter rather than `scenePhase` directly — see the doc comment on
            // `foregroundTick` above.
            presentDueMorning()
        }
        .onChange(of: isLocked) { _, isLocked in
            // Unlocking is itself a trigger: the day may have been due since before the phase
            // even changed (Face ID can take a while), and `scenePhase` already went `.active`
            // while still locked.
            if !isLocked { presentDueMorning() }
        }
    }

    private func presentDueMorning() {
        // Never above the lock screen: a `.sheet` draws in its own window, in front of
        // `RootView`'s `.overlay`, so presenting here while locked would make the card readable
        // without unlocking. (Pre-existing, out of scope: a sheet already open when the app
        // backgrounds sits above the lock too — that needs a window-level lock, not this guard.)
        let dueKey = store.dueMorningAfterDay()
        guard Self.shouldPresentMorning(
            isLocked: isLocked, isEntrySheetPresented: isEntrySheetPresented, dueMorning: dueMorning, dueKey: dueKey
        ) else { return }
        presentedMorningKey = dueKey
        dueMorning = dueKey.map(DueMorning.init)
    }

    /// Pulled out of `presentDueMorning()` so the guard is testable without `AppLockManager`'s
    /// Face ID plumbing or a real `TabView`.
    static func shouldPresentMorning(isLocked: Bool, isEntrySheetPresented: Bool, dueMorning: DueMorning?, dueKey: String?) -> Bool {
        !isLocked && dueMorning == nil && !isEntrySheetPresented && dueKey != nil
    }
}

/// `sheet(item:)` needs an Identifiable payload.
struct DueMorning: Identifiable {
    let dayKey: String
    var id: String { dayKey }
}
