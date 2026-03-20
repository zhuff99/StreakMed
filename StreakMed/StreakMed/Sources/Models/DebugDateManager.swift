import Foundation
import Combine

/// Singleton that lets debug builds override "today" for testing
/// day-reset logic, streak calculations, and history.
/// In production builds (#if !DEBUG) currentDate always returns Date().
final class DebugDateManager: ObservableObject {
    static let shared = DebugDateManager()
    private init() {}

    /// When non-nil, the whole app uses this date instead of Date()
    @Published var overrideDate: Date? = nil

    var isOverriding: Bool { overrideDate != nil }

    /// Use this everywhere instead of Date()
    var currentDate: Date {
        #if DEBUG
        return overrideDate ?? Date()
        #else
        return Date()
        #endif
    }

    /// Move forward by N days from the current override (or today)
    func advanceDays(_ n: Int) {
        let base = overrideDate ?? Date()
        overrideDate = Calendar.current.date(byAdding: .day, value: n, to: base)
    }

    func reset() {
        overrideDate = nil
    }
}
