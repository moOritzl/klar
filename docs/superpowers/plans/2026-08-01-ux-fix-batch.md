# Klar UX Fix Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the thirteen issues from the 2026-08-01 test pass — working Face ID, no dead lock screen, no panic gesture, one import/export format, controls in thumb reach, a usable calendar, a fitted entry sheet, de-slopped German copy, and a real dark mode defaulting to System.

**Architecture:** Eight independent phases against an existing SwiftUI + SwiftData app. Pure logic (`AppLockManager`, `ExportImportService`, month math) is unit-tested through XCTest; view layout is verified by screenshot in the simulator, because SwiftUI layout has no meaningful unit test. One new design-system container (`KlarScreen`) carries the layout change for three tabs, so the rule lives in one file rather than three.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, LocalAuthentication, XCTest, Xcode project at `Klar/Klar.xcodeproj`, local SPM package `Packages/KlarCore`. Deployment target iOS 26.5.

**Spec:** [2026-08-01-ux-fix-batch-design.md](../specs/2026-08-01-ux-fix-batch-design.md)

---

## Conventions for every task

Run unit tests with:

```bash
xcodebuild test -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' -only-testing:KlarTests 2>&1 | tail -20
```

Expected on a green run: `** TEST SUCCEEDED **`. Baseline before this plan starts: 12 tests, 0 failures.

Build only (faster, for view-only changes):

```bash
xcodebuild build -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

All paths below are relative to the repo root `/Users/moritzlenhard/PycharmProjects/klar`, and
every command is written to be run **from the repo root**. Do not `cd` into `Klar/` — the
`-project` flag is there precisely so you do not have to.

Branch: `feat/ux-fix-batch`. Every task commits there.

**Pin the simulator by UDID, never by name.** This machine has two devices called
`iPhone 17 Pro`, and only `D9360641-F9CD-4536-870B-3D66A89F6FEE` is a valid destination for the
Klar scheme. Passing `name=iPhone 17 Pro` resolves ambiguously and fails at launch with
`FBSOpenApplicationServiceErrorDomain ... "Application failed preflight checks" (Busy)`, which
looks like a test failure but is not one. Every command below is already pinned; keep it that way.
If you do see that error, it is the simulator, not the code — shut the device down and retry
rather than changing anything.

**Verification you cannot automate.** Face ID enrollment (Simulator → Features → Face ID →
Enrolled) and the export/import round trip through the Files app need a human at the keyboard.
Drive as far as you can with the simulator tooling, then state plainly in your report which steps
you could not perform. Do not claim a manual check passed because the code looks right.

Comments in this codebase are English and explain *why*, not *what*. Match that. Do not add a comment that restates the line below it.

---

## File Structure

**New files**

| File | Responsibility |
|---|---|
| `Klar/Klar/DesignSystem/KlarScreen.swift` | The banner-on-top / controls-at-the-bottom screen container. One file, because three tabs share it and it is not a "component" in the sense the rest of `KlarComponents.swift` is. |
| `Klar/Klar/App/AppAppearance.swift` | The `system / light / dark` enum and its `ColorScheme?` mapping. Separate from `AppSettings` so the theme layer can import it without pulling in every preference. |
| `Klar/KlarTests/AppLockManagerTests.swift` | Lock re-arm and no-double-evaluation invariants. |

**Modified files**

| File | Change |
|---|---|
| `Klar/Klar.xcodeproj/project.pbxproj` | `INFOPLIST_KEY_NSFaceIDUsageDescription` in both configs. |
| `Klar/Klar/Security/AppLockManager.swift` | Injectable authentication, cancel vs. failure, `isAuthenticating`. |
| `Klar/Klar/Security/AppLockOverlayView.swift` | Re-trigger on `scenePhase`. |
| `Klar/Klar/Security/PanicView.swift` | Deleted. |
| `Klar/Klar/App/RootView.swift` | Panic gate and `MultiTouchTapCatcher` removed; appearance applied. |
| `Klar/Klar/App/AppSettings.swift` | `isPanicGestureEnabled` removed, `appearance` added. |
| `Klar/Klar/Persistence/ExportImportService.swift` | `exportCSV` removed; `importJSON` split into `decode` + `restore`. |
| `Klar/Klar/Features/Settings/DataManagementView.swift` | CSV out, import in. |
| `Klar/Klar/Features/Settings/SettingsView.swift` | Panic row out, appearance row in. |
| `Klar/Klar/Features/Help/HelpView.swift` | Adopts `KlarScreen`. |
| `Klar/Klar/Features/History/HistoryView.swift` | Adopts `KlarScreen`, stat tiles to banner, segmented control to bottom bar, swipe gesture. |
| `Klar/Klar/Features/Plans/PlansView.swift` | Adopts `KlarScreen`. |
| `Klar/Klar/Features/Entry/EntrySheetView.swift` | Empty state and detents. |
| `Klar/Klar/Features/Today/TodayView.swift` | Quota line deleted. |
| `Klar/Klar/DesignSystem/KlarTheme.swift` | Adaptive tokens, appearance-aware shadow. |
| `Klar/Klar/Localizable.xcstrings` | Keys pruned in lockstep with copy changes. |
| `Klar/Klar/Assets.xcassets/LaunchBackground.colorset/Contents.json` | Dark variant. |
| `docs/klar-screens-implementation.md` | J2 section removed, layout and theme sections updated. |

---

# Phase 1 · The app lock works

### Task 1: Declare the Face ID usage description

Without `NSFaceIDUsageDescription` iOS refuses biometric evaluation and
`LAPolicy.deviceOwnerAuthentication` falls through to the passcode without saying why. This is the
whole of report 3.

**Files:**
- Modify: `Klar/Klar.xcodeproj/project.pbxproj:427` (Debug) and `:459` (Release)

- [ ] **Step 1: Confirm the key is absent**

```bash
grep -c "NSFaceIDUsageDescription" Klar/Klar.xcodeproj/project.pbxproj
```

Expected: `0`

- [ ] **Step 2: Add the key to both build configurations**

In `project.pbxproj`, both the `3923393630054E0D00A5DC89 /* Debug */` and
`3923393730054E0D00A5DC89 /* Release */` blocks contain this line:

```
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
```

Insert directly **above** it, in each block (build settings are sorted alphabetically, and `NS`
sorts before `UI`):

```
				INFOPLIST_KEY_NSFaceIDUsageDescription = "Klar entsperrt deine Einträge mit Face ID.";
```

- [ ] **Step 3: Verify both configs got it**

```bash
grep -c "NSFaceIDUsageDescription" Klar/Klar.xcodeproj/project.pbxproj
```

Expected: `2`

- [ ] **Step 4: Verify it reaches the built Info.plist**

```bash
xcodebuild build -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' 2>&1 | tail -3
plutil -extract NSFaceIDUsageDescription raw \
  ~/Library/Developer/Xcode/DerivedData/Klar-*/Build/Products/Debug-iphonesimulator/Klar.app/Info.plist
```

Expected: `** BUILD SUCCEEDED **`, then `Klar entsperrt deine Einträge mit Face ID.`

- [ ] **Step 5: Commit**

```bash
git add Klar/Klar.xcodeproj/project.pbxproj
git commit -m "Declare NSFaceIDUsageDescription so the lock can use Face ID

Without it iOS refuses biometric evaluation and deviceOwnerAuthentication
falls straight through to the device passcode."
```

---

### Task 2: Make the lock manager testable and cancel-aware

`attemptUnlock` currently treats every thrown error as a failure. When iOS dismisses the Face ID
sheet because the app resigned active (`LAError.systemCancel` / `.appCancel`), that is not a
failed attempt and must not paint "Erneut versuchen". The manager also needs to refuse
overlapping evaluations, and it needs an injection point so this is testable without biometrics.

**Files:**
- Modify: `Klar/Klar/Security/AppLockManager.swift`
- Create: `Klar/KlarTests/AppLockManagerTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Klar/KlarTests/AppLockManagerTests.swift`:

```swift
import XCTest
@testable import Klar

@MainActor
final class AppLockManagerTests: XCTestCase {
    func testSuccessfulAuthenticationUnlocks() async {
        let manager = AppLockManager { .success }
        await manager.attemptUnlock()
        XCTAssertFalse(manager.isLocked)
        XCTAssertFalse(manager.didFail)
    }

    func testFailedAuthenticationStaysLockedAndReportsFailure() async {
        let manager = AppLockManager { .failure }
        await manager.attemptUnlock()
        XCTAssertTrue(manager.isLocked)
        XCTAssertTrue(manager.didFail)
    }

    /// A system cancel is what happens when the app resigns active mid-prompt. The user did
    /// nothing wrong, so the screen must not accuse them of a failed attempt.
    func testCancelledAuthenticationStaysLockedWithoutReportingFailure() async {
        let manager = AppLockManager { .cancelled }
        await manager.attemptUnlock()
        XCTAssertTrue(manager.isLocked)
        XCTAssertFalse(manager.didFail)
    }

    /// The overlay re-triggers on every foregrounding. Two evaluations racing each other put
    /// two Face ID sheets on screen, which is the "stuck" symptom.
    func testOverlappingAttemptsEvaluateOnlyOnce() async {
        var evaluations = 0
        let manager = AppLockManager {
            evaluations += 1
            try? await Task.sleep(for: .milliseconds(50))
            return .success
        }

        async let first: Void = manager.attemptUnlock()
        async let second: Void = manager.attemptUnlock()
        _ = await (first, second)

        XCTAssertEqual(evaluations, 1)
    }

