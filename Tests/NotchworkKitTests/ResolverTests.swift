import XCTest
@testable import NotchworkKit

final class ResolverTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 100)
    func entry(_ source: String, _ id: String = "activity", priority: ActivityPriority = .normal, side: NotchSide = .left, sequence: UInt64 = 1, expiry: Double = 200) -> ActivityEntry {
        ActivityEntry(activity: NotchActivity(id: id, sourceID: source, sourceName: source, title: id, priority: priority, preferredSide: side), expiresAt: Date(timeIntervalSince1970: expiry), sequence: sequence)
    }
    func resolve(_ entries: [ActivityEntry], slots: [SlotPreference] = [.init()], sources: [SourcePreference]? = nil, side: NotchSide = .left) -> [NotchActivity?] {
        SlotResolver.resolve(entries: entries, sources: sources ?? [.init(id: "music", name: "Music"), .init(id: "build", name: "Build", canInterrupt: true)], slots: slots, side: side, now: now)
    }
    func testIndependentSides() {
        let entries = [entry("music"), entry("build", side: .right)]
        XCTAssertEqual(resolve(entries).first??.sourceID, "music")
        XCTAssertEqual(resolve(entries, side: .right).first??.sourceID, "build")
    }
    func testPinnedSourceIgnoresPreferredSide() {
        XCTAssertEqual(resolve([entry("music", side: .right)], slots: [.init(sourceID: "music")]).first??.sourceID, "music")
    }
    func testPriorityTemporarilyReplacesPinnedApp() {
        let entries = [entry("music"), entry("build", priority: .urgent, sequence: 2)]
        XCTAssertEqual(resolve(entries, slots: [.init(sourceID: "music")]).first??.sourceID, "build")
        XCTAssertEqual(resolve([entries[0]], slots: [.init(sourceID: "music")]).first??.sourceID, "music")
    }
    func testExpiredPriorityRestoresApp() {
        XCTAssertEqual(resolve([entry("music"), entry("build", priority: .urgent, expiry: 99)]).first??.sourceID, "music")
    }
    func testUnpermittedSourceCannotInterrupt() {
        XCTAssertEqual(resolve([entry("music"), entry("build", priority: .urgent, sequence: 2)], sources: [.init(id: "music", name: "Music"), .init(id: "build", name: "Build")]).first??.sourceID, "music")
    }
    func testPinnedSlotCanRefuseAllInterruptions() {
        XCTAssertEqual(resolve([entry("music"), entry("build", priority: .urgent)], slots: [.init(sourceID: "music", allowInterruptions: false)]).first??.sourceID, "music")
    }
    func testDisabledSourcesAndSlotsStayEmpty() {
        XCTAssertNil(resolve([entry("music")], sources: [.init(id: "music", name: "Music", enabled: false)])[0])
        XCTAssertNil(resolve([entry("music")], slots: [.init(enabled: false)])[0])
    }
    func testNoDuplicatesAcrossSlots() {
        let result = resolve([entry("build", priority: .urgent), entry("music", sequence: 2)], slots: [.init(), .init(), .init()])
        XCTAssertEqual(result.compactMap { $0?.sourceID }, ["build", "music"])
    }
    func testStableEqualPriorityOrder() {
        let entries = [entry("build", "first", priority: .important), entry("build", "second", priority: .important, sequence: 2)]
        XCTAssertEqual(resolve(entries.reversed()).first??.id, "first")
    }
    func testUrgentBeatsImportant() {
        XCTAssertEqual(resolve([entry("build", "important", priority: .important), entry("build", "urgent", priority: .urgent, sequence: 2)]).first??.id, "urgent")
    }
    func testValidationAndRoundTrip() throws {
        let card = entry("music").activity
        XCTAssertNoThrow(try card.validate())
        XCTAssertEqual(try JSONDecoder().decode(NotchActivity.self, from: JSONEncoder().encode(card)), card)
    }
    func testRejectsInvalidLifetimeProgressAndIDs() {
        var card = entry("music").activity
        card.ttl = -1; XCTAssertThrowsError(try card.validate())
        card.ttl = 60; card.progress = 1.1; XCTAssertThrowsError(try card.validate())
        card.progress = nil; card.sourceID = "../foo"; XCTAssertThrowsError(try card.validate())
    }
    func testRejectsExecutableAndCredentialURLs() {
        for url in ["file:///tmp/script", "javascript:alert(1)", "terminal://run", "https://user:pass@example.com"] {
            var card = entry("music").activity; card.actions = [.init(title: "Run", url: url)]
            XCTAssertThrowsError(try card.validate())
        }
        var card = entry("music").activity
        card.actions = [.init(title: "Open", url: "http://localhost:3000")]
        XCTAssertNoThrow(try card.validate())
    }
    func testClientRejectsAmbiguousAndRemoteEndpoints() {
        for endpoint in ["https://127.0.0.1:5000", "http://localhost:5000", "http://example.com:5000", "http://127.0.0.1:0", "http://user:pass@127.0.0.1:5000", "http://127.0.0.1:5000/path", "http://127.0.0.1:5000?token=x", "http://127.0.0.1:5000#fragment"] {
            XCTAssertThrowsError(try NotchworkClient.endpointURL(endpoint))
        }
        XCTAssertEqual(try NotchworkClient.endpointURL("http://127.0.0.1:5000").absoluteString, "http://127.0.0.1:5000/v1/activity")
    }
    func testBoundedPayload() {
        var card = entry("music").activity
        card.details = Array(repeating: "line", count: 31); XCTAssertThrowsError(try card.validate())
        card.details = []; card.title = String(repeating: "a", count: 121); XCTAssertThrowsError(try card.validate())
    }
    func testLeftDrawerMirrorsRight() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 300)
        let left = LiquidShape.path(in: rect, edge: .leftDrawer, progress: 1)
        let right = LiquidShape.path(in: rect, edge: .drawer, progress: 1)
        for x in stride(from: 1.0, through: 199.0, by: 7) {
            for y in stride(from: 1.0, through: 299.0, by: 7) {
                XCTAssertEqual(left.contains(CGPoint(x: x, y: y)), right.contains(CGPoint(x: 200 - x, y: y)))
            }
        }
    }
    func testSpringPreservesVelocityAcrossReversal() {
        var spring = LiquidSpring(0); spring.target = 1
        spring.advance(0.1)
        let speed = spring.velocity, value = spring.value
        spring.target = 0
        XCTAssertEqual(spring.value, value); XCTAssertEqual(spring.velocity, speed)
        for _ in 0..<240 { spring.advance(1 / 120) }
        XCTAssertTrue(spring.isSettled())
    }
}
