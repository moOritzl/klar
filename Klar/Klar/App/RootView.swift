import SwiftUI
import SwiftData

enum KlarTab: Hashable {
    case today, history, plans, help
}

/// The app shell. Gates, in priority order:
///
/// 1. **Panic façade** (J2) — beats everything, including the lock screen. If someone is
///    looking over the user's shoulder, no other consideration matters.
/// 2. **App lock** (J1) — Face ID / device passcode.
/// 3. **Onboarding** (A1–A4) — one-time.
/// 4. The four tabs.
struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var lockManager = AppLockManager()
    @State private var isPanicActive = false
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
        // The panic gesture is active across the whole app, including mid-flow.
        .overlay {
            if settings.isPanicGestureEnabled {
                MultiTouchTapCatcher(touches: 2, taps: 2) {
                    isPanicActive = true
                }
                .allowsHitTesting(false)
            }
        }
        .fullScreenCover(isPresented: $isPanicActive) {
            PanicView { isPanicActive = false }
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
        .preferredColorScheme(.light) // The design ships light only.
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

// MARK: - Panic gesture

/// Recognizes the two-finger double-tap that swaps the app for the calculator façade.
///
/// SwiftUI's `TapGesture` can't express a touch count, so this drops to UIKit. The recognizer
/// is installed on the **window**, not on this view: a view that covers the screen would either
/// swallow every touch or (if it declined hit-testing) never be delivered any. Living on the
/// window means it observes touches destined for the real UI without consuming them —
/// `cancelsTouchesInView = false` keeps buttons underneath working normally.
struct MultiTouchTapCatcher: UIViewRepresentable {
    let touches: Int
    let taps: Int
    let action: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = WindowAttachingView()
        view.isUserInteractionEnabled = false
        view.onMoveToWindow = { [weak coordinator = context.coordinator] window in
            guard let window, let coordinator, coordinator.recognizer == nil else { return }
            let recognizer = UITapGestureRecognizer(
                target: coordinator,
                action: #selector(Coordinator.handleTap)
            )
            recognizer.numberOfTouchesRequired = touches
            recognizer.numberOfTapsRequired = taps
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesEnded = false
            window.addGestureRecognizer(recognizer)
            coordinator.recognizer = recognizer
            coordinator.window = window
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        var recognizer: UITapGestureRecognizer?
        weak var window: UIWindow?

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func handleTap() {
            action()
        }

        /// Without this, toggling the panic setting off would leave the recognizer on the window.
        func detach() {
            if let recognizer { window?.removeGestureRecognizer(recognizer) }
            recognizer = nil
            window = nil
        }
    }

    private final class WindowAttachingView: UIView {
        var onMoveToWindow: ((UIWindow?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onMoveToWindow?(window)
        }
    }
}