    func testUnavailableAuthenticationUnlocksRatherThanLockingTheUserOut() async {
        let manager = AppLockManager { .unavailable }
        await manager.attemptUnlock()
        XCTAssertFalse(manager.isLocked)
    }

    func testScheduledLockFiresOnlyAfterTheGracePeriod() {
        let manager = AppLockManager { .success }
        manager.unlockWithoutAuthentication()

        manager.scheduleLock(after: 60)
        manager.cancelPendingLockIfStillWithinGrace(now: Date().addingTimeInterval(10))
        XCTAssertFalse(manager.isLocked)

        manager.scheduleLock(after: 60)
        manager.cancelPendingLockIfStillWithinGrace(now: Date().addingTimeInterval(120))
        XCTAssertTrue(manager.isLocked)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
xcodebuild test -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' -only-testing:KlarTests/AppLockManagerTests 2>&1 | tail -20
```

Expected: compilation failure — `AppLockManager` has no such initializer, no `didFail`, and
`cancelPendingLockIfStillWithinGrace` takes no argument.

- [ ] **Step 3: Rewrite `AppLockManager`**

Replace the entire contents of `Klar/Klar/Security/AppLockManager.swift`:

```swift
import Foundation
import LocalAuthentication
import Observation

/// What a single authentication attempt came back with. A *cancel* is deliberately not a
/// failure: iOS cancels the prompt whenever the app resigns active, and the user never saw it.
enum AuthenticationOutcome {
    case success
    case failure
    case cancelled
    /// Neither biometrics nor a device passcode is configured. Locking here would lock the user
    /// out of their own app over a device setting they may not control.
    case unavailable
}

@MainActor
@Observable
final class AppLockManager {
    private(set) var isLocked: Bool = true
    private(set) var didFail: Bool = false
    private(set) var isAuthenticating: Bool = false

    /// Set when the app backgrounds with a non-zero auto-lock delay. On the next foregrounding
    /// we lock only if this moment has already passed — that's what makes "Nach 1 Minute"
    /// different from "Sofort".
    private var lockDeadline: Date?

    private let authenticate: () async -> AuthenticationOutcome

    init(authenticate: @escaping () async -> AuthenticationOutcome = AppLockManager.systemAuthenticate) {
        self.authenticate = authenticate
    }

    var requiresUnlock: Bool { isLocked }

    func lock() {
        isLocked = true
        lockDeadline = nil
    }

    /// Called when the app enters the background.
    func scheduleLock(after delay: TimeInterval) {
        guard delay > 0 else {
            lock()
            return
        }
        lockDeadline = Date().addingTimeInterval(delay)
    }

    /// Called when the app becomes active again. Locks only if the grace period elapsed while
    /// we were away. `now` is injectable so the grace window is testable without sleeping.
    func cancelPendingLockIfStillWithinGrace(now: Date = Date()) {
        defer { lockDeadline = nil }
        guard let lockDeadline else { return }
        if now >= lockDeadline {
            isLocked = true
        }
    }

    /// Used when the user has the Face ID lock switched off — the gate must not stand in the way.
    func unlockWithoutAuthentication() {
        isLocked = false
        didFail = false
        lockDeadline = nil
    }

    /// Re-entrant by design: the overlay calls this on every foregrounding, and a second call
    /// while a prompt is already up would stack two Face ID sheets.
    func attemptUnlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        switch await authenticate() {
        case .success:
            isLocked = false
            didFail = false
        case .failure:
            isLocked = true
            didFail = true
        case .cancelled:
            isLocked = true
        case .unavailable:
            isLocked = false
            didFail = false
        }
    }

    private static func systemAuthenticate() async -> AuthenticationOutcome {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .unavailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(localized: "Entsperre Klar, um fortzufahren")
            )
            return success ? .success : .failure
        } catch let error as LAError where error.code == .systemCancel || error.code == .appCancel {
            return .cancelled
        } catch {
            return .failure
        }
    }

    /// Whether the device can actually gate on Face ID / passcode — drives whether the
    /// onboarding privacy step (A1) offers to switch the lock on.
    static func canAuthenticate() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
xcodebuild test -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' -only-testing:KlarTests/AppLockManagerTests 2>&1 | tail -20
```

Expected: `Executed 6 tests, with 0 failures`, `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Klar/Klar/Security/AppLockManager.swift Klar/KlarTests/AppLockManagerTests.swift
git commit -m "Make the lock manager cancel-aware, single-flight and testable

A system cancel is not a failed attempt, and two overlapping evaluations
stack two Face ID sheets."
```

---

### Task 3: Re-arm the lock screen on every foregrounding

`AppLockOverlayView` triggers authentication from `.task`, which runs once per view identity. If
the app backgrounds while already locked, nothing prompts on return — the wordmark screen with no
Face ID sheet, which is report 5.

**Files:**
- Modify: `Klar/Klar/Security/AppLockOverlayView.swift`

- [ ] **Step 1: Replace the view**

Replace the entire contents of `Klar/Klar/Security/AppLockOverlayView.swift`:

```swift
import SwiftUI

/// J1 · Sperrbildschirm — a neutral screen. Wordmark only, nothing that hints at what the
/// app is for.
struct AppLockOverlayView: View {
    @Bindable var lockManager: AppLockManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            KlarWordmark()

            VStack(spacing: 12) {
                Spacer()
                Button {
                    Task { await lockManager.attemptUnlock() }
                } label: {
                    Image(systemName: "faceid")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(Klar.textSecondary)
                        .frame(width: 56, height: 56)
                        .overlay {
                            Circle().strokeBorder(Klar.borderStrong, lineWidth: 2)
                        }
                }
                .accessibilityLabel("Mit Face ID entsperren")

                Text(lockManager.didFail ? "Erneut versuchen" : "Mit Face ID entsperren")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
            }
            .padding(.bottom, 70)
        }
        .task {
            await lockManager.attemptUnlock()
        }
        // `.task` fires once per view identity. When the app backgrounds while already locked,
        // the overlay never leaves the hierarchy, so without this the user comes back to a dead
        // wordmark screen and no prompt.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, lockManager.isLocked else { return }
            Task { await lockManager.attemptUnlock() }
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Verify in the simulator with enrolled biometrics**

```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; xcrun simctl bootstatus "iPhone 17 Pro"
```

Then install and launch the built app, enable "Face ID Sperre" in Einstellungen, set Auto-Sperre
to "Sofort", and:

1. Enroll: Simulator menu → Features → Face ID → Enrolled.
2. Background the app (Home), reopen. Expected: Face ID prompt appears.
3. Background it *from the lock screen*, reopen. Expected: the prompt appears again. This is the
   case that was broken.
4. Features → Face ID → Non-matching Face. Expected: "Erneut versuchen" and the app stays locked.

Record what happened in the commit message if anything deviates.

- [ ] **Step 4: Commit**

```bash
git add Klar/Klar/Security/AppLockOverlayView.swift
git commit -m "Re-trigger authentication whenever the app returns to the foreground

.task runs once per view identity, so backgrounding from an already-locked
screen left the user on the wordmark with no prompt."
```

---

# Phase 2 · Panic gesture removed

### Task 4: Delete the panic façade

Report 8: "Ich verstehe den Sinn gar nicht. Feature komplett entfernen."

**Files:**
- Delete: `Klar/Klar/Security/PanicView.swift`
- Modify: `Klar/Klar/App/RootView.swift`, `Klar/Klar/App/AppSettings.swift`, `Klar/Klar/Features/Settings/SettingsView.swift`, `Klar/Klar/Localizable.xcstrings`, `docs/klar-screens-implementation.md`

- [ ] **Step 1: Delete the view file and its Xcode reference**

```bash
git rm Klar/Klar/Security/PanicView.swift
```

The project uses Xcode 16+ synchronized file groups (no per-file `PBXFileReference` entries for
sources), so no `project.pbxproj` edit is needed. Confirm:

```bash
grep -c "PanicView" Klar/Klar.xcodeproj/project.pbxproj
```

Expected: `0`. If it is not 0, remove those lines too.

- [ ] **Step 2: Remove the gate from `RootView`**

In `Klar/Klar/App/RootView.swift`, delete the `@State private var isPanicActive = false` line, the
entire `.overlay { if settings.isPanicGestureEnabled { … } }` block, and the
`.fullScreenCover(isPresented: $isPanicActive) { … }` block. Then delete everything from the
`// MARK: - Panic gesture` marker to the end of the file (`MultiTouchTapCatcher` and its
`Coordinator` / `WindowAttachingView`).

Update the doc comment above `struct RootView` to the three remaining gates:

```swift
/// The app shell. Gates, in priority order:
///
/// 1. **App lock** (J1) — Face ID / device passcode.
/// 2. **Onboarding** (A1–A4) — one-time.
/// 3. The four tabs.
```

- [ ] **Step 3: Remove the setting**

In `Klar/Klar/App/AppSettings.swift`, delete three things: the `self.isPanicGestureEnabled = …`
line in `init`, the `var isPanicGestureEnabled` property with its doc comment, and the
`static let isPanicGestureEnabled` line in `Keys`.

