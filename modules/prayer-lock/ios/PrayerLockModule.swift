import ExpoModulesCore
import FamilyControls
import ManagedSettings
import DeviceActivity
import SwiftUI

// These names must match the monitor extension exactly (checkpoint 7b).
let appGroup = "group.com.sif.projectsalah"
let selectionKey = "allowedSelection"

extension ManagedSettingsStore.Name {
    static let prayer = Self("prayer")
}

// The bridge between TypeScript and Swift.
// Each Function/AsyncFunction becomes a method you can call from TypeScript.
public class PrayerLockModule: Module {
    public func definition() -> ModuleDefinition {
        Name("PrayerLock")

        Function("authorizationStatus") { () -> String in
            switch AuthorizationCenter.shared.authorizationStatus {
            case .approved: return "approved"
            case .denied: return "denied"
            case .notDetermined: return "notDetermined"
            @unknown default: return "unknown"
            }
        }

        AsyncFunction("requestAuthorization") { () async throws -> Void in
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        }

        Function("allowedAppCount") { () -> Int in
            loadSelection()?.applicationTokens.count ?? 0
        }

        // Shows Apple's app picker on top of the React Native screen.
        // Resolves with the number of apps chosen once the user taps Done.
        AsyncFunction("pickApps") { (promise: Promise) in
            guard let presenter = self.appContext?.utilities?.currentViewController() else {
                promise.reject("NO_VIEW", "Couldn't find a screen to show the picker on")
                return
            }
            var host: UIHostingController<AppPickerSheet>?
            let sheet = AppPickerSheet(selection: loadSelection() ?? FamilyActivitySelection()) { selection in
                saveSelection(selection)
                host?.dismiss(animated: true)
                promise.resolve(selection.applicationTokens.count)
            }
            host = UIHostingController(rootView: sheet)
            presenter.present(host!, animated: true)
        }.runOnQueue(.main)

        Function("lockNow") {
            PrayerLock.lock()
        }

        Function("unlock") {
            PrayerLock.unlock()
        }

        Function("readLog") { () -> String in
            Log.read()
        }

        Function("clearLog") {
            Log.clear()
        }
    }
}

// SwiftUI screen wrapping Apple's picker, with a Done button.
struct AppPickerSheet: View {
    @State var selection: FamilyActivitySelection
    let onDone: (FamilyActivitySelection) -> Void

    var body: some View {
        NavigationView {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Allowed apps")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { onDone(selection) }
                    }
                }
        }
        // Stops the user swiping it away without tapping Done.
        .interactiveDismissDisabled()
    }
}

func saveSelection(_ selection: FamilyActivitySelection) {
    if let data = try? JSONEncoder().encode(selection) {
        UserDefaults(suiteName: appGroup)?.set(data, forKey: selectionKey)
    }
}

func loadSelection() -> FamilyActivitySelection? {
    guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: selectionKey) else { return nil }
    return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
}

enum PrayerLock {
    static func lock() {
        let allowed = loadSelection()?.applicationTokens ?? []
        ManagedSettingsStore(named: .prayer).shield.applicationCategories = .all(except: allowed)
        Log.write("Lock applied. Allowed apps: \(allowed.count)")
    }

    static func unlock() {
        ManagedSettingsStore(named: .prayer).clearAllSettings()
        Log.write("Unlocked")
    }
}

enum Log {
    private static var url: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("log.txt")
    }

    static func write(_ message: String) {
        let time = Date().formatted(date: .omitted, time: .standard)
        let line = "\(time)  \(message)\n"
        guard let url else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    static func read() -> String {
        guard let url else { return "Shared folder not available." }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? "(empty)"
    }

    static func clear() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}