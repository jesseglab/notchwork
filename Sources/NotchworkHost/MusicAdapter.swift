import AppKit
import ScriptingBridge
import ApplicationServices
import NotchworkKit

// Both players expose these selectors and state codes in their installed scripting dictionaries.
@objc private protocol MusicApplication {
    @objc optional var playerState: UInt32 { get }
    @objc optional var currentTrack: SBObject { get }
}
@objc private protocol MusicTrack {
    @objc optional var name: String { get }
    @objc optional var artist: String { get }
    @objc optional var album: String { get }
}
extension SBApplication: MusicApplication {}
extension SBObject: MusicTrack {}

private final class MusicReadError: NSObject, SBApplicationDelegate {
    var error: Error?
    func eventDidFail(_ event: UnsafePointer<AppleEvent>, withError error: Error) -> Any? { self.error = error; return nil }
}

enum MusicPlayer: Sendable {
    case appleMusic, spotify
    var name: String { self == .appleMusic ? "Apple Music" : "Spotify" }
    var bundleID: String { self == .appleMusic ? "com.apple.Music" : "com.spotify.client" }
    var sourceID: String { self == .appleMusic ? "app.notchwork.music" : "app.notchwork.spotify" }
}

struct MusicReading: Sendable {
    var title: String
    var artist: String
    var album: String
    var playing: Bool
    func activity(for player: MusicPlayer) -> NotchActivity {
        NotchActivity(id: "playing", sourceID: player.sourceID, sourceName: player.name,
            title: String(title.prefix(120)), subtitle: String((playing ? artist : "Paused · \(artist)").prefix(240)),
            symbol: playing ? "music.note" : "pause.fill", preferredSide: .left,
            details: album.isEmpty ? [] : [String(album.prefix(500))], ttl: 30)
    }
}

@MainActor final class MusicAdapter {
    typealias Delivery = (NotchActivity?, String) -> Void
    private let player: MusicPlayer
    private let deliver: Delivery
    private var enabled = false
    private var canAsk = false
    private var generation = UUID()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var inFlight = false
    private let queue = DispatchQueue(label: "Notchwork.Music", qos: .utility)
    init(player: MusicPlayer, deliver: @escaping Delivery) { self.player = player; self.deliver = deliver }
    func setEnabled(_ value: Bool, requestPermission: Bool) {
        stop(); enabled = value; canAsk = requestPermission
        guard value else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, app.bundleIdentifier == self?.player.bundleID else { return }
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
        refresh()
    }
    private func refresh() {
        timer?.invalidate(); timer = nil
        guard enabled else { return }
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: player.bundleID).isEmpty else {
            deliver(nil, "Open \(player.name) to connect. Notchwork won’t launch it for you."); return
        }
        guard !inFlight else { schedule(); return }
        inFlight = true
        let token = generation, ask = canAsk, player = player
        canAsk = false
        queue.async { [weak self] in
            let result = Result { try Self.read(player: player, requestPermission: ask) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.inFlight = false
                guard self.enabled else { return }
                guard self.generation == token else { self.refresh(); return }
                switch result {
                case .success(let reading):
                    self.deliver(reading?.activity(for: player), reading == nil ? "\(player.name) is stopped." : "Connected · " + (reading!.playing ? "playing" : "paused"))
                    self.schedule()
                case .failure(let error):
                    self.deliver(nil, error.localizedDescription)
                    // Permission failures require an explicit reconnect, not repeated prompts.
                }
            }
        }
    }
    private func schedule() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer?.tolerance = 1
    }
    nonisolated private static func read(player: MusicPlayer, requestPermission: Bool) throws -> MusicReading? {
        let target = NSAppleEventDescriptor(bundleIdentifier: player.bundleID)
        let permission = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, requestPermission)
        guard permission == noErr else {
            throw ActivityError.invalid("Allow Notchwork → \(player.name) in System Settings → Privacy & Security → Automation, then reconnect. (\(permission))")
        }
        guard let app = SBApplication(bundleIdentifier: player.bundleID), app.isRunning else { return nil }
        app.timeout = 120 // Apple event ticks: two seconds; all requests stay off the UI thread.
        let errors = MusicReadError(); app.delegate = errors
        let state = (app as MusicApplication).playerState
        if let error = errors.error { throw error }
        guard let state, [0x6b505350, 0x6b505370, 0x6b505353, 0x6b505346, 0x6b505352].contains(state) else {
            throw ActivityError.invalid("Could not read \(player.name) playback state. Reconnect to try again.")
        }
        guard state == 0x6b505350 || state == 0x6b505370 else { return nil } // kPSP / kPSp
        guard let track = (app as MusicApplication).currentTrack else { return nil }
        let item = track as MusicTrack
        let result = MusicReading(title: item.name ?? "", artist: item.artist ?? "", album: item.album ?? "", playing: state == 0x6b505350)
        if let error = errors.error { throw error }
        return result.title.isEmpty ? nil : result
    }
    func stop() {
        enabled = false; generation = UUID(); timer?.invalidate(); timer = nil
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }; observers.removeAll()
    }
}