The stale `klar.isPanicGestureEnabled` UserDefaults key stays on existing installs. Migration code
for a boolean nobody reads is not worth writing.

- [ ] **Step 4: Remove the settings row**

In `Klar/Klar/Features/Settings/SettingsView.swift`, delete the "Panik-Geste" `SettingsToggleRow`
and the `SettingsDivider()` immediately above it (lines 50–57), leaving Face ID Sperre followed by
Auto-Sperre.

- [ ] **Step 5: Prune the string catalog**

```bash
python3 - <<'EOF'
import json
path = "Klar/Klar/Localizable.xcstrings"
data = json.load(open(path))
for key in ["Panik-Geste",
            "Zwei Finger, doppelt tippen — zeigt einen Taschenrechner. Zum Zurückkehren die Anzeige lange gedrückt halten."]:
    data["strings"].pop(key, None)
json.dump(data, open(path, "w"), ensure_ascii=False, indent=2, sort_keys=True)
open(path, "a").write("\n")
EOF
grep -c "Panik" Klar/Klar/Localizable.xcstrings
```

Expected: `0`

- [ ] **Step 6: Update the implementation doc**

In `docs/klar-screens-implementation.md`, remove the J2 row/section describing the calculator
façade and change the `RootView` gate-order note from "panic façade → app lock → onboarding →
tabs" to "app lock → onboarding → tabs".

- [ ] **Step 7: Verify nothing references it**

```bash
grep -rn "Panic\|Panik\|isPanicGestureEnabled" --include="*.swift" Klar | grep -v "Angst und Panik"
```

Expected: no output. (`HelpContent.swift` mentions "Angst und Panik" as a cannabis risk — that is
unrelated prose and stays.)

- [ ] **Step 8: Build and test**

```bash
xcodebuild test -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' -only-testing:KlarTests 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **`, 18 tests.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "Remove the panic gesture and calculator facade

The feature had no clear purpose and cost a window-level gesture recognizer
plus a whole gate in the app shell."
```

---

# Phase 3 · One format in, the same format out

### Task 5: Split decode from restore so a bad file cannot wipe good data

`importJSON` refuses a non-empty store. Making import usable means wiping first — which is only
safe if the file has already been proven decodable. Splitting the function is what makes the
ordering possible.

**Files:**
- Modify: `Klar/Klar/Persistence/ExportImportService.swift`
- Modify: `Klar/KlarTests/ExportImportTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `Klar/KlarTests/ExportImportTests.swift`, inside the existing `final class
ExportImportTests: XCTestCase { … }`:

```swift
    func testDecodeRejectsMalformedJSONWithoutTouchingTheStore() throws {
        let context = TestModelContainer.makeInMemoryContext()
        context.insert(Substance(name: "Kaffee", unit: .drink, colorIndex: 0, sortOrder: 0))
        try context.save()

        XCTAssertThrowsError(try ExportImportService.decode(Data("nicht json".utf8)))

        let survivors = try context.fetch(FetchDescriptor<Substance>())
        XCTAssertEqual(survivors.count, 1, "A rejected file must leave the store untouched")
    }

    func testDecodeRejectsAnUnknownSchemaVersion() throws {
        let payload = #"{"schemaVersion": 999, "exportedAt": 0, "substances": [], "entries": [], "contextTags": [], "goalPeriods": [], "plans": [], "planCheckIns": [], "substitutionActions": [], "whyNotes": [], "reviewDecisions": []}"#

        XCTAssertThrowsError(try ExportImportService.decode(Data(payload.utf8))) { error in
            XCTAssertEqual(error as? ExportImportError, .unknownSchemaVersion(999))
        }
    }

    /// The import screen's real sequence: decode, then wipe, then restore. Exercised end to end
    /// because the ordering is the whole safety property.
    func testReplaceAllReplacesAPopulatedStore() throws {
        let sourceContext = TestModelContainer.makeInMemoryContext()
        let substance = Substance(name: "Kaffee", unit: .drink, colorIndex: 2, sortOrder: 0)
        sourceContext.insert(substance)
        sourceContext.insert(Entry(substance: substance, timestamp: Date(timeIntervalSince1970: 1_770_000_000), timezoneID: "Europe/Berlin"))
        try sourceContext.save()
        let payload = try ExportImportService.exportJSON(context: sourceContext)

        let destinationContext = TestModelContainer.makeInMemoryContext()
        destinationContext.insert(Substance(name: "Bier", unit: .drink, colorIndex: 1, sortOrder: 0))
        try destinationContext.save()

        try ExportImportService.replaceAll(with: payload, context: destinationContext)

        let names = try destinationContext.fetch(FetchDescriptor<Substance>()).map(\.name)
        XCTAssertEqual(names, ["Kaffee"])
        XCTAssertEqual(try destinationContext.fetchCount(FetchDescriptor<Entry>()), 1)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
xcodebuild test -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' -only-testing:KlarTests/ExportImportTests 2>&1 | tail -20
```

Expected: compilation failure — `decode` and `replaceAll` do not exist.

- [ ] **Step 3: Split the function**

In `Klar/Klar/Persistence/ExportImportService.swift`, replace the existing `importJSON` with:

```swift
    /// Decodes and validates without touching the store. Split out from the import so a corrupt
    /// or wrong-version file can be rejected *before* anything is deleted.
    static func decode(_ data: Data) throws -> KlarExport {
        let export = try KlarExportCoding.makeDecoder().decode(KlarExport.self, from: data)
        guard export.schemaVersion == KlarExport.currentSchemaVersion else {
            throw ExportImportError.unknownSchemaVersion(export.schemaVersion)
        }
        return export
    }

    static func importJSON(_ data: Data, context: ModelContext) throws {
        guard try isStoreEmpty(context: context) else {
            throw ExportImportError.storeNotEmpty
        }
        try restore(decode(data), context: context)
    }

    /// What the import screen calls. Decode first, wipe second, restore third — in that order
    /// a rejected file costs the user nothing.
    static func replaceAll(with data: Data, context: ModelContext) throws {
        let export = try decode(data)
        try wipeAll(context: context)
        try restore(export, context: context)
    }
```

Change `private static func restore` to `static func restore` so `replaceAll` and the tests can
reach it.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
xcodebuild test -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' -only-testing:KlarTests/ExportImportTests 2>&1 | tail -20
```

Expected: `Executed 6 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Klar/Klar/Persistence/ExportImportService.swift Klar/KlarTests/ExportImportTests.swift
git commit -m "Split decode from restore so import can validate before wiping

Importing into a used store means replacing it. Decoding first means a
corrupt file is rejected while the old data is still there."
```

---

### Task 6: Remove the CSV export

Report 9: only offer the format that can also be imported.

**Files:**
- Modify: `Klar/Klar/Persistence/ExportImportService.swift`, `Klar/Klar/Features/Settings/DataManagementView.swift`, `Klar/Klar/Localizable.xcstrings`

- [ ] **Step 1: Delete `exportCSV`**

Remove the whole `static func exportCSV(context:) throws -> Data` function (lines 11–27) from
`Klar/Klar/Persistence/ExportImportService.swift`. No test covers it — verify:

```bash
grep -c "exportCSV\|CSV" Klar/KlarTests/ExportImportTests.swift
```

Expected: `0`

- [ ] **Step 2: Delete the CSV path from the data screen**

In `Klar/Klar/Features/Settings/DataManagementView.swift` remove, in this order:

- `@State private var isExportingCSV = false`
- the `SettingsDivider()` and the "Als CSV exportieren" `SettingsNavigationRow` (lines 38–44)
- the entire second `.fileExporter(isPresented: $isExportingCSV, …)` modifier (lines 103–108)
- the `private func exportCSV()` function (lines 148–156)

In `ExportDocument`, narrow the readable types now that only one format exists:

```swift
    static var readableContentTypes: [UTType] { [.json] }
```

The remaining JSON row loses its now-pointless disambiguating subtitle, since there is nothing to
disambiguate against:

```swift
                        SettingsGroup {
                            SettingsNavigationRow(
                                icon: "square.and.arrow.up",
                                title: "Daten exportieren"
                            ) { exportJSON() }
                        }
```

- [ ] **Step 3: Prune the string catalog**

```bash
python3 - <<'EOF'
import json
path = "Klar/Klar/Localizable.xcstrings"
data = json.load(open(path))
for key in ["Als CSV exportieren", "CSV teilen", "Nur Einträge, für Tabellenprogramme",
            "Als JSON exportieren", "Vollständig — lässt sich wieder importieren"]:
    data["strings"].pop(key, None)
json.dump(data, open(path, "w"), ensure_ascii=False, indent=2, sort_keys=True)
open(path, "a").write("\n")
EOF
```

- [ ] **Step 4: Build**

```bash
xcodebuild build -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Drop the CSV export

Only one format should leave the app: the one that can come back in."
```

---

### Task 7: Add the import entry point

**Files:**
- Modify: `Klar/Klar/Features/Settings/DataManagementView.swift`, `Klar/Klar/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Add the import state and row**

In `Klar/Klar/Features/Settings/DataManagementView.swift`, add to the `@State` block:

```swift
    @State private var isImporting = false
    @State private var pendingImport: Data?
```

Add a new section between the Export group and the "Löschen" label:

