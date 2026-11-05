import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

// These must match PrayerLockModule.swift exactly,
// so the app and the extension share the same data.
let appGroup = "group.com.sif.projectsalah"
let selectionKey = "allowedSelection"

extension ManagedSettingsStore.Name {
    static let prayer = Self("prayer")
}

// iOS runs this in the background when a prayer schedule starts or ends,
// even if the app is closed.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        Log.write("Extension: \(activity.rawValue) started")
        lock()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Doesn't unlock. Only "I've prayed" in the app does that.
        Log.write("Extension: \(activity.rawValue) ended, lock kept")
    }

    private func lock() {
        var allowed = Set<ApplicationToken>()
        if let data = UserDefaults(suiteName: appGroup)?.data(forKey: selectionKey),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            allowed = selection.applicationTokens
        }
        ManagedSettingsStore(named: .prayer).shield.applicationCategories = .all(except: allowed)
        Log.write("Lock applied. Allowed apps: \(allowed.count)")
    }
}

// Writes to the same log.txt the app reads.
enum Log {
    static func write(_ message: String) {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("log.txt") else { return }

        let time = Date().formatted(date: .omitted, time: .standard)
        let line = "\(time)  \(message)\n"

        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}