import SwiftUI
import SwiftData

enum KlarTab: Hashable {
    case today, patterns, help
    /// Not a screen. The round button beside the tab bar that opens „Eintrag erfassen"; selecting
    /// it never sticks (see `tabSelection`).
    case addEntry
}

/// The app shell. Gates, in priority order:
///
/// 1. **App lock** (J1) — Face ID / device passcode.
/// 2. **Onboarding** (A1–A4) — one-time.
/// 3. The three tabs and the „+" beside them.
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

    private func rescheduleReminder() {
        guard settings.hasCompletedOnboarding else { return }
        let store = store
        Task { await MorningReminder.shared.reschedule(store: store, settings: settings) }
    }

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
                // Leaving is when the day's entries are final enough to plan tomorrow's reminder.
                rescheduleReminder()
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
                // Coming back may have answered the day by itself (the card pops up), or the
                // reminder may have been delivered already; either way, plan afresh.
                rescheduleReminder()
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

    /// Lives here because the button that sets it is part of the tab bar, and because
    /// `presentDueMorning()` must not put the morning card over an open entry sheet.
    @State private var isEntrySheetPresented = false
    @State private var patternsSubstanceID: UUID?
    /// „Der Morgen danach" is the one moment the app speaks unprompted. Presented here, on top
    /// of the tabs, so whichever tab is showing cannot swallow it.
    @State private var dueMorning: DueMorning?
    private let reminder = MorningReminder.shared

    private var store: KlarStore { KlarStore(context: modelContext) }

    /// Whether the app-lock overlay (`RootView`) is currently in front of everything, including
    /// this view's own `.sheet`s — a `.sheet` draws in its own window above a parent's `.overlay`,
    /// so the card must not go up while this is true or it is readable without unlocking.
    private var isLocked: Bool { settings.isAppLockEnabled && lockManager.requiresUnlock }

    /// One string for the „+" tab's label and for `TabActionInterceptor`, which recognises the tab
    /// by it.
    static let addEntryTitle = String(localized: "Eintrag erfassen")

    /// The tab bar's selection, with the „+" turned into an action: tapping it opens the entry
    /// sheet and leaves the user on the tab they were on. `TabActionInterceptor` normally catches
    /// the tap before it gets here; this is the fallback if UIKit ever selects the tab anyway.
    private var tabSelection: Binding<KlarTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == .addEntry {
                    isEntrySheetPresented = true
                } else {
                    selectedTab = newTab
                }
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            // The tab label matches the screen's `navigationTitle`, as it does in every
            // first-party app. The case stays `.today` — the file, the screen IDs (B1–B3) and
            // the docs all still call this the Heute screen; only what the user reads changed.
            Tab("Übersicht", systemImage: "house", value: KlarTab.today) {
                TodayView()
                    // Stops UIKit from switching to the empty „+" tab before the binding below
                    // can refuse it — that switch is what made the screen flash.
                    .background(TabActionInterceptor(tabTitle: Self.addEntryTitle) { isEntrySheetPresented = true })
            }

            Tab("Muster", systemImage: "chart.xyaxis.line", value: KlarTab.patterns) {
                PatternsView(selectedSubstanceID: $patternsSubstanceID)
            }

            Tab("Hilfe", systemImage: "lifepreserver", value: KlarTab.help) {
                HelpView()
            }

            // Logging is the app's one recurring action, so it gets the separate round button at
            // the trailing end of the tab bar: under the thumb, on every tab, and without a second
            // bar stacked on the first. iOS only draws that button for the search role; the role
            // decides the placement, the label and `tabSelection` decide what it does.
            Tab(Self.addEntryTitle, systemImage: "plus", value: KlarTab.addEntry, role: .search) {
                Color.clear
            }
        }
        // No `tabBarMinimizeBehavior`. It was tried and it strands the user: once the bar has
        // minimized, scrolling back to the top does not bring it back on these screens, and the
        // other tabs are simply gone. Trading permanent access to Muster and Hilfe for a bit of
        // scroll polish is not a trade worth making on a three-tab app.
        .sheet(isPresented: $isEntrySheetPresented) {
            EntrySheetView()
        }
        // Dismissing writes nothing: swiping the card away is „Später", and the day waits in
        // „Mitteilungen". Only the card's own „Überspringen" records a skip.
        //
        // Closing the first card is also when iOS is asked for permission to send the reminder:
        // the user has just seen what it would be for. Asked once; iOS remembers the answer.
        .sheet(item: $dueMorning, onDismiss: {
            guard settings.isMorningReminderEnabled else { return }
            Task { await reminder.requestAuthorizationIfUndetermined() }
        }) { due in
            MorningAfterCardView(dayKey: due.dayKey)
                .presentationBackground(.clear)
                // The once-a-day pop-up is spent when the card is actually on screen, not when
                // it was queued — a sheet SwiftUI does not present must not use the day up.
                // Never moved backwards: a tapped reminder can open an older day.
                .onAppear {
                    if (settings.lastPresentedMorningDayKey ?? "") < due.dayKey {
                        settings.lastPresentedMorningDayKey = due.dayKey
                    }
                }
        }
        .task { presentDueMorning() }
        .onChange(of: foregroundTick) { _, _ in
            // The morning after usually starts with the app still in the background from the
            // night before, so checking only at launch would miss it. Driven by `RootView`'s
            // counter rather than `scenePhase` directly — see the doc comment on
            // `foregroundTick` above.
            presentDueMorning()
        }
        .onChange(of: reminder.tappedDayKey) { _, _ in
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
        if presentTappedReminder() { return }
        let dueKey = store.dueMorningAfterDay()
        guard Self.shouldPresentMorning(
            isLocked: isLocked,
            isEntrySheetPresented: isEntrySheetPresented,
            dueMorning: dueMorning,
            dueKey: dueKey,
            lastPresentedKey: settings.lastPresentedMorningDayKey
        ) else { return }
        dueMorning = dueKey.map(DueMorning.init)
    }

    /// A tapped „Wie war der Morgen?" opens that day's card even if the card already popped up
    /// for it — the user asked for it. Waits while locked; dropped once the day is answered or
    /// can no longer be.
    private func presentTappedReminder() -> Bool {
        guard let key = reminder.tappedDayKey,
              !isLocked, dueMorning == nil, !isEntrySheetPresented
        else { return false }
        reminder.tappedDayKey = nil
        guard store.openMorningAfterDays().contains(key) else { return false }
        dueMorning = DueMorning(dayKey: key)
        return true
    }

    /// Pulled out of `presentDueMorning()` so the guard is testable without `AppLockManager`'s
    /// Face ID plumbing or a real `TabView`. A day the card already popped up for, or an
    /// older one that becomes due again (the newer day's entries were deleted), is not presented
    /// again — P9: every question is asked by itself once. Day keys sort as strings.
    static func shouldPresentMorning(
        isLocked: Bool,
        isEntrySheetPresented: Bool,
        dueMorning: DueMorning?,
        dueKey: String?,
        lastPresentedKey: String?
    ) -> Bool {
        guard !isLocked, dueMorning == nil, !isEntrySheetPresented, let dueKey else { return false }
        guard let lastPresentedKey else { return true }
        return dueKey > lastPresentedKey
    }
}

/// `sheet(item:)` needs an Identifiable payload.
struct DueMorning: Identifiable {
    let dayKey: String
    var id: String { dayKey }
}
