import SwiftUI

enum DashboardModeType {
    case morning, evening
}

@Observable
class DashboardMode {
    var activeMode: DashboardModeType = .morning
    var isManualOverride = false

    init() {
        activeMode = Self.autoMode()
    }

    static func autoMode() -> DashboardModeType {
        let hour = currentHour()
        // Evening: 3pm (15) through 1am (inclusive of 0)
        return (hour >= 15 || hour < 1) ? .evening : .morning
    }

    private static func currentHour() -> Int {
        var cal = Calendar.current
        cal.timeZone = DashboardConfig.tz
        return cal.component(.hour, from: Date())
    }

    /// Call on scenePhase → .active or when time boundary is crossed
    func resetToAuto() {
        isManualOverride = false
        activeMode = Self.autoMode()
    }

    /// Manual toggle by user
    func toggle() {
        isManualOverride = true
        activeMode = (activeMode == .morning) ? .evening : .morning
    }

    /// Check if auto mode changed (call periodically or on app foreground)
    func applyAutoIfNeeded() {
        if !isManualOverride {
            activeMode = Self.autoMode()
        }
    }

    // MARK: - Date Helpers

    /// The "target" date for weather and calendar (today in morning, tomorrow in evening)
    var targetDate: Date {
        if activeMode == .evening {
            return Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        }
        return Date()
    }

    var greeting: String {
        activeMode == .morning ? "GOOD MORNING" : "GOOD EVENING"
    }

    var calendarSubtitle: String {
        activeMode == .morning ? "Today" : "Tomorrow"
    }

    var otherModeLabel: String {
        activeMode == .morning ? "EVENING" : "MORNING"
    }
}
