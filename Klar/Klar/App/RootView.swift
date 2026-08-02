import SwiftUI
import SwiftData

enum KlarTab: Hashable {
    case today, history, plans, help
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

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        ZStack {
            if settings.hasCompletedOnboarding {
                MainTabView(selectedTab: $selectedTab)
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
            guard settings.isAppLockEnabled else { return }
            if newPhase == .background {
                lockManager.scheduleLock(after: TimeInterval(settings.autoLockDelay.rawValue))
            } else if newPhase == .active {
                lockManager.cancelPendingLockIfStillWithinGrace()
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
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    /// The plan check-in (D1) and the weekly review (F1–F3) are the only two moments the app
    /// speaks unprompted. Both are presented here, on top of the tabs, so they can't be
    /// swallowed by whichever tab happens to be showing.
    @State private var pendingCheckIn: PendingCheckIn?
    @State private var isReviewPresented = false

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(selectedTab: $selectedTab)
                .tabItem { Label("Heute", systemImage: "house") }
                .tag(KlarTab.today)

            HistoryView()
                .tabItem { Label("Verlauf", systemImage: "chart.bar") }
                .tag(KlarTab.history)

            PlansView()
                .tabItem { Label("Pläne", systemImage: "checkmark.circle") }
                .tag(KlarTab.plans)

            HelpView()
                .tabItem { Label("Hilfe", systemImage: "lifepreserver") }
                .tag(KlarTab.help)
        }
        .sheet(item: $pendingCheckIn) { pending in
            PlanCheckInView(plan: pending.plan, entry: pending.entry)
                .presentationBackground(.clear)
        }
        .fullScreenCover(isPresented: $isReviewPresented) {
            WeeklyReviewFlowView()
        }
        .task {
            await presentDueMoments()
        }
    }

    /// Runs once per foregrounding. Check-in first — it's about a concrete entry and is the
    /// tighter loop; the review can wait a beat.
    private func presentDueMoments() async {
        if let pending = store.pendingCheckIn() {
            pendingCheckIn = PendingCheckIn(plan: pending.plan, entry: pending.entry)
            return
        }
        if WeeklyReviewSummary.isReviewDue(
            lastReviewedWeekStart: settings.lastReviewedWeekStart,
            hasAnyEntries: !store.allEntries().isEmpty
        ) {
            isReviewPresented = true
        }
    }
}

/// `sheet(item:)` needs a single Identifiable payload.
struct PendingCheckIn: Identifiable {
    let plan: Plan
    let entry: Entry
    var id: UUID { entry.id }
}
