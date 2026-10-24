import Foundation

public enum ActivityPriority: String, Codable, CaseIterable, Sendable {
    case normal, important, urgent
    public static let low = Self.normal
    public static let mid = Self.important
    public static let high = Self.urgent
    public var notificationLevel: String { ["low", "mid", "high"][rank] }
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "low", "normal": self = .normal
        case "mid", "important": self = .important
        case "high", "urgent": self = .urgent
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Use low, mid, or high priority.")
        }
    }
    // Keep the wire encoding readable by existing hosts and snapshot consumers.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
    public var rank: Int { switch self { case .normal: return 0; case .important: return 1; case .urgent: return 2 } }
}
public enum NotchSide: String, Codable, CaseIterable, Sendable { case left, right }
public struct ActivityAction: Codable, Equatable, Sendable {
    public var title: String
    public var url: String
    public init(title: String, url: String) { self.title = title; self.url = url }
}
/// A small, declarative activity. Send another activity with the same sourceID/id to update it.
public struct NotchActivity: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var sourceID: String
    public var sourceName: String
    public var title: String
    public var subtitle: String
    public var symbol: String
    public var priority: ActivityPriority
    public var preferredSide: NotchSide
    public var progress: Double?
    public var details: [String]
    public var actions: [ActivityAction]
    public var interface: ActivityInterface?
    public var iconPNG: String?
    public var notificationID: String?
    public var ttl: Double
    public init(id: String, sourceID: String, sourceName: String, title: String,
                subtitle: String = "", symbol: String = "app", priority: ActivityPriority = .normal,
                preferredSide: NotchSide = .left, progress: Double? = nil, details: [String] = [],
                actions: [ActivityAction] = [], ttl: Double = 60, interface: ActivityInterface? = nil, iconPNG: String? = nil, notificationID: String? = nil) {
        self.id = id; self.sourceID = sourceID; self.sourceName = sourceName; self.title = title
        self.subtitle = subtitle; self.symbol = symbol; self.priority = priority; self.preferredSide = preferredSide
        self.progress = progress; self.details = details; self.actions = actions; self.ttl = ttl; self.interface = interface; self.iconPNG = iconPNG; self.notificationID = notificationID
    }
    public func validate() throws {
        try interface?.validate()
        if let iconPNG { try ActivityIcon.validate(iconPNG) }
        func require(_ value: Bool, _ message: String) throws { if !value { throw ActivityError.invalid(message) } }
        try require([id, sourceID].allSatisfy { $0.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || [45, 46, 95].contains($0) } }, "IDs may contain letters, digits, dots, underscores, and hyphens.")
        try require(!id.isEmpty && id.utf8.count <= 128 && !sourceID.isEmpty && sourceID.utf8.count <= 128, "IDs must contain 1–128 bytes.")
        try require(!sourceName.isEmpty && sourceName.count <= 60 && !title.isEmpty && title.count <= 120, "A short app name and title are required.")
        try require(subtitle.count <= 240 && symbol.count <= 80, "Subtitle or symbol is too long.")
        try require(notificationID.map { !$0.isEmpty && $0.utf8.count <= 128 } ?? true, "notificationID must contain 1–128 bytes.")
        try require(ttl.isFinite && (2...3600).contains(ttl), "ttl must be 2–3600 seconds.")
        if let progress { try require(progress.isFinite && (0...1).contains(progress), "Progress must be between 0 and 1.") }
        try require(details.count <= 30 && details.allSatisfy { $0.count <= 500 }, "Use at most 30 detail lines of 500 characters each.")
        try require(actions.count <= 3, "Use at most three actions.")
        for action in actions {
            let url = URL(string: action.url)
            try require(!action.title.isEmpty && action.title.count <= 40 && action.url.count <= 2048 &&
                        ["http", "https"].contains(url?.scheme?.lowercased() ?? "") && url?.host != nil && url?.user == nil && url?.password == nil,
                        "Actions require a short title and an http(s) URL without credentials.")
        }
    }
}
public enum ActivityError: Error, LocalizedError {
    case invalid(String)
    public var errorDescription: String? { switch self { case .invalid(let message): return message } }
}
public struct SourcePreference: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var enabled: Bool
    public var canInterrupt: Bool
    public var allowCustomInterface: Bool?
    public init(id: String, name: String, enabled: Bool = true, canInterrupt: Bool = false, allowCustomInterface: Bool = false) {
        self.id = id; self.name = name; self.enabled = enabled; self.canInterrupt = canInterrupt; self.allowCustomInterface = allowCustomInterface
    }
}
public struct SlotPreference: Codable, Equatable, Sendable {
    public var sourceID: String?
    public var enabled: Bool
    public var allowInterruptions: Bool
    public init(sourceID: String? = nil, enabled: Bool = true, allowInterruptions: Bool = true) {
        self.sourceID = sourceID; self.enabled = enabled; self.allowInterruptions = allowInterruptions
    }
}
public struct ActivityEntry: Equatable, Sendable {
    public var activity: NotchActivity
    public var expiresAt: Date
    public var sequence: UInt64
    public var updateSequence: UInt64
    public init(activity: NotchActivity, expiresAt: Date, sequence: UInt64, updateSequence: UInt64? = nil) {
        self.activity = activity; self.expiresAt = expiresAt; self.sequence = sequence; self.updateSequence = updateSequence ?? sequence
    }
}
public enum SlotResolver {
    /// Priority ordering is stable. Updating an activity doesn't steal an equal-priority slot.
    public static func resolve(entries: [ActivityEntry], sources: [SourcePreference], slots: [SlotPreference],
                               side: NotchSide, now: Date = Date()) -> [NotchActivity?] {
        let preferences = Dictionary(sources.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let available = entries.filter { $0.expiresAt > now && preferences[$0.activity.sourceID]?.enabled == true }
        var used = Set<String>()
        func key(_ entry: ActivityEntry) -> String { entry.activity.sourceID + "\u{0}" + entry.activity.id }
        func priority(_ entry: ActivityEntry) -> Int {
            preferences[entry.activity.sourceID]?.canInterrupt == true ? entry.activity.priority.rank : 0
        }
        return slots.map { slot in
            guard slot.enabled else { return nil }
            let eligible = available.filter { !used.contains(key($0)) }
            let normal = eligible.filter { slot.sourceID == nil ? $0.activity.preferredSide == side : $0.activity.sourceID == slot.sourceID }
            let baseline = normal.sorted { $0.sequence < $1.sequence }.first
            let interruption = slot.allowInterruptions ? eligible.filter {
                priority($0) > 0 && ($0.activity.preferredSide == side || $0.activity.sourceID == slot.sourceID)
            }.sorted {
                priority($0) == priority($1) ? $0.sequence < $1.sequence : priority($0) > priority($1)
            }.first : nil
            let selected = interruption ?? baseline
            if let selected { used.insert(key(selected)); return selected.activity }
            return nil
        }
    }
}