```swift
                        KlarSectionLabel(text: "Import")
                            .padding(.bottom, 8)

                        SettingsGroup {
                            SettingsNavigationRow(
                                icon: "square.and.arrow.down",
                                title: "Daten importieren",
                                subtitle: "Ersetzt alle Daten auf diesem Gerät"
                            ) { isImporting = true }
                        }
                        .padding(.bottom, 20)
```

- [ ] **Step 2: Add the file importer and its confirmation**

Add these modifiers next to the existing `.fileExporter`:

```swift
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                loadForImport(url)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .confirmationDialog(
            "Alle Daten ersetzen?",
            isPresented: Binding(
                get: { pendingImport != nil },
                set: { if !$0 { pendingImport = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Ersetzen", role: .destructive) { performImport() }
            Button("Abbrechen", role: .cancel) { pendingImport = nil }
        } message: {
            Text("Einträge, Ziele, Pläne und Notizen auf diesem Gerät werden durch die Datei ersetzt.")
        }
```

- [ ] **Step 3: Add the two functions**

```swift
    /// Reads and validates before anything is destroyed. A file that cannot be decoded never
    /// reaches the confirmation dialog, so the user is never asked to approve a wipe that would
    /// then fail halfway.
    private func loadForImport(_ url: URL) {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            _ = try ExportImportService.decode(data)
            pendingImport = data
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performImport() {
        guard let data = pendingImport else { return }
        pendingImport = nil
        do {
            try ExportImportService.replaceAll(with: data, context: modelContext)
            // Without this the user lands back in onboarding on top of a full store.
            settings.hasCompletedOnboarding = true
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
```

- [ ] **Step 4: Rename the settings row that leads here**

In `Klar/Klar/Features/Settings/SettingsView.swift:110`, change the title from
`"Daten exportieren / löschen"` to `"Daten"`, and update the catalogue:

```bash
python3 - <<'EOF'
import json
path = "Klar/Klar/Localizable.xcstrings"
data = json.load(open(path))
data["strings"].pop("Daten exportieren / löschen", None)
json.dump(data, open(path, "w"), ensure_ascii=False, indent=2, sort_keys=True)
open(path, "a").write("\n")
EOF
```

- [ ] **Step 5: Build and verify the round trip by hand**

```bash
xcodebuild build -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' 2>&1 | tail -5
```

In the simulator: create two entries → Einstellungen → Daten → exportieren (save to Files) →
alle Daten löschen → run onboarding → Daten → importieren → pick the file → confirm. Expected:
both entries are back and the app is past onboarding. Then import a file with garbage in it and
confirm the error alert appears with the data still intact.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Add a data import to the settings screen

importJSON was only reachable from the debug root view. Import replaces the
store, so it decodes and validates the file before wiping anything."
```

---

# Phase 4 · A banner zone on every tab

> **Superseded in part, 2026-08-01.** This phase originally pushed each screen's interactive block
> down into thumb reach. That was built (Tasks 8–10), shown to the user, and rejected on sight:
> "sieht leider echt trash aus mit dem kalender unten", and the same for Hilfe. Commit `fe2431b`
> made `KlarScreen` top-aligned and put the segmented control back under the title, replacing the
> reachability argument with a swipe gesture between sections. What survives from the original
> design is the generous banner zone and the stat tiles at the top of Verlauf, both of which the
> user liked. Read the tasks below with that in mind: the code is still right, the rationale about
> thumb reach is not.

### Task 8: Build the `KlarScreen` container

Reports 6 and 7. On Hilfe the last tappable row ends at ~46 % of screen height with ~45 % dead
space beneath it. Every tab is a top-aligned `ScrollView` today.

**Files:**
- Create: `Klar/Klar/DesignSystem/KlarScreen.swift`

- [ ] **Step 1: Write the container**

Create `Klar/Klar/DesignSystem/KlarScreen.swift`:

```swift
import SwiftUI

/// The layout rule for the four tabs: what you look at sits at the top, what you touch sits at
/// the bottom.
///
/// The banner is anchored under the status bar with real breathing room; the content block is
/// pushed toward the tab bar by flexible space. When the content outgrows the viewport the
/// flexible space collapses to `Klar.Space.x6` and the screen scrolls like any other. That is
/// why the inner frame uses `minHeight` and not `containerRelativeFrame` — an exact height would
/// clip a long month or a full plan list.
struct KlarScreen<Banner: View, Content: View>: View {
    var horizontalPadding: CGFloat = 16
    @ViewBuilder var banner: Banner
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        banner

                        Spacer(minLength: Klar.Space.x6)

                        content
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: proxy.size.height - Klar.Space.x6 * 2,
                        alignment: .leading
                    )
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, Klar.Space.x6)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
        }
    }
}

