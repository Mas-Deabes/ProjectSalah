import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

// These must match PrayerLockModule.swift exactly,
// so the app and the extension share the same data.
let appGroup = "group.com.sif.projectsalah"
let selectionKey = "allowedSelection"
let tableKey = "scheduleTable"

extension ManagedSettingsStore.Name {
    static let prayer = Self("prayer")
}

extension DeviceActivityName {
    static let daily = Self("Daily")
    static let dailyTest = Self("DailyTest")
}

// One row entry in the timetable. Matches ScheduleEntry in prayerTimes.ts.
struct ScheduleEntry: Decodable {
    let name: String
    let hour: Int
    let minute: Int
}

// iOS runs this in the background when a schedule starts or ends,
// even if the app is closed.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        Log.write("Extension: \(activity.rawValue) started")

        if activity == .daily || activity == .dailyTest {
            // Midnight job: register today's prayers. Doesn't lock.
            scheduleToday()
        } else {
            lock()
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Doesn't unlock. Only "I've prayed" in the app does that.
        Log.write("Extension: \(activity.rawValue) ended")
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

    private func scheduleToday() {
        // 1. Read the timetable the app saved.
        guard let json = UserDefaults(suiteName: appGroup)?.string(forKey: tableKey),
              let data = json.data(using: .utf8),
              let table = try? JSONDecoder().decode([String: [ScheduleEntry]].self, from: data) else {
            Log.write("No timetable saved. Open the app to create one.")
            return
        }

        // 2. Find today's row.
        let today = Self.dateKey(Date())
        guard let entries = table[today] else {
            Log.write("No times for \(today). Open the app to refresh the timetable.")
            return
        }

        // 3. Replace yesterday's prayer schedules with today's.
        let center = DeviceActivityCenter()
        let old = center.activities.filter { $0 != .daily }
        if !old.isEmpty {
            center.stopMonitoring(old)
        }

        let calendar = Calendar.current
        let now = calendar.component(.hour, from: Date()) * 60 + calendar.component(.minute, from: Date())

        var count = 0
        for entry in entries {
            let startMinutes = entry.hour * 60 + entry.minute
            let endMinutes = startMinutes + 15

            // Skip times already passed (or about to), and anything crossing midnight.
            if startMinutes <= now + 1 || endMinutes >= 24 * 60 { continue }

            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: entry.hour, minute: entry.minute),
                intervalEnd: DateComponents(hour: endMinutes / 60, minute: endMinutes % 60),
                repeats: false
            )

            do {
                try center.startMonitoring(DeviceActivityName(entry.name), during: schedule)
                count += 1
            } catch {
                Log.write("Failed to schedule \(entry.name): \(error.localizedDescription)")
            }
        }

        Log.write("Scheduled \(count) prayers for \(today)")
    }

    // Today's date as "YYYY-MM-DD", matching dateKey() in prayerTimes.ts.
    private static func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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