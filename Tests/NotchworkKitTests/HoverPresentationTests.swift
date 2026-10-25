import XCTest
import AppKit
import WebKit
import NotchworkKit
@testable import NotchworkHost

final class HoverPresentationTests: XCTestCase {
    @MainActor private func fixture(_ mode: NotchLayoutMode = .dual) -> ActivityStore {
        let store = ActivityStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        store.preferences.mode = mode
        for (id, width) in [("app.left", 400.0), ("app.right", 640.0)] {
            _ = store.apply(.init(operation: "register", registration: .init(id: id, name: id, customInterface: true)))
            _ = store.apply(.init(operation: "publish", activity: NotchActivity(id: "panel", sourceID: id, sourceName: id, title: id,
                interface: ActivityInterface(html: "<h1>\(id)</h1><input id='draft'>", height: 400, width: width, keepOpen: true))))
        }
        store.preferences.left[0].sourceID = "app.left"
        store.preferences.right[0].sourceID = "app.right"
        return store
    }
    @MainActor private func clean(_ store: ActivityStore) {
        store.stop(); try? FileManager.default.removeItem(at: store.directory)
    }
    @MainActor func testSideSelectionAndIdentityAcrossUpdates() {
        for mode in [NotchLayoutMode.dual, .multiple] {
            let store = fixture(mode); defer { clean(store) }
            let left = store.visibleActivities[0]!.sourceID, right = store.visibleActivities[1]!.sourceID
            XCTAssertTrue(store.selectPresentation(side: .left))
            XCTAssertEqual(store.presentationActivities.count, 1)
            XCTAssertEqual(store.presentationActivities[0]?.sourceID, left)
            _ = store.apply(.init(operation: "publish", activity: NotchActivity(id: "panel", sourceID: right, sourceName: right, title: "Updated", priority: .high)))
            XCTAssertEqual(store.presentationActivities[0]?.sourceID, left, "Background ordering changes must not switch an open app")
            store.endPresentation()
            let currentRight = store.visibleActivities[1]!.sourceID
            XCTAssertTrue(store.selectPresentation(side: .right))
            XCTAssertEqual(store.presentationActivities.count, 1)
            XCTAssertEqual(store.presentationActivities[0]?.sourceID, currentRight)
            XCTAssertFalse(store.holdsPresentation, "Client keepOpen is not a user pin")
        }
    }
    @MainActor func testSingleModeAndDisabledOrEmptySides() {
        let store = fixture(.single); defer { clean(store) }
        store.preferences.singleSourceID = "app.left"
        for side in [NotchSide.left, .right] {
            XCTAssertTrue(store.selectPresentation(side: side))
            XCTAssertEqual(store.presentationActivities[0]?.sourceID, "app.left")
        }
        store.preferences.sources[0].enabled = false
        XCTAssertNil(store.presentationActivities[0])
        XCTAssertFalse(store.selectPresentation(side: .left))
        store.preferences.mode = .dual
        XCTAssertFalse(store.selectPresentation(side: .left), "Empty side must not open its neighbour")
        XCTAssertTrue(store.selectPresentation(side: .right))
        store.preferences.sources[1].allowCustomInterface = false
        XCTAssertFalse(store.permitsInterface(store.presentationActivities[0]!))
    }
    @MainActor func testNativeHoverAndAutomaticDismissal() {
        _ = NSApplication.shared
        let store = fixture(); defer { clean(store) }
        let manager = PanelManager(store: store); defer { manager.stop() }
        let compact = manager.compactFrame
        let outside = CGPoint(x: compact.midX, y: compact.minY - 850)
        manager.close(0); manager.pointerMoved(at: outside)
        let left = CGPoint(x: compact.minX + 22, y: compact.midY)
        let right = CGPoint(x: compact.maxX - 22, y: compact.midY)
        XCTAssertEqual(manager.side(at: left), .left); XCTAssertEqual(manager.side(at: right), .right)
        manager.pointerMoved(at: left)
        XCTAssertTrue(manager.opened[0])
        XCTAssertEqual(store.presentationActivities[0]?.sourceID, "app.left")
        manager.pointerMoved(at: right)
        XCTAssertEqual(store.presentationActivities[0]?.sourceID, "app.right")
        XCTAssertEqual(store.presentationActivities.count, 1)
        let now = Date()
        manager.pointerMoved(at: outside, now: now)
        manager.pointerMoved(at: outside, now: now.addingTimeInterval(0.2))
        XCTAssertFalse(manager.opened[0], "keepOpen=true must not trap the notch open")
        manager.pointerMoved(at: outside)
        manager.pointerMoved(at: left)
        store.userPinned = true
        manager.pointerMoved(at: outside, now: now)
        manager.pointerMoved(at: outside, now: now.addingTimeInterval(1))
        XCTAssertTrue(manager.opened[0], "Explicit user pin is respected")
        manager.close(0)
        XCTAssertFalse(store.userPinned)
        XCTAssertFalse(manager.opened[0])
    }
    @MainActor func testSelectedWebInterfaceGetsFullSizeAndFocusedInputDoesNotTrapIt() async throws {
        _ = NSApplication.shared
        let store = fixture(); defer { clean(store) }
        let manager = PanelManager(store: store); defer { manager.stop() }
        manager.openSide(.right)
        store.userPinned = true
        func webViews(_ view: NSView) -> [IsolatedWebView] {
            (view as? IsolatedWebView).map { [$0] } ?? view.subviews.flatMap { webViews($0) }
        }
        let started = Date()
        var selected: IsolatedWebView?
        for _ in 0..<60 {
            let fixtures = NSApp.windows.compactMap(\.contentView).flatMap { webViews($0) }.filter {
                $0.window != nil && ($0.document.contains("<h1>app.left</h1>") || $0.document.contains("<h1>app.right</h1>"))
            }
            if let web = fixtures.first, (try? await web.evaluateJavaScript("document.querySelector('h1')?.textContent")) as? String == "app.right", web.frame.width > 630 {
                XCTAssertEqual(fixtures.count, 1, "Only the selected app is rendered")
                selected = web; break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let web = try XCTUnwrap(selected)
        print("Selected interface ready in \(Date().timeIntervalSince(started)) seconds")
        XCTAssertEqual(web.frame.width, 640, accuracy: 1)
        XCTAssertEqual(web.frame.height, 400, accuracy: 1)
        _ = try await web.evaluateJavaScript("document.getElementById('draft').focus(); true")
        store.userPinned = false
        let outside = CGPoint(x: manager.compactFrame.midX, y: manager.compactFrame.minY - 850)
        let now = Date()
        manager.pointerMoved(at: outside, now: now)
        manager.pointerMoved(at: outside, now: now.addingTimeInterval(0.2))
        XCTAssertFalse(manager.opened[0])
    }

}
