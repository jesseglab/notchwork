import AppKit
import Combine
import NotchworkKit

struct DrawerPreference: Codable, Equatable {
    var enabled = true
    var sourceID: String?
}
struct LayoutPreferences: Codable {
    var left = [SlotPreference(), SlotPreference(enabled: false), SlotPreference(enabled: false)]
    var right = [SlotPreference(), SlotPreference(enabled: false), SlotPreference(enabled: false)]
    var leftDrawer = DrawerPreference()
    var rightDrawer = DrawerPreference()
    var sources: [SourcePreference] = []
    var hoverToOpen = true
}
@MainActor final class ActivityStore: ObservableObject {
    @Published var preferences: LayoutPreferences
    @Published private(set) var revision = 0
    @Published var connectionStatus = "Starting local connection…"
    private(set) var entries: [ActivityEntry] = []
    private var sequence: UInt64 = 0
    private var eventSequence: UInt64 = 0
    private var events: [ActivityEvent] = []
    private var eventWaiters: [UUID: (HostCommand, CheckedContinuation<HostResponse, Never>)] = [:]
    private var expiryTimer: Timer?
    private var publication: DispatchWorkItem?
    let directory: URL
    let preferencesURL: URL
    var onLayoutChanged: (() -> Void)?
    init(directory: URL) {
        self.directory = directory
        preferencesURL = directory.appendingPathComponent("preferences.json")
        preferences = (try? JSONDecoder().decode(LayoutPreferences.self, from: Data(contentsOf: preferencesURL))) ?? LayoutPreferences()
        preferences.left = Array((preferences.left + Array(repeating: SlotPreference(enabled: false), count: 3)).prefix(3))
        preferences.right = Array((preferences.right + Array(repeating: SlotPreference(enabled: false), count: 3)).prefix(3))
    }
    func apply(_ command: HostCommand) -> HostResponse {
        do {
            switch command.operation {
            case "publish":
                guard let card = command.activity else { throw ActivityError.invalid("Missing activity.") }
                try card.validate()
                let index = entries.firstIndex { $0.activity.sourceID == card.sourceID && $0.activity.id == card.id }
                guard index != nil || entries.count < 128 else { throw ActivityError.invalid("The host supports at most 128 live activities.") }
                if !preferences.sources.contains(where: { $0.id == card.sourceID }) {
                    guard preferences.sources.count < 32 else { throw ActivityError.invalid("The host supports at most 32 registered apps.") }
                    preferences.sources.append(SourcePreference(id: card.sourceID, name: card.sourceName))
                    save()
                }
                if let index {
                    entries[index].activity = card
                    entries[index].expiresAt = Date().addingTimeInterval(card.ttl)
                } else {
                    sequence += 1
                    entries.append(ActivityEntry(activity: card, expiresAt: Date().addingTimeInterval(card.ttl), sequence: sequence))
                }
            case "remove":
                guard let source = command.sourceID, let id = command.id else { throw ActivityError.invalid("Missing sourceID or id.") }
                entries.removeAll { $0.activity.sourceID == source && $0.activity.id == id }
            case "events":
                guard let source = command.sourceID, preferences.sources.contains(where: { $0.id == source }) else {
                    throw ActivityError.invalid("Unknown source.")
                }
                events.removeAll { Date().timeIntervalSince1970 - $0.createdAt > 30 || ($0.sourceID == source && $0.sequence <= (command.after ?? 0)) }
                return HostResponse(ok: true, message: "UI events.", events: events.filter { $0.sourceID == source && $0.sequence > (command.after ?? 0) })
            case "ping": return HostResponse(ok: true, message: "Notchwork is ready.")
            default: throw ActivityError.invalid("Unknown operation.")
            }
            scheduleExpiry(); publishSoon()
            return HostResponse(ok: true, message: "Activity accepted.")
        } catch { return HostResponse(ok: false, message: error.localizedDescription) }
    }
    func respond(_ command: HostCommand) async -> HostResponse {
        let response = apply(command)
        guard command.operation == "events", command.wait == true, response.ok, response.events?.isEmpty == true else { return response }
        return await withCheckedContinuation { continuation in
            let id = UUID()
            eventWaiters[id] = (command, continuation)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.finishWaiter(id) }
        }
    }
    private func finishWaiter(_ id: UUID) {
        guard let (command, continuation) = eventWaiters.removeValue(forKey: id) else { return }
        continuation.resume(returning: apply(command))
    }
    func permitsInterface(_ card: NotchActivity) -> Bool {
        preferences.sources.contains { $0.id == card.sourceID && $0.enabled && $0.allowCustomInterface == true }
    }
    @discardableResult func invoke(sourceID: String, activityID: String, action: String, value: String) -> Bool {
        guard value.utf8.count <= 4096,
              let card = entries.first(where: { $0.activity.sourceID == sourceID && $0.activity.id == activityID && $0.expiresAt > Date() })?.activity,
              permitsInterface(card), card.interface?.actions.contains(action) == true else { return false }
        events.removeAll { Date().timeIntervalSince1970 - $0.createdAt > 30 }
        guard events.filter({ $0.sourceID == sourceID }).count < 64, events.count < 256 else { return false }
        eventSequence += 1
        events.append(ActivityEvent(sequence: eventSequence, sourceID: sourceID, activityID: activityID, action: action, value: value))
        for id in eventWaiters.keys.filter({ eventWaiters[$0]?.0.sourceID == sourceID }) { finishWaiter(id) }
        return true
    }
    func save() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(preferences).write(to: preferencesURL, options: .atomic)
        } catch { connectionStatus = "Could not save layout: " + error.localizedDescription }
        revision += 1; onLayoutChanged?()
    }
    private func publishSoon() {
        guard publication == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.publication = nil; self.revision += 1; self.onLayoutChanged?()
        }
        publication = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }
    private func scheduleExpiry() {
        expiryTimer?.invalidate(); expiryTimer = nil
        guard let date = entries.map(\.expiresAt).min() else { return }
        expiryTimer = Timer.scheduledTimer(withTimeInterval: max(0.01, date.timeIntervalSinceNow), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.entries.removeAll { $0.expiresAt <= Date() }
                self.scheduleExpiry(); self.publishSoon()
            }
        }
    }
    func slots(_ side: NotchSide) -> [NotchActivity?] {
        let slots = (side == .left ? preferences.left : preferences.right).filter(\.enabled)
        return SlotResolver.resolve(entries: entries, sources: preferences.sources, slots: slots, side: side)
    }
    func cards(_ side: NotchSide, drawer: Bool = false) -> [NotchActivity] {
        let preference = side == .left ? preferences.leftDrawer : preferences.rightDrawer
        return entries.filter { entry in
            entry.expiresAt > Date() && preferences.sources.contains { $0.id == entry.activity.sourceID && $0.enabled } &&
            (!drawer || preference.sourceID.map { $0 == entry.activity.sourceID } ?? (entry.activity.preferredSide == side))
        }.sorted { a, b in
            a.activity.priority.rank == b.activity.priority.rank ? a.sequence < b.sequence : a.activity.priority.rank > b.activity.priority.rank
        }.map(\.activity)
    }
    func dismiss(_ card: NotchActivity) { _ = apply(HostCommand(operation: "remove", sourceID: card.sourceID, id: card.id)) }
    func loadExamples() {
        let demoSources = ["demo.music", "demo.build", "demo.portkeeper"]
        for (id, name) in zip(demoSources, ["Music demo", "Build demo", "Portkeeper demo"]) where !preferences.sources.contains(where: { $0.id == id }) {
            preferences.sources.append(SourcePreference(id: id, name: name, canInterrupt: id == "demo.build"))
        }
        save()
        for card in [
            NotchActivity(id: "playing", sourceID: "demo.music", sourceName: "Music demo", title: "Night drive", subtitle: "A sample now-playing activity", symbol: "music.note", preferredSide: .left, details: ["Your own app or adapter supplies live information.", "This is an example; it is not connected to a music player."], ttl: 3600),
            NotchActivity(id: "services", sourceID: "demo.portkeeper", sourceName: "Portkeeper demo", title: "3 services", subtitle: "All systems running", symbol: "terminal", preferredSide: .right, details: ["API · localhost:4100", "Web · localhost:3000", "Worker · ready", "Sample data; the host does not manage these processes."], ttl: 3600)
        ] { _ = apply(HostCommand(operation: "publish", activity: card)) }
    }
    func showPriorityExample() {
        if !preferences.sources.contains(where: { $0.id == "demo.build" }) { loadExamples() }
        _ = apply(HostCommand(operation: "publish", activity: NotchActivity(id: "result", sourceID: "demo.build", sourceName: "Build demo", title: "Build needs you", subtitle: "Priority demo · clears in 15 seconds", symbol: "exclamationmark.triangle.fill", priority: .urgent, preferredSide: .left, details: ["A permitted urgent activity temporarily occupies the left slot.", "Dismiss it or wait 15 seconds to restore the previous activity."], ttl: 15)))
    }
    func stop() {
        expiryTimer?.invalidate(); publication?.cancel()
        let pending = eventWaiters.values; eventWaiters.removeAll()
        for (_, continuation) in pending { continuation.resume(returning: HostResponse(ok: false, message: "Host stopped.")) }
    }
}
