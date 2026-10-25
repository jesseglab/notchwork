import Foundation
import ImageIO

/// An app-designed, offline HTML panel. The host routes named UI events back to the app.
public struct ActivityInterface: Codable, Equatable, Sendable {
    public var html: String
    public var height: Double
    public var actions: [String]
    public var width: Double?
    public var stateJSON: String?
    /// Legacy hint, ignored by hosts with user-controlled-pinning. Only the user can pin the container.
    public var keepOpen: Bool?
    public init(html: String, height: Double = 300, actions: [String] = [], width: Double? = nil, stateJSON: String? = nil, keepOpen: Bool? = nil) {
        self.html = html; self.height = height; self.actions = actions; self.width = width; self.stateJSON = stateJSON; self.keepOpen = keepOpen
    }
    public func validate() throws {
        if let width, !width.isFinite || !(240...1000).contains(width) {
            throw ActivityError.invalid("Custom interface width must be 240–1000 points.")
        }
        if let stateJSON {
            guard stateJSON.utf8.count <= 2_097_152,
                  let data = stateJSON.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil else {
                throw ActivityError.invalid("Interface state must be valid JSON up to 2 MiB.")
            }
        }
        guard html.utf8.count <= 65_536, height.isFinite, (80...800).contains(height), actions.count <= 20,
              Set(actions).count == actions.count,
              actions.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 64 && $0.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || [45,46,95].contains($0) } }) else {
            throw ActivityError.invalid("Custom interfaces require HTML up to 64 KiB, height 80–800, and up to 20 unique action names.")
        }
    }
}

public struct ActivityEvent: Codable, Equatable, Sendable {
    public var sequence: UInt64
    public var sourceID: String
    public var activityID: String
    public var action: String
    public var value: String
    public var createdAt: Double
    public init(sequence: UInt64, sourceID: String, activityID: String, action: String, value: String, createdAt: Double = Date().timeIntervalSince1970) {
        self.sequence = sequence; self.sourceID = sourceID; self.activityID = activityID
        self.action = action; self.value = value; self.createdAt = createdAt
    }
}

public enum ActivityIcon {
    public static func validate(_ base64: String) throws {
        guard base64.utf8.count <= 16_384, let data = Data(base64Encoded: base64),
              data.starts(with: [137,80,78,71,13,10,26,10]),
              let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              (1...128).contains(width), (1...128).contains(height) else {
            throw ActivityError.invalid("Custom icons must be a single PNG up to 128 × 128 and 16 KiB of base64.")
        }
    }
}
