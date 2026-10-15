import XCTest
import AppKit
import SwiftUI
import NotchworkKit
@testable import NotchworkHost

final class HostTests: XCTestCase {
    @MainActor func testUpdateKeepsIdentityAndRefreshesExpiration() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActivityStore(directory: directory)
        defer { store.stop() }
        var card = NotchActivity(id: "build", sourceID: "test.build", sourceName: "Test", title: "Starting", ttl: 5)
        XCTAssertTrue(store.apply(HostCommand(operation: "publish", activity: card)).ok)
        let sequence = store.entries[0].sequence
        card.title = "Ready"; card.ttl = 60
        XCTAssertTrue(store.apply(HostCommand(operation: "publish", activity: card)).ok)
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries[0].sequence, sequence)
        XCTAssertEqual(store.entries[0].activity.title, "Ready")
        XCTAssertGreaterThan(store.entries[0].expiresAt.timeIntervalSinceNow, 55)
        XCTAssertFalse(store.preferences.sources[0].canInterrupt)
    }
    @MainActor func testPreferencesPersistButLiveDataDoesNot() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = ActivityStore(directory: directory)
        _ = first.apply(HostCommand(operation: "publish", activity: NotchActivity(id: "task", sourceID: "test.app", sourceName: "App", title: "Running")))
        first.preferences.right[0].sourceID = "test.app"
        first.preferences.leftDrawer.enabled = false
        first.save(); first.stop()
        let restored = ActivityStore(directory: directory)
        XCTAssertEqual(restored.preferences.right[0].sourceID, "test.app")
        XCTAssertFalse(restored.preferences.leftDrawer.enabled)
        XCTAssertTrue(restored.entries.isEmpty)
        restored.stop()
    }
    @MainActor func testDrawersUseIndependentAssignmentsAndSourceDisable() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActivityStore(directory: directory)
        defer { store.stop() }
        _ = store.apply(HostCommand(operation: "publish", activity: NotchActivity(id: "a", sourceID: "test.left", sourceName: "Left", title: "Left", preferredSide: .left)))
        _ = store.apply(HostCommand(operation: "publish", activity: NotchActivity(id: "b", sourceID: "test.right", sourceName: "Right", title: "Right", preferredSide: .right)))
        XCTAssertEqual(store.cards(.left, drawer: true).map(\.sourceID), ["test.left"])
        XCTAssertEqual(store.cards(.right, drawer: true).map(\.sourceID), ["test.right"])
        store.preferences.leftDrawer.sourceID = "test.right"
        XCTAssertEqual(store.cards(.left, drawer: true).map(\.sourceID), ["test.right"])
        store.preferences.sources[1].enabled = false
        XCTAssertTrue(store.cards(.left, drawer: true).isEmpty)
        XCTAssertTrue(store.cards(.right, drawer: true).isEmpty)
    }
    @MainActor func testExpirationRestoresUnderlyingActivity() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActivityStore(directory: directory)
        defer { store.stop() }
        _ = store.apply(HostCommand(operation: "publish", activity: NotchActivity(id: "base", sourceID: "test.base", sourceName: "Base", title: "Base", ttl: 60)))
        _ = store.apply(HostCommand(operation: "publish", activity: NotchActivity(id: "alert", sourceID: "test.alert", sourceName: "Alert", title: "Alert", priority: .urgent, ttl: 2)))
        store.preferences.sources[1].canInterrupt = true
        XCTAssertEqual(store.slots(.left)[0]?.id, "alert")
        try? await Task.sleep(nanoseconds: 2_300_000_000)
        XCTAssertEqual(store.slots(.left)[0]?.id, "base")
        XCTAssertEqual(store.entries.count, 1)
    }
    @MainActor func testLeftAndRightNativeSurfaceAnchorsAndCleanup() async {
        _ = NSApplication.shared
        for edge in [LiquidEdge.leftDrawer, .drawer] {
            let panel = NSPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            let surface = LiquidSurfaceView(edge: edge, expanded: Text("Details"), compact: Text("›"))
            panel.contentView = surface
            let screen = NSScreen.main!.visibleFrame
            let left = edge == .leftDrawer
            let compact = CGRect(x: left ? screen.minX : screen.maxX - 26, y: screen.midY - 48, width: 26, height: 96)
            let expanded = CGRect(x: left ? screen.minX : screen.maxX - 380, y: screen.midY - 200, width: 380, height: 400)
            surface.move(compact: compact, expanded: expanded, open: false, animated: false)
            panel.orderFrontRegardless()
            surface.move(compact: compact, expanded: expanded, open: true, animated: true)
            try? await Task.sleep(nanoseconds: 140_000_000)
            XCTAssertGreaterThan(surface.presentedFrame.width, compact.width)
            XCTAssertLessThan(surface.presentedFrame.width, expanded.width)
            XCTAssertEqual(left ? surface.presentedFrame.minX : surface.presentedFrame.maxX, left ? screen.minX : screen.maxX, accuracy: 0.001)
            surface.move(compact: compact, expanded: expanded, open: false, animated: false)
            XCTAssertFalse(surface.isAnimating)
            XCTAssertEqual(surface.subviews.count, 1)
            surface.stopMotion(); panel.orderOut(nil)
        }
    }
}
