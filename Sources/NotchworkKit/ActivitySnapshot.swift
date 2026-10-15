import Foundation

/// Versioned local bridge payload. Dates are seconds since the Unix epoch.
public struct ActivitySnapshot: Codable, Sendable {
    public var version: Int
    public var sentAt: Double
    public var activity: NotchActivity
    public init(activity: NotchActivity, now: Date = Date()) {
        version = 1; sentAt = now.timeIntervalSince1970; self.activity = activity
    }
    public func freshActivity(sourceID: String, id: String, now: Date = Date()) throws -> NotchActivity {
        let age = now.timeIntervalSince1970 - sentAt
        guard version == 1, sentAt.isFinite, age >= -5, age < 58,
              activity.sourceID == sourceID, activity.id == id else {
            throw ActivityError.invalid("Waiting for a fresh activity from the connected app.")
        }
        try activity.validate()
        var result = activity
        result.ttl = min(activity.ttl, max(2, 60 - max(0, age)))
        return result
    }
}
