import XCTest
import NotchworkKit
@testable import NotchworkHost

final class IntegrationTests: XCTestCase {
    func card() -> NotchActivity { NotchActivity(id: "services", sourceID: "app.portkeeper", sourceName: "Portkeeper", title: "2 running") }
    func testSnapshotRejectsStaleFutureWrongSourceAndInvalidData() throws {
        let now = Date()
        let fresh = ActivitySnapshot(activity: card(), now: now.addingTimeInterval(-20))
        XCTAssertEqual(try fresh.freshActivity(sourceID: "app.portkeeper", id: "services", now: now).ttl, 40, accuracy: 0.1)
        for age in [-10.0, 59, 1000] {
            let value = ActivitySnapshot(activity: card(), now: now.addingTimeInterval(-age))
            XCTAssertThrowsError(try value.freshActivity(sourceID: "app.portkeeper", id: "services", now: now))
        }
        XCTAssertThrowsError(try fresh.freshActivity(sourceID: "other.app", id: "services", now: now))
        var invalid = fresh; invalid.activity.title = ""
        XCTAssertThrowsError(try invalid.freshActivity(sourceID: "app.portkeeper", id: "services", now: now))
        invalid = fresh; invalid.version = 99
        XCTAssertThrowsError(try invalid.freshActivity(sourceID: "app.portkeeper", id: "services", now: now))
    }
    func testSnapshotReaderRejectsSymlinkAndOversizedFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("snapshot.json")
        try JSONEncoder().encode(ActivitySnapshot(activity: card())).write(to: file)
        XCTAssertEqual(try Integrations.read(file).title, "2 running")
        let link = directory.appendingPathComponent("link.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertThrowsError(try Integrations.read(link))
        try Data(repeating: 32, count: 65_537).write(to: file)
        XCTAssertThrowsError(try Integrations.read(file))
    }
    @MainActor func testFileWatcherReceivesChangesAndDisconnectRemovesCard() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("Portkeeper/notchwork.json")
        let store = ActivityStore(directory: directory)
        let integrations = Integrations(store: store, snapshotFile: file, restore: false)
        defer { integrations.stop(); store.stop() }
        integrations.setPortkeeper(true)
        try JSONEncoder().encode(ActivitySnapshot(activity: card())).write(to: file, options: .atomic)
        for _ in 0..<30 where store.entries.isEmpty { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertEqual(store.entries.first?.activity.title, "2 running")
        var failed = card(); failed.title = "1 needs attention"; failed.priority = .urgent
        try JSONEncoder().encode(ActivitySnapshot(activity: failed)).write(to: file, options: .atomic)
        for _ in 0..<30 where store.entries.first?.activity.title != failed.title { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertEqual(store.entries.first?.activity.priority, .urgent)
        try FileManager.default.removeItem(at: file)
        for _ in 0..<30 where !store.entries.isEmpty { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertTrue(store.entries.isEmpty)
        integrations.setPortkeeper(false)
        try JSONEncoder().encode(ActivitySnapshot(activity: card())).write(to: file, options: .atomic)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(store.entries.isEmpty)
    }
    func testMusicPlayersHaveIndependentSourcesAndBoundedMetadata() throws {
        let reading = MusicReading(title: String(repeating: "a", count: 500), artist: "Artist", album: "Album", playing: false)
        let apple = reading.activity(for: .appleMusic), spotify = reading.activity(for: .spotify)
        XCTAssertNotEqual(apple.sourceID, spotify.sourceID)
        XCTAssertEqual(spotify.sourceName, "Spotify")
        XCTAssertTrue(apple.subtitle.hasPrefix("Paused"))
        XCTAssertEqual(apple.title.count, 120)
        try apple.validate(); try spotify.validate()
    }
}