/// The banner headline. Bigger and more generously spaced than the old inline `Klar.TypeScale.title`
/// so the top of a screen reads as a deliberate zone rather than a label stuck to the status bar.
struct KlarScreenBanner<Detail: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var detail: Detail

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(Klar.TypeScale.display(30))
                .foregroundStyle(Klar.text)
                .padding(.bottom, Klar.Space.x4)

            detail
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension KlarScreenBanner where Detail == EmptyView {
    init(title: LocalizedStringKey) {
        self.init(title: title) { EmptyView() }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Klar/Klar/DesignSystem/KlarScreen.swift
git commit -m "Add the KlarScreen container

Informative banner anchored at the top, interactive block pushed to the
bottom, flexible space in between that collapses when content is long."
```

---

### Task 9: Move Hilfe into the new container

The screen that needs it most: four tap targets, never scrolls, all of them crowded into the top
half.

**Files:**
- Modify: `Klar/Klar/Features/Help/HelpView.swift:12-71`

- [ ] **Step 1: Replace the body**

In `Klar/Klar/Features/Help/HelpView.swift`, replace `var body: some View { … }` (lines 12–71)
with:

```swift
    var body: some View {
        NavigationStack {
            KlarScreen {
                KlarScreenBanner(title: "Hilfe")
            } content: {
                VStack(alignment: .leading, spacing: 0) {
                    sosButton
                        .padding(.bottom, 16)

                    VStack(spacing: 10) {
                        NavigationLink {
                            EmergencyView()
                        } label: {
                            emergencyRow
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("help.emergency")

                        NavigationLink {
                            CounselingView()
                        } label: {
                            helpRow(
                                icon: "person.2",
                                title: "Beratung",
                                subtitle: "Suchtberatung · Hotlines · anonym"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("help.counseling")

                        NavigationLink {
                            RiskInfoListView()
                        } label: {
                            helpRow(
                                icon: "book",
                                title: "Risiko-Infos",
                                subtitle: "Nachschlagewerk, kein Startpunkt"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("help.riskInfo")
                    }
                }
            }
            .fullScreenCover(isPresented: $isSOSPresented) {
                CravingSOSView()
            }
        }
    }
```

Update the doc comment above `struct HelpView` — "SOS at the very top" is no longer true:

```swift
/// H1 · Tab „Hilfe".
///
/// Must be operable one-handed in a bad moment, which is why the whole block sits in the lower
/// half of the screen: SOS first, reference material last. A permanently visible tab normalizes
/// asking for help — it's a basic function of the app, not an emergency exit.
```

- [ ] **Step 2: Screenshot the result**

```bash
xcodebuild build -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' 2>&1 | tail -3
```

Launch the app in the simulator, go to the Hilfe tab, take a screenshot. Expected: the "Hilfe"
banner at the top with visible breathing room, the SOS card starting around the vertical middle,
and the "Risiko-Infos" row ending just above the tab bar. No scroll bounce.

- [ ] **Step 3: Run the UI test that touches this screen**

```bash
xcodebuild test -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' -only-testing:KlarUITests/KlarUITests 2>&1 | tail -15
```

Expected: `** TEST SUCCEEDED **`. The `help.sos` identifier is unchanged, so this should pass
without edits.

- [ ] **Step 4: Commit**

```bash
git add Klar/Klar/Features/Help/HelpView.swift
git commit -m "Move Hilfe into KlarScreen

Four tap targets in the top half with 45% dead space underneath was the
worst case of the layout problem."
```

---

### Task 10: Restructure Verlauf

Stat tiles become the banner (nobody taps them), the calendar drops to the bottom, and the
segmented control moves into a bottom accessory bar.

**Files:**
- Modify: `Klar/Klar/Features/History/HistoryView.swift:21-58` and `:96-131`

- [ ] **Step 1: Replace `HistoryView.body`**

```swift
    var body: some View {
        KlarScreen {
            KlarScreenBanner(title: title) {
                if section == .calendar {
                    CalendarStatsView(visibleMonth: visibleMonth)
                }
            }
        } content: {
            switch section {
            case .calendar: CalendarSectionView(visibleMonth: $visibleMonth)
            case .trends: TrendsSectionView()
            case .review: ReviewArchiveSectionView()
            }
        }
        // The segmented control is interactive, so by the screen's own rule it belongs at the
        // bottom. It sits in its own inset rather than in the scrolling content so it does not
        // scroll away, and inset from the edges so it does not read as a second tab bar.
        .safeAreaInset(edge: .bottom) {
            KlarSegmentedControl(
                options: [
                    (Section.calendar, "Kalender"),
                    (Section.trends, "Trends"),
                    (Section.review, "Rückblick")
                ],
                selection: $section
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
```

The visible month has to move up to `HistoryView` because the banner shows stats for it while the
content owns the grid. Add to `HistoryView`:

```swift
    @State private var visibleMonth = Date()
```

`KlarScreenBanner.title` is a `LocalizedStringKey`, but `HistoryView.title` is declared `String`
and will not convert. Change its declaration (the two returned values are string literals, so
nothing else moves):

```swift
    private var title: LocalizedStringKey {
        switch section {
        case .calendar, .trends: "Verlauf"
        case .review: "Wochenrückblicke"
        }
    }
```

- [ ] **Step 2: Extract the stats into their own view**

The two tiles currently live at the bottom of `CalendarSectionView`. Move them out. Add to
`Klar/Klar/Features/History/HistoryView.swift`, after `HistoryView`:

```swift
/// The month's two numbers. Pure output — the only thing on this screen nobody taps, which is
/// why it is the one thing that stays at the top.
struct CalendarStatsView: View {
    let visibleMonth: Date

    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [Entry]

    private var store: KlarStore { KlarStore(context: modelContext) }
    private var calendar: Calendar { KlarDate.calendar }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: visibleMonth)?.count ?? 30
    }

    private var entryCount: Int {
        entries.filter {
            let day = KlarDate.logicalDay(for: $0.timestamp, timezoneID: $0.timezoneID)
            return calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month)
        }.count
    }

    private var entryFreeDays: Int {
        daysInMonth - store.loggedDays(inMonthOf: visibleMonth).count
    }

    var body: some View {
        HStack(spacing: 12) {
            tile(label: "Einträge", value: "\(entryCount)", color: Klar.text)
            tile(label: "Eintragsfrei", value: "\(entryFreeDays)", color: Klar.Palette.emerald700)
        }
    }

    private func tile(label: LocalizedStringKey, value: String, color: Color) -> some View {
        KlarCard(padding: 14) {
            Text(label)
                .font(Klar.TypeScale.caption)
                .foregroundStyle(Klar.textTertiary)
            Text(value)
                .font(Klar.TypeScale.numeral)
                .foregroundStyle(color)
        }
    }
}
```

- [ ] **Step 3: Slim down `CalendarSectionView`**

In `CalendarSectionView`: change `@State private var visibleMonth = Date()` to
`@Binding var visibleMonth: Date`, delete the now-duplicated `daysInMonth`, `entryCount`,
`entryFreeDays` computed properties and the `statTile` function, and replace the `body` with:

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KlarCard(padding: 16) {
                monthHeader
                    .padding(.bottom, 12)

                weekdayHeader
                    .padding(.bottom, 6)

                dayGrid
            }

            legend
                .padding(.top, 14)
        }
        .sheet(item: Binding(
            get: { selectedDay.map { IdentifiableDate(date: $0) } },
            set: { selectedDay = $0?.date }
        )) { wrapper in
            DayDetailView(day: wrapper.date)
        }
    }
```

`daysInMonth` is still needed by `cells`, so keep that one. Only `entryCount`, `entryFreeDays`
and `statTile` go.

- [ ] **Step 4: Build and screenshot both states**

```bash
xcodebuild build -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' 2>&1 | tail -3
```

Screenshot the Verlauf tab. Expected: "Verlauf" plus the two number tiles at the top, calendar
card and legend at the bottom, segmented control pinned above the tab bar. Switch to Trends and
Rückblick and confirm the banner drops the tiles and the sections still render.

**Stop here and hand both variants back.** The user decides this one from screenshots, not you.
Build the pinned bottom bar as written and screenshot the Verlauf tab. Then temporarily move the
`KlarSegmentedControl` into `KlarScreenBanner`'s `detail` slot (above the tiles), screenshot the
same tab again, and revert to the pinned version. Report both image paths and stop the task there
with the pinned variant in the working tree. Do not commit a choice.

- [ ] **Step 5: Commit**

```bash
git add Klar/Klar/Features/History/HistoryView.swift
git commit -m "Restructure Verlauf: numbers on top, calendar in thumb reach

The stat tiles are the only thing on the screen nobody taps, so they become
the banner and the interactive grid moves down."
```

---

### Task 11: Restructure Pläne

**Files:**
- Modify: `Klar/Klar/Features/Plans/PlansView.swift:26-64`

- [ ] **Step 1: Replace the body**

```swift
    var body: some View {
        NavigationStack {
            KlarScreen {
                KlarScreenBanner(title: "Pläne") {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(subtitle)
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.textTertiary)

                        if let goalLine {
                            KlarCard(padding: 16) {
                                KlarSectionLabel(text: "Ziel")
                                    .padding(.bottom, 6)
                                Text(goalLine)
                                    .font(Klar.TypeScale.body)
                                    .foregroundStyle(Klar.text)
                            }
                            .padding(.top, 14)
                        }
                    }
                }
            } content: {
                VStack(alignment: .leading, spacing: 0) {
                    if activePlans.isEmpty {
                        emptyState
                    } else {
                        planCards
                    }

                    navigationRows
                        .padding(.top, 24)
                }
            }
            .sheet(item: $editorSeed) { seed in
                PlanEditorView(
                    existingPlan: seed.plan,
                    prefilledSituationTag: seed.tag
                )
            }
        }
    }
```

- [ ] **Step 2: Rename `filledState` and drop the goal card from it**

The Ziel card moved into the banner, so it must not render twice. Rename `filledState` to
`planCards` and delete the leading `if let goalLine { KlarCard(padding: 16) { … } .padding(.bottom, 14) }`
block (lines 76–86) from it. Everything from `VStack(spacing: 12) { ForEach(activePlans) …` down
stays exactly as it is.

- [ ] **Step 3: Build and screenshot**

```bash
xcodebuild build -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' 2>&1 | tail -3
```

Screenshot the Pläne tab with zero plans and with one plan. Expected in both: the serif banner
title, then subtitle, then (when a goal exists) the Ziel card, then plan cards, "Neuer Plan" and
the two navigation rows — all top-aligned, flowing straight down from the banner with no gap.
Confirm the Ziel card appears exactly once.

**Do not push anything toward the tab bar.** The bottom-weighted variant of this layout was built,
shown to the user on 2026-08-01 and rejected: "sieht leider echt trash aus". `KlarScreen` is
top-aligned now; this task only adopts the banner zone.

- [ ] **Step 4: Run the screenshot UI test**

```bash
xcodebuild test -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' -only-testing:KlarUITests/ScreenshotTests 2>&1 | tail -15
```

Expected: `** TEST SUCCEEDED **`. `plans.goalsLink` is unchanged, but the row may now need a
scroll to be hittable on smaller devices; if the test fails on tap, add
`app.buttons["plans.goalsLink"].scrollUpToElement()` style handling rather than moving the row
back up.

- [ ] **Step 5: Bring Heute's header up to the same typography**

Heute keeps its own layout — it has a bottom-right FAB already and its content grows with every
entry, so bottom-weighting would fight itself. It only adopts the banner *look*, so the four tabs
do not have two different title styles. In `Klar/Klar/Features/Today/TodayView.swift`, in the
`header` property, change the title font and give the row room to breathe:

```swift
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Heute")
                .font(Klar.TypeScale.display(30))
                .foregroundStyle(Klar.text)
            Spacer()
            Text(KlarDate.shortWeekdayDate(today))
                .font(Klar.TypeScale.bodySmall)
                .foregroundStyle(Klar.textTertiary)
            KlarIconButton(systemImage: "gearshape", accessibilityLabel: "Einstellungen") {
                isSettingsPresented = true
            }
        }
    }
```

and change the `ScrollView`'s `.padding(.top, 8)` (line 115) to `.padding(.top, Klar.Space.x6)`.

Screenshot Heute and one other tab side by side and confirm the two titles now match.

- [ ] **Step 6: Commit**

```bash
git add Klar/Klar/Features/Plans/PlansView.swift Klar/Klar/Features/Today/TodayView.swift
git commit -m "Restructure Pläne and align Heute's header typography

Goal on top, plan actions in thumb reach. Heute keeps its layout — it has a
FAB and growing content — but adopts the same banner title."
```

---

# Phase 5 · Calendar interaction

### Task 12: Swipe between months

Report 2. The phantom scroll is already gone via `KlarScreen`'s
`scrollBounceBehavior(.basedOnSize)`; this task adds the missing gesture and proves the bounce fix.

**Files:**
- Modify: `Klar/Klar/Features/History/HistoryView.swift`

- [ ] **Step 1: Write the failing test for the forward guard**

The month math currently lives inside the view as `shiftMonth`, so it has to come out before it
can be tested. Create `Klar/KlarTests/CalendarMonthNavigationTests.swift`:

```swift
import XCTest
@testable import Klar

/// The swipe and the chevrons must agree on which months exist. Future months are unreachable
/// by either path.
final class CalendarMonthNavigationTests: XCTestCase {
    func testSteppingBackwardMovesOneMonth() throws {
        let june = try XCTUnwrap(KlarDate.calendar.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        let stepped = try XCTUnwrap(CalendarMonthNavigation.month(after: -1, from: june, today: june))
        XCTAssertEqual(KlarDate.calendar.component(.month, from: stepped), 5)
    }

    func testSteppingForwardPastTheCurrentMonthIsRefused() throws {
        let today = try XCTUnwrap(KlarDate.calendar.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        XCTAssertNil(CalendarMonthNavigation.month(after: 1, from: today, today: today))
    }

    func testSteppingForwardFromThePastIsAllowed() throws {
        let today = try XCTUnwrap(KlarDate.calendar.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        let april = try XCTUnwrap(KlarDate.calendar.date(from: DateComponents(year: 2026, month: 4, day: 15)))
        let stepped = try XCTUnwrap(CalendarMonthNavigation.month(after: 1, from: april, today: today))
        XCTAssertEqual(KlarDate.calendar.component(.month, from: stepped), 5)
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
xcodebuild test -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' -only-testing:KlarTests/CalendarMonthNavigationTests 2>&1 | tail -15
```

Expected: compilation failure — `CalendarMonthNavigation` does not exist.

- [ ] **Step 3: Extract the month math**

Add to `Klar/Klar/Features/History/HistoryView.swift`, above `CalendarSectionView`:

```swift
/// Month stepping, pulled out of the view so the chevrons and the swipe cannot drift apart and
/// so the "no future months" rule is testable.
enum CalendarMonthNavigation {
    static func month(after delta: Int, from visibleMonth: Date, today: Date = Date()) -> Date? {
        let calendar = KlarDate.calendar
        guard let shifted = calendar.date(byAdding: .month, value: delta, to: visibleMonth) else {
            return nil
        }
        guard shifted <= today || calendar.isDate(shifted, equalTo: today, toGranularity: .month) else {
            return nil
        }
        return shifted
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
xcodebuild test -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' -only-testing:KlarTests/CalendarMonthNavigationTests 2>&1 | tail -15
```

Expected: `Executed 3 tests, with 0 failures`

- [ ] **Step 5: Route both the chevrons and a new swipe through it**

In `CalendarSectionView`, replace `shiftMonth`:

```swift
    private func shiftMonth(_ delta: Int) {
        guard let shifted = CalendarMonthNavigation.month(after: delta, from: visibleMonth) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleMonth = shifted
        }
    }
```

Attach the gesture to the calendar card in `body` — on the `KlarCard`, not on the whole screen,
so it cannot fight the tab bar's own edge gestures:

```swift
            KlarCard(padding: 16) {
                monthHeader
                    .padding(.bottom, 12)

                weekdayHeader
                    .padding(.bottom, 6)

                dayGrid
            }
            // Horizontal-only: a drag that is mostly vertical belongs to the scroll view, and
            // the day cells' own tap gestures must keep working.
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        shiftMonth(value.translation.width < 0 ? 1 : -1)
                    }
            )
```

- [ ] **Step 6: Verify by hand**

```bash
xcodebuild build -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' 2>&1 | tail -3
```

In the simulator, on Verlauf → Kalender:

1. Drag left across the calendar card. Expected: nothing (already the current month).
2. Drag right. Expected: previous month, animated, same as tapping the left chevron.
3. Drag left again. Expected: back to the current month.
4. Try to drag the screen vertically. Expected: no scroll and no bounce — the content fits.
5. Tap a day cell. Expected: the day detail sheet still opens.

- [ ] **Step 7: Commit**

```bash
git add Klar/Klar/Features/History/HistoryView.swift Klar/KlarTests/CalendarMonthNavigationTests.swift
git commit -m "Swipe left and right to change month

Both the chevrons and the gesture go through one stepping function, so the
no-future-months rule cannot drift between them."
```

---

# Phase 6 · Entry sheet spacing

### Task 13: Fit the entry sheet to its content

Report 4. In the screenshot there are no substances configured: the explanatory sentence renders,
an empty `ScrollView` claims the rest, and the `.medium` detent holds half a screen of nothing.
The sentence also points at a screen the user then has to go find.

**Files:**
- Modify: `Klar/Klar/Features/Entry/EntrySheetView.swift:39-111`

- [ ] **Step 1: Give the empty state its own branch**

In `EntrySheetView`, add:

```swift
    @State private var isManagingSubstances = false

    private var hasSubstances: Bool { !activeSubstances.isEmpty }
```

Replace the `.presentationDetents` modifier on the `Group`:

```swift
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $isManagingSubstances) { SubstancesView() }
```

and add:

```swift
    /// The empty state is three lines and a button; a half-screen detent around it is the
    /// "spacing" complaint.
    private var detents: Set<PresentationDetent> {
        guard stage.isPicker else { return [.large] }
        return hasSubstances ? [.medium, .large] : [.height(300)]
    }
```

- [ ] **Step 2: Replace the picker with a branching one**

```swift
    private var substancePicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Eintrag")
                .font(Klar.TypeScale.title)
                .foregroundStyle(Klar.text)
                .padding(.bottom, 4)

            Text(hasSubstances
                 ? "Tippen genügt. Details kannst du später ergänzen."
                 : "Noch keine Substanz ausgewählt.")
                .font(Klar.TypeScale.bodySmall)
                .foregroundStyle(Klar.textTertiary)
                .padding(.bottom, 18)

            if hasSubstances {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(activeSubstances) { substance in
                            Button {
                                save(substance)
                            } label: {
                                substanceRow(substance)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            } else {
                // Pointing at Einstellungen and leaving the user to find it was the old copy.
                // The button is the same distance away and does not have to be searched for.
                KlarPrimaryButton(title: "Substanzen auswählen") {
                    isManagingSubstances = true
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Klar.surface)
    }

    private func substanceRow(_ substance: Substance) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Klar.substanceColor(substance.colorIndex))
                .frame(width: 12, height: 12)
            Text(substance.name)
                .font(Klar.TypeScale.body)
                .foregroundStyle(Klar.text)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(Klar.surface)
        .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous)
                .strokeBorder(Klar.border, lineWidth: 1)
        }
    }
```

- [ ] **Step 3: Prune the replaced string**

```bash
python3 - <<'EOF'
import json
path = "Klar/Klar/Localizable.xcstrings"
data = json.load(open(path))
data["strings"].pop("Noch keine Substanz ausgewählt. Du kannst sie in den Einstellungen ergänzen.", None)
json.dump(data, open(path, "w"), ensure_ascii=False, indent=2, sort_keys=True)
open(path, "a").write("\n")
EOF
```

- [ ] **Step 4: Build and screenshot both states**

```bash
xcodebuild build -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' 2>&1 | tail -3
```

Screenshot the "+" sheet with no substances (expected: a short sheet, roughly a third of the
screen, with a working "Substanzen auswählen" button) and with three substances (expected:
unchanged from today, medium detent, list fills it).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Fit the entry sheet to its empty state

A half-screen detent around three lines of text, plus a sentence pointing at
a screen the user then had to find."
```

---

# Phase 7 · Copy

### Task 14: Delete the quota absolution line

Report 11, the one the user named specifically.

**Files:**
- Modify: `Klar/Klar/Features/Today/TodayView.swift:312`

- [ ] **Step 1: Delete the line**

In `NewMonthCard`, remove:

```swift
            Text("Jeder Monat beginnt bei null. Kein Rückblick auf den letzten, kein Vorwurf.")
                .font(Klar.TypeScale.bodySmall)
                .foregroundStyle(Klar.textOnInverseSecondary)
```

and drop the now-trailing `.padding(.bottom, 6)` from the `quotaLine` `Text` above it. The card
keeps "Neuer Monat" and the factual "Kontingent: 4." — the information stays, the absolution goes.

Update the comment at `TodayView.swift:41-42`, which quotes the deleted sentence:

```swift
                    // B3 · Only on the 1st. The quota resets, and the card says so — the number
                    // and nothing else.
```

- [ ] **Step 2: Prune the string**

```bash
python3 - <<'EOF'
import json
path = "Klar/Klar/Localizable.xcstrings"
data = json.load(open(path))
data["strings"].pop("Jeder Monat beginnt bei null. Kein Rückblick auf den letzten, kein Vorwurf.", None)
json.dump(data, open(path, "w"), ensure_ascii=False, indent=2, sort_keys=True)
open(path, "a").write("\n")
EOF
```

- [ ] **Step 3: Build and commit**

```bash
xcodebuild build -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' 2>&1 | tail -3
git add -A
git commit -m "Drop the new-month absolution line

The card states the quota. It does not need to forgive anyone."
```

---

### Task 15: The em-dash pass

Report 10. Measured baseline across the 328 user-facing strings (1714 words): 32 em dashes,
18.7 per 1000 words. Flagged vocabulary, inflated significance and negative parallelism all score
zero — the vocabulary is fine. The tell is one construction repeated 32 times: *[Fakt] —
[Beruhigung]*.

**Rule: delete the reassurance clause, do not rewrite it.** An em dash survives only where it
separates an aside that carries information.

**Files:**
- Modify: `Klar/Klar/Features/Plans/PlansView.swift`, `Klar/Klar/Features/Today/TodayView.swift`, `Klar/Klar/Features/Settings/SettingsView.swift`, `Klar/Klar/Features/Entry/EntrySheetView.swift`, `Klar/Klar/Features/Onboarding/OnboardingFlowView.swift`, `Klar/Klar/Features/Help/HelpView.swift`, `Klar/Klar/Features/Review/WeeklyReviewFlowView.swift`, `Klar/Klar/Localizable.xcstrings`

- [ ] **Step 1: Record the baseline**

```bash
SKILL="$HOME/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin"
SLOP=$(find "$SKILL" -name slopcheck.py -path "*anti-ai-writing*" | head -1)
mkdir -p /tmp/klarcopy
grep -rhoE '"[^"]{12,}"' --include="*.swift" Klar/Klar \
  | grep -E '[äöüßA-ZÄÖÜ]' \
  | grep -vE '^"[a-z._]+"$|systemImage|klar\.|accessibilityIdentifier' \
  | sed 's/^"//; s/"$//' | sort -u > /tmp/klarcopy/before.txt
python3 "$SLOP" /tmp/klarcopy/before.txt --lang de | head -20
```

Expected: `em_dash 32 · 18.7`

- [ ] **Step 2: Apply these exact rewrites**

| File | Before | After |
|---|---|---|
| PlansView | `Noch kein Plan — das ist in Ordnung.` | `Noch kein Plan.` |
| PlansView | `Max. 3 aktive Pläne — Fokus statt Liste.` | `Max. 3 aktive Pläne.` |
| PlanEditorView | `Max. 3 aktive Pläne — Fokus statt Liste. Pausiere einen bestehenden Plan, um Platz zu schaffen.` | `Max. 3 aktive Pläne. Pausiere einen bestehenden Plan, um Platz zu schaffen.` |
| PlansView | `Ein guter Plan braucht Kenntnis der eigenen Muster. Deshalb kommt er nicht am Tag 1 — sondern wenn deine Einträge etwas zeigen.` | `Ein guter Plan braucht Kenntnis der eigenen Muster. Er entsteht, wenn deine Einträge etwas zeigen.` |
| TodayView | `Ein Plan entsteht aus deinen Mustern — nicht am Tag 1.` | `Ein Plan entsteht aus deinen Mustern.` |
| SettingsView | `Generische Texte — nie Substanznamen` | `Generische Texte, nie Substanznamen` |
| SettingsView | `Erscheint im Craving-SOS — in dem Moment, in dem du es am wenigsten formulieren kannst.` | `Erscheint im Craving-SOS.` |
| EntrySheetView | `Möchtest du deinen Plan dazu ansehen? — Freiwillig, nicht jetzt nötig.` | delete the whole `Text(…)` and its `.padding(.bottom, 20)` — it is a question with no button |
| OnboardingFlowView | `Erstmal nur beobachten — kein Limit, kein Druck.` | `Erstmal nur beobachten. Kein Limit.` |
| OnboardingFlowView | `Jederzeit änderbar — die Auswahl ist kein Bekenntnis.` | `Jederzeit änderbar.` |
| OnboardingFlowView | `Kein Ziel am Tag 1 nötig. „Nur beobachten“ ist Stufe 1 — anfangen darfst du trotzdem.` | `Kein Ziel am Tag 1 nötig. „Nur beobachten“ ist Stufe 1.` |
| OnboardingFlowView | `2–3 persönliche Alternativen. Im Craving ist keine Zeit, sie zu suchen — darum jetzt, in Ruhe.` | `2–3 persönliche Alternativen. Im Craving ist keine Zeit, sie zu suchen.` |
| WeeklyReviewFlowView | `Eine eintragsfreie Woche. Rein deskriptiv — kein Lob, keine Wertung.` | `Eine eintragsfreie Woche.` |
| WeeklyReviewFlowView | `Dein Plan für nächste Woche — du entscheidest.` | `Dein Plan für nächste Woche.` |
| HistoryView | `Dein Archiv — nur deine eigene Ausgangslage.` | `Dein Archiv.` |
| GoalsView | `Abstinenz — Einträge werden weiterhin ohne Wertung erfasst.` | `Abstinenz. Einträge werden weiterhin ohne Wertung erfasst.` |
| PlanCheckInView | `Abstinenz — jeder Eintrag wird trotzdem ohne Wertung erfasst.` | `Abstinenz. Jeder Eintrag wird trotzdem ohne Wertung erfasst.` |

Each edit is a `Text("…")` literal; find them with
`grep -rn "Noch kein Plan — das ist in Ordnung" --include="*.swift" Klar/Klar` and so on.

- [ ] **Step 3: Handle the remaining em dashes one by one**

```bash
grep -rn "—" --include="*.swift" Klar/Klar | grep -v "^.*:.*//" | grep '"'
```

For each hit still standing: keep it only if what follows the dash is information the user needs.
Keep, for example, `Alkohol (bildet Cocaethylen — deutlich herztoxischer)` and the risk-info
sentences in `HelpContent.swift`, which are medical facts. Convert the rest to a period or a
comma. Do not invent replacement prose.

- [ ] **Step 4: Leave these three alone — decided, do not change them**

These read as reassurance and were put to the user on 2026-08-01. The answer was to keep all
three. Do not touch them, and do not let the density gate in Step 6 tempt you into it (none of
them contains an em dash, so they do not affect it):

1. `Steht so in deinem Verlauf. Ehrliche Daten sind wertvoller als eingehaltene Zahlen.` (EntrySheetView, over-limit notice)
2. `Local-first. Kein Account, kein Server, nichts zu kompromittieren.` (SettingsView footer)
3. `Ein ruhiger Tag.` (TodayView empty state)

- [ ] **Step 5: Update the string catalogue**

Every edited `Text("…")` changed its catalogue key. Prune the orphans:

```bash
python3 - <<'EOF'
import json, re, pathlib
path = pathlib.Path("Klar/Klar/Localizable.xcstrings")
data = json.loads(path.read_text())
sources = " ".join(p.read_text() for p in pathlib.Path("Klar/Klar").rglob("*.swift"))
removed = [k for k in list(data["strings"]) if k and k not in sources]
for k in removed:
    del data["strings"][k]
path.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
print(f"pruned {len(removed)} orphaned keys")
EOF
```

Expected: a non-zero count roughly matching the number of strings you changed. Xcode regenerates
the new keys on the next build.

- [ ] **Step 6: Re-measure**

```bash
SKILL="$HOME/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin"
SLOP=$(find "$SKILL" -name slopcheck.py -path "*anti-ai-writing*" | head -1)
grep -rhoE '"[^"]{12,}"' --include="*.swift" Klar/Klar \
  | grep -E '[äöüßA-ZÄÖÜ]' \
  | grep -vE '^"[a-z._]+"$|systemImage|klar\.|accessibilityIdentifier' \
  | sed 's/^"//; s/"$//' | sort -u > /tmp/klarcopy/after.txt
python3 "$SLOP" /tmp/klarcopy/after.txt --lang de | head -20
diff /tmp/klarcopy/before.txt /tmp/klarcopy/after.txt
```

Gate: `em_dash` per 1000 words **below 6**, and `flagged_vocabulary`, `inflated_significance`,
`negative_parallelism` still at 0. Read the diff line by line and confirm no sentence lost
information — only reassurance.

- [ ] **Step 7: Build and commit**

```bash
xcodebuild build -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' 2>&1 | tail -3
git add -A
git commit -m "Cut the reassurance clauses from the UI copy

32 em dashes in 1714 words, two thirds of them the same [fact] — [comfort]
construction. The facts stay, the comfort goes."
```

---

# Phase 8 · Dark mode

### Task 16: Add the appearance setting

**Files:**
- Create: `Klar/Klar/App/AppAppearance.swift`
- Modify: `Klar/Klar/App/AppSettings.swift`

- [ ] **Step 1: Create the enum**

```swift
import SwiftUI

/// Follows the system by default. An app that hides in a privacy-conscious pocket should not be
/// the one window that stays bright at night.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Hell"
        case .dark: "Dunkel"
        }
    }

    /// `nil` hands the decision back to iOS.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
```

- [ ] **Step 2: Wire it into `AppSettings`**

In `init`:

```swift
        self.appearance = AppAppearance(
            rawValue: defaults.string(forKey: Keys.appearance) ?? ""
        ) ?? .system
```

As a property:

```swift
    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }
```

In `Keys`:

```swift
        static let appearance = "klar.appearance"
```

The `?? .system` fallback is what makes System the default on existing installs too — there is no
stored value to migrate.

- [ ] **Step 3: Build and commit**

```bash
xcodebuild build -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' 2>&1 | tail -3
git add -A
git commit -m "Add an appearance preference defaulting to System"
```

---

### Task 17: Make the design tokens adaptive

**Files:**
- Modify: `Klar/Klar/DesignSystem/KlarTheme.swift`

- [ ] **Step 1: Add the resolver and the dark ramp**

At the top of `enum Klar`, after the `Palette` block:

```swift
    /// Resolves per trait collection rather than per asset catalog entry: the 25 semantic tokens
    /// below stay one line each, which is what keeps them mappable 1:1 onto the design file's CSS
    /// custom properties.
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
```

Add `import UIKit` at the top of the file.

- [ ] **Step 2: Convert the semantic aliases**

Replace the whole `// MARK: - Semantic aliases` block. The dark values are the existing teal ramp
read from the other end, so the two schemes stay one family:

```swift
    static let bg = adaptive(light: 0xFFFFFF, dark: 0x0E1719)
    static let bgSubtle = adaptive(light: 0xF7FAFA, dark: 0x15272B)
    static let bgSunken = adaptive(light: 0xF4F6F6, dark: 0x0E1719)
    static let bgInverse = adaptive(light: 0x0E3B43, dark: 0x0A2429)
    static let bgInverseDeep = adaptive(light: 0x15272B, dark: 0x081A1E)

    static let surface = adaptive(light: 0xFFFFFF, dark: 0x1B3238)
    static let surfaceTint = adaptive(light: 0xEEF6F5, dark: 0x17444C)

    static let border = adaptive(light: 0xD5E4E2, dark: 0x28545C)
    static let borderSubtle = adaptive(light: 0xE6F2F0, dark: 0x1F4048)
    static let borderStrong = adaptive(light: 0xBFD8D4, dark: 0x44585E)

    static let text = adaptive(light: 0x15272B, dark: 0xEEF6F5)
    static let textSecondary = adaptive(light: 0x44585E, dark: 0xBFD8D4)
    static let textTertiary = adaptive(light: 0x5C7078, dark: 0x8FB2AE)
    /// Always on a filled accent or inverse surface, so it does not flip.
    static let textOnInverse = Color.white
    static let textOnInverseSecondary = Palette.teal300

    static let accent = adaptive(light: 0x02C39A, dark: 0x02C39A)
    static let accentStrong = adaptive(light: 0x1A6B62, dark: 0x02C39A)
    static let accentTint = adaptive(light: 0xD9F2EB, dark: 0x123B37)

    static let link = adaptive(light: 0x028090, dark: 0x40B4C4)

    static let danger = adaptive(light: 0xC0392B, dark: 0xE8705F)
    static let dangerTint = adaptive(light: 0xFBECEA, dark: 0x3A1C18)
```

Update the file's header comment, which currently promises light only:

```swift
/// Ported 1:1 from the Claude Design project "Klar iOS App Design"
/// (`_ds/klar-design-system-.../tokens/*.css`). Names mirror the CSS custom
/// properties so a token change in the design file maps to exactly one change here.
///
/// The design file ships light only; the dark values are derived from the same teal ramp read
/// from the other end, so both schemes stay one family. `RootView` applies the user's choice.
```

- [ ] **Step 3: Make elevation work in the dark**

`Klar.Shadow` is `teal900` at 6–12 % opacity, which is invisible on a dark background. Replace
`klarShadow` at the bottom of the file:

```swift
extension View {
    /// In dark mode a translucent dark shadow does nothing. Elevation there comes from the
    /// surface being lighter than its background, so the shadow simply drops out.
    func klarShadow(_ shadow: (color: Color, radius: CGFloat, y: CGFloat)) -> some View {
        modifier(KlarShadowModifier(shadow: shadow))
    }
}

private struct KlarShadowModifier: ViewModifier {
    let shadow: (color: Color, radius: CGFloat, y: CGFloat)
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.shadow(
            color: colorScheme == .dark ? .clear : shadow.color,
            radius: shadow.radius,
            x: 0,
            y: shadow.y
        )
    }
}
```

- [ ] **Step 4: Build and commit**

```bash
xcodebuild build -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' 2>&1 | tail -3
git add -A
git commit -m "Make the design tokens adaptive

Dark values come off the same teal ramp, and shadows drop out in dark where
they were invisible anyway."
```

---

### Task 18: Audit the hardcoded whites

42 `.white` literals across 16 files. Most sit on a filled accent or inverse surface and are
correct; the ones that mean "the page" have to become `Klar.surface`.

**Files:**
- Modify: whichever of the 15 remaining files the audit turns up (`PanicView.swift` is gone by now)

- [ ] **Step 1: List them**

```bash
grep -rn "\.white\|Color\.white" --include="*.swift" Klar/Klar
```

Expected: 40 hits across 15 files (2 fewer than the original 42 — `PanicView.swift` was deleted in
Task 4).

- [ ] **Step 2: Classify and fix**

For each hit, decide:

- **On `Klar.accent`, `KlarInverseCard`, or the SOS card** — correct as is. White on emerald and
  white on teal-950 read the same in both schemes. Leave it.
- **As a background standing in for the page or a card** — replace with `Klar.surface`.
- **As foreground text on `Klar.surface`** — replace with `Klar.text`.

Known cases from the current code:

| Location | Verdict |
|---|---|
| `HelpView.swift` SOS card (6 hits) | keep — all on `Klar.accent` |
| `TodayView.swift:224` today-dot fill | keep — on `Klar.text` fill |
| `TodayView.swift:302,310` NewMonthCard | keep — on `KlarInverseCard` |
| `PlansView.swift` suggestion card | keep — on `KlarInverseCard` |
| `KlarComponents.swift` primary button | keep — on `Klar.accent` |
| `EntrySheetView.swift:291` mood chip | keep — on `Klar.accent` when selected |

Anything not in that table gets read in context before it is touched.

- [ ] **Step 3: Verify no bare white background survives**

```bash
grep -rn "background(Color.white\|background(.white" --include="*.swift" Klar/Klar
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Audit hardcoded whites for dark mode

Whites on accent and inverse surfaces stay; whites standing in for the page
become Klar.surface."
```

---

### Task 19: Apply the scheme and finish the edges

**Files:**
- Modify: `Klar/Klar/App/RootView.swift:55`, `Klar/Klar/Features/Settings/SettingsView.swift`, `Klar/Klar/Assets.xcassets/LaunchBackground.colorset/Contents.json`

- [ ] **Step 1: Apply the user's choice**

In `Klar/Klar/App/RootView.swift`, replace:

```swift
        .preferredColorScheme(.light) // The design ships light only.
```

with:

```swift
        .preferredColorScheme(settings.appearance.colorScheme)
```

- [ ] **Step 2: Add the settings row**

`SettingsPickerRow` is typed to `AutoLockDelay`. Generalise it — replace the struct in
`Klar/Klar/Features/Settings/SettingsView.swift`:

```swift
struct SettingsPickerRow<Value: Hashable & Identifiable>: View {
    let icon: String
    let title: LocalizedStringKey
    let options: [Value]
    let label: (Value) -> String
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Klar.textSecondary)
                .frame(width: 18)
            Text(title)
                .font(Klar.TypeScale.body)
                .foregroundStyle(Klar.text)
            Spacer()
            Picker(title, selection: $selection) {
                ForEach(options) { option in
                    Text(label(option)).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(Klar.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}
```

Update the existing Auto-Sperre call site:

```swift
                            SettingsPickerRow(
                                icon: "timer",
                                title: "Auto-Sperre",
                                options: AutoLockDelay.allCases,
                                label: \.label,
                                selection: $settings.autoLockDelay
                            )
```

Add a new "Darstellung" group between "Privatsphäre & Sicherheit" and "Deine Daten":

```swift
                        KlarSectionLabel(text: "Darstellung")
                            .padding(.bottom, 8)

                        SettingsGroup {
                            SettingsPickerRow(
                                icon: "circle.lefthalf.filled",
                                title: "Erscheinungsbild",
                                options: AppAppearance.allCases,
                                label: \.label,
                                selection: $settings.appearance
                            )
                        }
                        .padding(.bottom, 16)
```

- [ ] **Step 3: Give the launch background a dark variant**

Replace `Klar/Klar/Assets.xcassets/LaunchBackground.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0xFA",
          "green" : "0xFA",
          "red" : "0xF7"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0x2B",
          "green" : "0x27",
          "red" : "0x15"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

The dark value is `bgSubtle`'s dark counterpart (`0x15272B`), so the launch frame still matches
the first real frame and there is no flash.

- [ ] **Step 4: Screenshot every main screen in both schemes**

```bash
xcodebuild build -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' 2>&1 | tail -3
xcrun simctl ui booted appearance dark
```

With the setting on "System", screenshot Heute (empty and with entries), Verlauf/Kalender,
Verlauf/Trends, Pläne, Hilfe, Einstellungen, the entry sheet and the lock screen. Then:

```bash
xcrun simctl ui booted appearance light
```

and repeat. Check specifically: text legible on `bgSubtle` in both, cards distinguishable from
their background in dark without shadows, the emerald accent not glowing, and the red danger tint
not vibrating on the dark background.

Then set the app's own preference to "Hell" and confirm it stays light while the system is dark,
and "Dunkel" the other way round.

- [ ] **Step 5: Full test run**

```bash
xcodebuild test -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **` for KlarTests and KlarUITests.

- [ ] **Step 6: Update the implementation doc**

In `docs/klar-screens-implementation.md`, update the Foundations table: `KlarTheme.swift` is no
longer a light-only port, and add a row for `KlarScreen.swift`. Correct any sentence claiming the
app is light-only.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Ship dark mode, following the system by default

The launch background gets a dark variant too, so there is no light flash
before the first real frame."
```

---

## Done criteria

- [ ] `xcodebuild test -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE'` reports `** TEST SUCCEEDED **`
- [ ] Face ID prompts on a fresh launch and on every return from the background, including from an already-locked screen
- [ ] `grep -rn "Panic\|isPanicGestureEnabled" --include="*.swift" Klar` is empty
- [ ] Export produces JSON only; that JSON imports back into a populated app; a corrupt file leaves the data intact
- [ ] On Hilfe, Verlauf and Pläne the lowest interactive element sits within ~15 % of the tab bar
- [ ] The calendar does not bounce and responds to horizontal swipes
- [ ] The entry sheet with no substances is about a third of the screen and offers a button that resolves it
- [ ] `slopcheck.py` reports under 6 em dashes per 1000 words
- [ ] Every main screen has been screenshot in both light and dark
