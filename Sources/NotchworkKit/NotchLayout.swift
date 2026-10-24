import Foundation

public enum NotchLayoutMode: String, Codable, CaseIterable, Sendable {
    case single, dual, multiple
}

/// Resolves one app per position. Multiple mode ranks across both preferred sides.
public enum NotchLayoutResolver {
    public static func resolve(entries: [ActivityEntry], sources: [SourcePreference], mode: NotchLayoutMode,
                               singleSourceID: String? = nil, leftSourceID: String? = nil,
                               rightSourceID: String? = nil, now: Date = Date()) -> [NotchActivity?] {
        let enabled = Set(sources.filter(\.enabled).map(\.id))
        let live = entries.filter { $0.expiresAt > now && enabled.contains($0.activity.sourceID) }
        func newest(_ entries: [ActivityEntry]) -> NotchActivity? {
            entries.sorted { $0.updateSequence > $1.updateSequence }.first?.activity
        }
        switch mode {
        case .single:
            let source = singleSourceID ?? live.min(by: { $0.sequence < $1.sequence })?.activity.sourceID
            return [newest(live.filter { $0.activity.sourceID == source })]
        case .dual:
            var used = Set<String>()
            return [(NotchSide.left, leftSourceID), (.right, rightSourceID)].map { side, source in
                let otherSource = side == .left ? rightSourceID : leftSourceID
                let candidates = live.filter {
                    !used.contains($0.activity.sourceID) &&
                    (source != nil || $0.activity.sourceID != otherSource) &&
                    (source == nil ? $0.activity.preferredSide == side : $0.activity.sourceID == source)
                }
                let selectedSource = source ?? candidates.min(by: { $0.sequence < $1.sequence })?.activity.sourceID
                let card = newest(candidates.filter { $0.activity.sourceID == selectedSource })
                if let card { used.insert(card.sourceID) }
                return card
            }
        case .multiple:
            let ranked = live.sorted {
                if $0.activity.priority.rank != $1.activity.priority.rank { return $0.activity.priority.rank > $1.activity.priority.rank }
                if $0.updateSequence != $1.updateSequence { return $0.updateSequence > $1.updateSequence }
                return ($0.activity.sourceID, $0.activity.id) < ($1.activity.sourceID, $1.activity.id)
            }
            var used = Set<String>()
            let selected = ranked.filter { used.insert($0.activity.sourceID).inserted }.prefix(2).map { Optional($0.activity) }
            return selected + Array(repeating: nil, count: 2 - selected.count)
        }
    }
}
