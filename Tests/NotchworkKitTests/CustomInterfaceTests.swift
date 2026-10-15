import XCTest
import AppKit
import WebKit
import NotchworkKit
@testable import NotchworkHost

final class CustomInterfaceTests: XCTestCase {
    func card() -> NotchActivity {
        NotchActivity(id: "panel", sourceID: "test.custom", sourceName: "Custom", title: "Own UI",
            interface: ActivityInterface(html: "<button>Restart</button>", actions: ["restart"]))
    }
    func testCustomInterfaceValidationAndBackwardCompatibility() throws {
        try card().validate()
        var bad = card(); bad.interface!.html = String(repeating: "x", count: 32_769)
        XCTAssertThrowsError(try bad.validate())
        bad = card(); bad.interface!.height = .infinity
        XCTAssertThrowsError(try bad.validate())
        bad = card(); bad.interface!.actions = ["restart", "restart"]
        XCTAssertThrowsError(try bad.validate())
        bad = card(); bad.iconPNG = "PHN2Zz4="
        XCTAssertThrowsError(try bad.validate())
        let oldSource = Data(#"{"id":"test.old","name":"Old","enabled":true,"canInterrupt":false}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(SourcePreference.self, from: oldSource).allowCustomInterface)
        var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(card())) as! [String: Any]
        old.removeValue(forKey: "interface"); old.removeValue(forKey: "iconPNG")
        XCTAssertNil(try JSONDecoder().decode(NotchActivity.self, from: JSONSerialization.data(withJSONObject: old)).interface)
    }
    @MainActor func testCallbacksRequirePermissionLiveActivityAndDeclaredAction() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ActivityStore(directory: directory)
        defer { store.stop(); try? FileManager.default.removeItem(at: directory) }
        _ = store.apply(HostCommand(operation: "publish", activity: card()))
        XCTAssertFalse(store.invoke(sourceID: "test.custom", activityID: "panel", action: "restart", value: "service"))
        store.preferences.sources[0].allowCustomInterface = true
        XCTAssertFalse(store.invoke(sourceID: "test.custom", activityID: "panel", action: "shell", value: "command"))
        XCTAssertFalse(store.invoke(sourceID: "test.custom", activityID: "panel", action: "restart", value: String(repeating: "x", count: 4097)))
        XCTAssertTrue(store.invoke(sourceID: "test.custom", activityID: "panel", action: "restart", value: "service"))
        let response = store.apply(HostCommand(operation: "events", sourceID: "test.custom", after: 0))
        XCTAssertEqual(response.events?.first?.value, "service")
        let cursor = try XCTUnwrap(response.events?.first?.sequence)
        XCTAssertTrue(store.apply(HostCommand(operation: "events", sourceID: "test.custom", after: cursor)).events!.isEmpty)
        XCTAssertTrue(store.apply(HostCommand(operation: "events", sourceID: "test.custom", after: 0)).events!.isEmpty)
        _ = store.apply(HostCommand(operation: "remove", sourceID: "test.custom", id: "panel"))
        XCTAssertFalse(store.invoke(sourceID: "test.custom", activityID: "panel", action: "restart", value: "service"))
    }
    @MainActor func testWaitingClientWakesOnInteractionAndShutdown() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ActivityStore(directory: directory)
        defer { store.stop(); try? FileManager.default.removeItem(at: directory) }
        _ = store.apply(HostCommand(operation: "publish", activity: card()))
        store.preferences.sources[0].allowCustomInterface = true
        let waiting = Task { await store.respond(HostCommand(operation: "events", sourceID: "test.custom", wait: true)) }
        try await Task.sleep(nanoseconds: 50_000_000)
        let started = Date()
        XCTAssertTrue(store.invoke(sourceID: "test.custom", activityID: "panel", action: "restart", value: "service"))
        let response = await waiting.value
        XCTAssertEqual(response.events?.first?.value, "service")
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.5)
        let ending = Task { await store.respond(HostCommand(operation: "events", sourceID: "test.custom", after: response.events!.last!.sequence, wait: true)) }
        try await Task.sleep(nanoseconds: 50_000_000)
        store.stop()
        let stopped = await ending.value
        XCTAssertFalse(stopped.ok)
    }
    @MainActor func testCallbacksCrossLocalAPIWithoutBlockingOtherRequests() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ActivityStore(directory: directory)
        let file = directory.appendingPathComponent("connection.json")
        let server = LocalServer(file: file, handle: { await store.respond($0) }, status: { _ in })
        defer { store.stop(); server.stop(); try? FileManager.default.removeItem(at: directory) }
        try server.start()
        for _ in 0..<50 where !FileManager.default.fileExists(atPath: file.path) { try await Task.sleep(nanoseconds: 50_000_000) }
        let client = NotchworkClient(connection: try .discover(at: file))
        try await client.publish(card())
        store.preferences.sources[0].allowCustomInterface = true
        let waiting = Task { try await client.events(sourceID: "test.custom", wait: true) }
        try await Task.sleep(nanoseconds: 50_000_000)
        let health = try await client.send(HostCommand(operation: "ping"))
        XCTAssertTrue(health.ok)
        XCTAssertTrue(store.invoke(sourceID: "test.custom", activityID: "panel", action: "restart", value: "local-service"))
        let events = try await waiting.value
        XCTAssertEqual(events.first?.value, "local-service")
        XCTAssertEqual(events.first?.sourceID, "test.custom")
        let after = try XCTUnwrap(events.last?.sequence)
        let empty = try await client.events(sourceID: "test.custom", after: after, wait: true)
        XCTAssertTrue(empty.isEmpty)
    }
    @MainActor func testCallbackQueueIsBoundedAndSourceScoped() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ActivityStore(directory: directory)
        defer { store.stop(); try? FileManager.default.removeItem(at: directory) }
        _ = store.apply(HostCommand(operation: "publish", activity: card()))
        store.preferences.sources[0].allowCustomInterface = true
        for _ in 0..<64 { XCTAssertTrue(store.invoke(sourceID: "test.custom", activityID: "panel", action: "restart", value: "")) }
        XCTAssertFalse(store.invoke(sourceID: "test.custom", activityID: "panel", action: "restart", value: ""))
        var other = card(); other.sourceID = "test.other"
        _ = store.apply(HostCommand(operation: "publish", activity: other))
        XCTAssertTrue(store.apply(HostCommand(operation: "events", sourceID: "test.other")).events!.isEmpty)
    }
    @MainActor func testWebKitRendersOwnUIRoutesEventsBlocksNetworkAndClearsWhenHidden() async throws {
        _ = NSApplication.shared
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        var received: [(String, String)] = []
        let coordinator = CustomInterfaceView.Coordinator { action, value in received.append((action, value)); return true }
        configuration.userContentController.add(coordinator, name: "notchwork")
        let web = IsolatedWebView(frame: CGRect(x: 0, y: 0, width: 400, height: 300), configuration: configuration)
        web.navigationDelegate = coordinator
        web.document = CustomInterfaceView.document("""
        <h1 id="title">My own layout</h1><button id="run" onclick="notchwork.invoke('restart','owned-service')">Restart</button>
        <script>document.addEventListener('securitypolicyviolation',e=>notchwork.invoke('policy',e.violatedDirective));window.counter=0;setInterval(()=>window.counter++,10);fetch('https://example.com/blocked').catch(()=>{});</script>
        """)
        let window = NSWindow(contentRect: web.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = web
        defer { web.removeFromSuperview(); window.orderOut(nil); configuration.userContentController.removeScriptMessageHandler(forName: "notchwork") }
        window.orderFrontRegardless()
        for _ in 0..<100 where !received.contains(where: { $0.0 == "policy" }) { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertTrue(received.contains { $0.0 == "policy" && $0.1 == "connect-src" })
        let title = try await web.evaluateJavaScript("document.getElementById('title').textContent") as? String
        XCTAssertEqual(title, "My own layout")
        _ = try await web.evaluateJavaScript("document.getElementById('run').click(); true")
        for _ in 0..<20 where !received.contains(where: { $0.0 == "restart" }) { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertTrue(received.contains { $0.0 == "restart" && $0.1 == "owned-service" })
        web.removeFromSuperview()
        try await Task.sleep(nanoseconds: 300_000_000)
        let stopped = try await web.evaluateJavaScript("typeof window.counter") as? String
        XCTAssertEqual(stopped, "undefined")
    }
}
