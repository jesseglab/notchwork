import XCTest
import CoreGraphics
@testable import NotchworkHost

final class NotchGeometryTests: XCTestCase {
    private func geometry(active: Bool, single: Bool = true) -> NotchGeometry {
        // A second display with a negative origin and an off-center camera gap.
        NotchGeometry(screen: CGRect(x: -1600, y: 300, width: 1600, height: 1000), safeTop: 32,
                      leftArea: CGRect(x: -1600, y: 1268, width: 650, height: 32),
                      rightArea: CGRect(x: -750, y: 1268, width: 750, height: 32),
                      hasActivity: active, singlePresentation: single)
    }
    func testIdleHugsHardwareAndActiveLeavesOnlyIconSpace() {
        let idle = geometry(active: false), active = geometry(active: true)
        XCTAssertEqual(idle.housing, 200)
        XCTAssertEqual(idle.compact.width - idle.housing, 4)
        XCTAssertEqual(active.compact.width - active.housing, 88)
        XCTAssertEqual(active.compact.height, 34)
        XCTAssertEqual(idle.compact.midX, -850)
        XCTAssertEqual(active.compact.midX, idle.compact.midX)
        XCTAssertEqual(active.compact.maxY, 1300)
    }
    func testPresentationCountNeverInflatesCollapsedSizeOrMovesAnchor() {
        let single = geometry(active: true), two = geometry(active: true, single: false)
        XCTAssertEqual(single.compact, two.compact)
        XCTAssertGreaterThan(two.expanded.width, single.expanded.width)
        for item in [single, two, geometry(active: false)] {
            XCTAssertEqual(item.compact.midX, item.expanded.midX)
            XCTAssertEqual(item.compact.maxY, item.expanded.maxY)
            XCTAssertGreaterThanOrEqual(item.expanded.minX, -1600)
            XCTAssertLessThanOrEqual(item.expanded.maxX, 0)
        }
    }
    func testDisplayWithoutNotchUsesSmallHandleWithoutFakeCameraGap() {
        for active in [false, true] {
            let item = NotchGeometry(screen: CGRect(x: 500, y: -900, width: 1440, height: 900), safeTop: 0,
                                     leftArea: nil, rightArea: nil, hasActivity: active, singlePresentation: true)
            XCTAssertEqual(item.housing, 0)
            XCTAssertEqual(item.compact.size, CGSize(width: 88, height: 28))
            XCTAssertEqual(item.compact.midX, 1220)
            XCTAssertEqual(item.compact.maxY, 0)
        }
    }
    func testAppInterfaceSizeUsesItsOwnContentDimensions() {
        let item = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1728, height: 1117), safeTop: 32,
                                 leftArea: CGRect(x: 0, y: 1085, width: 771.5, height: 32),
                                 rightArea: CGRect(x: 956.5, y: 1085, width: 771.5, height: 32),
                                 hasActivity: true, singlePresentation: true, interfaceSize: CGSize(width: 400, height: 590))
        XCTAssertEqual(item.expanded.size, CGSize(width: 424, height: 662))
        XCTAssertEqual(item.compact.width, 273)
        XCTAssertEqual(item.compact.midX, item.expanded.midX)
    }
    func testExpandedSurfaceFitsNarrowScreen() {
        let screen = CGRect(x: 0, y: 0, width: 800, height: 600)
        let item = NotchGeometry(screen: screen, safeTop: 0, leftArea: nil, rightArea: nil,
                                 hasActivity: true, singlePresentation: false)
        XCTAssertTrue(screen.contains(item.compact))
        XCTAssertTrue(screen.contains(item.expanded))
        XCTAssertEqual(item.expanded.width, 776)
    }
}
