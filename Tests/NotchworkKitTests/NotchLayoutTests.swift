import XCTest
import NotchworkKit
@testable import NotchworkHost

final class NotchLayoutTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 100)
    func entry(_ source: String, priority: ActivityPriority = .low, sequence: UInt64 = 1,
               side: NotchSide = .left, expires: Double = 200) -> ActivityEntry {
        .init(activity: .init(id: "status", sourceID: source, sourceName: source, title: source,
                              priority: priority, preferredSide: side),
              expiresAt: Date(timeIntervalSince1970: expires), sequence: sequence)
    }
    func resolve(_ entries: [ActivityEntry], mode: NotchLayoutMode = .multiple,
                 single: String? = nil, left: String? = nil, right: String? = nil,
                 disabled: String? = nil) -> [NotchActivity?] {
        let sources = Set(entries.map { $0.activity.sourceID }).map { SourcePreference(id: $0, name: $0, enabled: $0 != disabled) }
        return NotchLayoutResolver.resolve(entries: entries, sources: sources, mode: mode,
                                          singleSourceID: single, leftSourceID: left, rightSourceID: right, now: now)
    }
    func testSingleAppOwnsContainerDespiteOtherUrgentApp() {
        let cards = [entry("music"), entry("portkeeper", priority: .high, sequence: 2)]
        XCTAssertEqual(resolve(cards, mode: .single, single: "music").compactMap { $0?.sourceID }, ["music"])
        XCTAssertNil(resolve(cards, mode: .single, single: "offline")[0])
    }
    func testDualAssignmentsIgnorePreferredSideAndPriority() {
        let cards = [entry("music"), entry("portkeeper", priority: .high), entry("build", priority: .high, sequence: 3)]
        XCTAssertEqual(resolve(cards, mode: .dual, left: "portkeeper", right: "music").compactMap { $0?.sourceID }, ["portkeeper", "music"])
        XCTAssertNil(resolve(cards, mode: .dual, left: "music", right: "music")[1])
        XCTAssertEqual(resolve(cards, mode: .dual, right: "music").compactMap { $0?.sourceID }, ["portkeeper", "music"])
    }
    func testMultipleRanksAcrossSidesAndUsesNewestTie() {
        let cards = [entry("music", priority: .low, sequence: 9), entry("build", priority: .high, sequence: 2),
                     entry("portkeeper", priority: .high, sequence: 3), entry("sync", priority: .mid, sequence: 8)]
        XCTAssertEqual(resolve(cards).compactMap { $0?.sourceID }, ["portkeeper", "build"])
        XCTAssertEqual(resolve(cards, disabled: "portkeeper").compactMap { $0?.sourceID }, ["build", "sync"])
    }
    func testExpiryRestoresNextAppAndSourceCannotOccupyBothPositions() {
        var duplicate = entry("build", priority: .mid, sequence: 4)
        duplicate.activity.id = "other"
        let cards = [entry("expired", priority: .high, expires: 99), entry("build", priority: .high), duplicate, entry("music")]
        XCTAssertEqual(resolve(cards).compactMap { $0?.sourceID }, ["build", "music"])
        XCTAssertEqual(resolve([]).count, 2)
        XCTAssertTrue(resolve([]).allSatisfy { $0 == nil })
    }
    func testNewPriorityNamesAndLegacyEncoding() throws {
        for (name, priority) in [("low", ActivityPriority.low), ("mid", .mid), ("high", .high),
                                 ("normal", .low), ("important", .mid), ("urgent", .high)] {
            XCTAssertEqual(try JSONDecoder().decode(ActivityPriority.self, from: Data("\"\(name)\"".utf8)), priority)
            XCTAssertEqual(try JSONDecoder().decode(ActivityPriority.self, from: JSONEncoder().encode(priority)), priority)
        }
        XCTAssertThrowsError(try JSONDecoder().decode(ActivityPriority.self, from: Data("\"critical\"".utf8)))
    }
    @MainActor func testMeaningfulUpdatesMoveAheadButHeartbeatsDoNot() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ActivityStore(directory: directory)
        defer { store.stop(); try? FileManager.default.removeItem(at: directory) }
        store.preferences.mode = .multiple
        var first = entry("first").activity
        let second = entry("second").activity
        _ = store.apply(.init(operation: "publish", activity: first))
        _ = store.apply(.init(operation: "publish", activity: second))
        XCTAssertEqual(store.visibleActivities[0]?.sourceID, "second")
        first.ttl = 120
        _ = store.apply(.init(operation: "publish", activity: first))
        XCTAssertEqual(store.visibleActivities[0]?.sourceID, "second")
        first.title = "Changed"
        _ = store.apply(.init(operation: "publish", activity: first))
        XCTAssertEqual(store.visibleActivities[0]?.sourceID, "first")
        var update = second
        update.notificationID = "event-2"
        _ = store.apply(.init(operation: "publish", activity: update))
        XCTAssertEqual(store.visibleActivities[0]?.sourceID, "second")
        let sequence = store.entries[1].updateSequence
        _ = store.apply(.init(operation: "publish", activity: update))
        XCTAssertEqual(store.entries[1].updateSequence, sequence)
        store.dismiss(update)
        XCTAssertEqual(store.visibleActivities[0]?.sourceID, "first")
    }
    @MainActor func testLegacyPreferencesMigrateAndNewModesPersist() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacy = #"{"left":[{"sourceID":"music","enabled":true,"allowInterruptions":true}],"right":[],"sources":[{"id":"music","name":"Music","enabled":true,"canInterrupt":true}],"hoverToOpen":false}"#
        try Data(legacy.utf8).write(to: directory.appendingPathComponent("preferences.json"))
        let store = ActivityStore(directory: directory)
        defer { store.stop() }
        XCTAssertEqual(store.preferences.mode, .dual)
        XCTAssertEqual(store.preferences.left[0].sourceID, "music")
        XCTAssertEqual(store.preferences.right.count, 3)
        XCTAssertFalse(store.preferences.hoverToOpen)
        store.preferences.mode = .single; store.preferences.singleSourceID = "music"; store.save()
        let restored = ActivityStore(directory: directory)
        defer { restored.stop() }
        XCTAssertEqual(restored.preferences.mode, .single)
        XCTAssertEqual(restored.preferences.singleSourceID, "music")
        XCTAssertEqual(restored.preferences.sources.count, 1)
    }
}
