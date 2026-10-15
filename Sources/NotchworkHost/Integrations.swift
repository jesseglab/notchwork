import AppKit
import Combine
import Darwin
import NotchworkKit

@MainActor final class Integrations: ObservableObject {
    @Published private(set) var portkeeperEnabled = false
    @Published private(set) var spotifyEnabled = false
    @Published private(set) var spotifyStatus = "Shows the current track after you allow Spotify access."
    @Published private(set) var musicEnabled = false
    @Published private(set) var portkeeperStatus = "Enable status sharing in Portkeeper, then connect here."
    @Published private(set) var musicStatus = "Shows the current track after you allow Music access."
    private let store: ActivityStore
    private let settingsFile: URL
    private let snapshotFile: URL
    private var watcher: DispatchSourceFileSystemObject?
    private var expiry: Timer?
    private var generation = UUID()
    private let reading = DispatchQueue(label: "Notchwork.Portkeeper", qos: .utility)
    private var music: MusicAdapter?
    private var spotify: MusicAdapter?

    init(store: ActivityStore, snapshotFile: URL? = nil, restore: Bool = true) {
        self.store = store
        settingsFile = store.directory.appendingPathComponent("integrations.json")
        self.snapshotFile = snapshotFile ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Portkeeper/notchwork.json")
        music = MusicAdapter(player: .appleMusic) { [weak self] card, status in
            guard let self, self.musicEnabled else { return }
            self.musicStatus = status
            if let card { _ = self.store.apply(HostCommand(operation: "publish", activity: card)) }
            else { self.remove("app.notchwork.music", "playing") }
        }
        spotify = MusicAdapter(player: .spotify) { [weak self] card, status in
            guard let self, self.spotifyEnabled else { return }
            self.spotifyStatus = status
            if let card { _ = self.store.apply(HostCommand(operation: "publish", activity: card)) }
            else { self.remove("app.notchwork.spotify", "playing") }
        }
        if restore, let data = try? Data(contentsOf: settingsFile),
           let settings = try? JSONDecoder().decode([String: Bool].self, from: data) {
            setPortkeeper(settings["portkeeper"] ?? false)
            setMusic(settings["music"] ?? false, requestPermission: false)
            setSpotify(settings["spotify"] ?? false, requestPermission: false)
        }
    }
    func setPortkeeper(_ enabled: Bool) {
        portkeeperEnabled = enabled; generation = UUID()
        watcher?.cancel(); watcher = nil; expiry?.invalidate(); expiry = nil
        remove("app.portkeeper", "services")
        if enabled {
            do {
                let directory = snapshotFile.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                let fd = Darwin.open(directory.path, O_EVTONLY | O_NOFOLLOW)
                guard fd >= 0 else { throw ActivityError.invalid("Could not watch the Portkeeper integration folder.") }
                let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
                source.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.readSnapshot() } }
                source.setCancelHandler { Darwin.close(fd) }
                watcher = source; source.resume(); readSnapshot()
            } catch { portkeeperStatus = error.localizedDescription }
        } else { portkeeperStatus = "Disconnected. Service management stays in Portkeeper." }
        save()
    }
    func setMusic(_ enabled: Bool, requestPermission: Bool = true) {
        musicEnabled = enabled
        music?.setEnabled(enabled, requestPermission: requestPermission)
        if !enabled { remove("app.notchwork.music", "playing"); musicStatus = "Disconnected." }
        save()
    }
    func setSpotify(_ enabled: Bool, requestPermission: Bool = true) {
        spotifyEnabled = enabled
        spotify?.setEnabled(enabled, requestPermission: requestPermission)
        if !enabled { remove("app.notchwork.spotify", "playing"); spotifyStatus = "Disconnected." }
        save()
    }
    private func save() {
        do {
            try JSONEncoder().encode(["music": musicEnabled, "spotify": spotifyEnabled, "portkeeper": portkeeperEnabled]).write(to: settingsFile, options: .atomic)
        } catch { store.connectionStatus = "Could not save integrations: " + error.localizedDescription }
    }
    private func remove(_ source: String, _ id: String) { _ = store.apply(HostCommand(operation: "remove", sourceID: source, id: id)) }
    private func readSnapshot() {
        guard portkeeperEnabled else { return }
        let file = snapshotFile, token = generation
        reading.async { [weak self] in
            let result = Result { try Self.read(file) }
            DispatchQueue.main.async {
                guard let self, self.portkeeperEnabled, self.generation == token else { return }
                self.expiry?.invalidate(); self.expiry = nil
                switch result {
                case .success(let card):
                    let response = self.store.apply(HostCommand(operation: "publish", activity: card))
                    self.portkeeperStatus = response.ok ? "Connected · live service status" : response.message
                    self.expiry = Timer.scheduledTimer(withTimeInterval: card.ttl, repeats: false) { [weak self] _ in
                        MainActor.assumeIsolated {
                            self?.remove("app.portkeeper", "services")
                            self?.portkeeperStatus = "Portkeeper stopped sending updates. Waiting to reconnect…"
                        }
                    }
                case .failure:
                    self.remove("app.portkeeper", "services")
                    self.portkeeperStatus = "Waiting for Portkeeper. Enable Share service status in its settings."
                }
            }
        }
    }
    nonisolated static func read(_ file: URL) throws -> NotchActivity {
        let fd = Darwin.open(file.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard fd >= 0 else { throw ActivityError.invalid("Snapshot unavailable.") }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_uid == getuid(), info.st_size <= 65_536 else {
            throw ActivityError.invalid("Invalid snapshot file.")
        }
        let data = try handle.read(upToCount: 65_537) ?? Data()
        guard data.count <= 65_536 else { throw ActivityError.invalid("Snapshot too large.") }
        let snapshot = try JSONDecoder().decode(ActivitySnapshot.self, from: data)
        return try snapshot.freshActivity(sourceID: "app.portkeeper", id: "services")
    }
    func stop() {
        generation = UUID(); watcher?.cancel(); watcher = nil; expiry?.invalidate(); expiry = nil
        music?.stop(); spotify?.stop()
    }
}
