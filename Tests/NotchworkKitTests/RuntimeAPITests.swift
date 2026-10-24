import XCTest
import NotchworkKit
@testable import NotchworkHost

final class RuntimeAPITests: XCTestCase {
    @MainActor func testRegistrationAndExplicitPresentation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ActivityStore(directory: directory)
        defer { store.stop(); try? FileManager.default.removeItem(at: directory) }
        XCTAssertEqual(store.apply(.init(operation: "ping")).apiVersion, 2)
        let source = SourceRegistration(id: "app.test", name: "Test", customInterface: true)
        XCTAssertTrue(store.apply(.init(operation: "register", registration: source)).ok)
        XCTAssertTrue(store.preferences.sources[0].allowCustomInterface == true)
        let card = NotchActivity(id: "status", sourceID: source.id, sourceName: source.name, title: "Ready", priority: .high)
        var openings = 0
        store.onPresent = { openings += 1 }
        XCTAssertFalse(store.apply(.init(operation: "present", sourceID: source.id, id: card.id)).ok)
        XCTAssertTrue(store.apply(.init(operation: "publish", activity: card)).ok)
        XCTAssertEqual(openings, 0, "A notification cannot open the container")
        store.preferences.singleSourceID = "another.app"
        XCTAssertNil(store.visibleActivities[0])
        XCTAssertTrue(store.apply(.init(operation: "present", sourceID: source.id, id: card.id)).ok)
        XCTAssertEqual(openings, 1)
        XCTAssertEqual(store.presentationActivities[0]?.sourceID, source.id)
        XCTAssertNil(store.visibleActivities[0], "Explicit presentation does not rewrite fixed assignments")
        store.endPresentation()
        XCTAssertNil(store.presentationActivities[0])
        store.preferences.sources[0].enabled = false
        XCTAssertFalse(store.apply(.init(operation: "present", sourceID: source.id, id: card.id)).ok)
    }
    @MainActor func testReconnectPreservesUserPermissionsAndRejectsInvalidRegistration() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ActivityStore(directory: directory)
        defer { store.stop(); try? FileManager.default.removeItem(at: directory) }
        XCTAssertFalse(store.apply(.init(operation: "register", registration: .init(id: "../invalid", name: "Invalid"))).ok)
        XCTAssertFalse(store.apply(.init(operation: "register")).ok)
        let registration = SourceRegistration(id: "app.test", name: "Test", customInterface: true)
        _ = store.apply(.init(operation: "register", registration: registration))
        store.preferences.sources[0].enabled = false
        store.preferences.sources[0].allowCustomInterface = false
        _ = store.apply(.init(operation: "register", registration: registration))
        XCTAssertEqual(store.preferences.sources.count, 1)
        XCTAssertFalse(store.preferences.sources[0].enabled)
        XCTAssertFalse(store.preferences.sources[0].allowCustomInterface == true)
    }
}
