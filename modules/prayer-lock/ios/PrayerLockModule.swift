import ExpoModulesCore
import FamilyControls
import ManagedSettings
import DeviceActivity
import SwiftUI

// These names must match the monitor extension exactly.
let appGroup = "group.com.sif.projectsalah"
let selectionKey = "allowedSelection"
let tableKey = "scheduleTable"

extension ManagedSettingsStore.Name {
    static let prayer = Self("prayer")
}

extension DeviceActivityName {
    // Wakes the extension just after midnight to register that day's prayers.
    static let daily = Self("Daily")
}

// One prayer's lock time, sent from TypeScript.
struct PrayerSchedule: Record {
    @Field var name: String = ""
    @Field var hour: Int = 0
    @Field var minute: Int = 0
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

        // Saves the timetable (JSON text) for the extension to read at midnight.
        Function("saveScheduleTable") { (json: String) in
            UserDefaults(suiteName: appGroup)?.set(json, forKey: tableKey)
            Log.write("Saved timetable (\(json.count) characters)")
        }

        // Replaces the prayer schedules with these ones, and makes sure
        // the Daily schedule exists. Returns how many prayers were registered.
        Function("schedulePrayers") { (prayers: [PrayerSchedule]) -> Int in
            PrayerScheduler.schedule(prayers)
        }

        // Names of the schedules iOS is currently holding.
        Function("activeSchedules") { () -> [String] in
            DeviceActivityCenter().activities.map(\.rawValue)
        }

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

enum PrayerScheduler {
    // Apple rejects schedules shorter than 15 minutes.
    static let intervalMinutes = 15

    static func schedule(_ prayers: [PrayerSchedule]) -> Int {
        let center = DeviceActivityCenter()

        // Stop every schedule except Daily.
        // (Calling stopMonitoring with an empty list would stop everything, including Daily.)
        let old = center.activities.filter { $0 != .daily }
        if !old.isEmpty {
            center.stopMonitoring(old)
        }

        var count = 0
        for prayer in prayers {
            let startMinutes = prayer.hour * 60 + prayer.minute
            let endMinutes = startMinutes + intervalMinutes

            // A schedule can't run past midnight, so skip anything that would.
            if endMinutes >= 24 * 60 {
                Log.write("Skipped \(prayer.name): too close to midnight")
                continue
            }

            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: prayer.hour, minute: prayer.minute),
                intervalEnd: DateComponents(hour: endMinutes / 60, minute: endMinutes % 60),
                repeats: false
            )

            do {
                try center.startMonitoring(DeviceActivityName(prayer.name), during: schedule)
                count += 1
                Log.write("Scheduled \(prayer.name) lock at \(String(format: "%02d:%02d", prayer.hour, prayer.minute))")
            } catch {
                Log.write("Failed to schedule \(prayer.name): \(error.localizedDescription)")
            }
        }

        ensureDaily(center)
        return count
    }

    // Registers the repeating 00:01–00:16 schedule, if it isn't already.
    static func ensureDaily(_ center: DeviceActivityCenter) {
        if center.activities.contains(.daily) { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 1),
            intervalEnd: DateComponents(hour: 0, minute: 16),
            repeats: true
        )

        do {
            try center.startMonitoring(.daily, during: schedule)
            Log.write("Daily schedule registered for 00:01")
        } catch {
            Log.write("Failed to register Daily: \(error.localizedDescription)")
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