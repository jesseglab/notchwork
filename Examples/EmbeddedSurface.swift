import AppKit
import SwiftUI
import NotchworkKit

/// Keep this controller alive while your panel is in use. Own pointer/keyboard policy in your app.
@MainActor final class EmbeddedDrawer {
    let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    let surface = LiquidSurfaceView(edge: .leftDrawer,
        expanded: Text("Your own SwiftUI view").foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity),
        compact: Image(systemName: "chevron.right").foregroundStyle(.green).frame(maxWidth: .infinity, maxHeight: .infinity))
    init() {
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.isReleasedWhenClosed = false; panel.contentView = surface
        surface.onPointerEntered = { [weak self] in self?.setOpen(true) }
    }
    func setOpen(_ open: Bool) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let compact = CGRect(x: frame.minX, y: frame.midY - 48, width: 26, height: 96)
        let expanded = CGRect(x: frame.minX, y: frame.midY - 250, width: 360, height: 500)
        surface.move(compact: compact, expanded: expanded, open: open,
                     animated: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        panel.orderFrontRegardless()
    }
    func stop() { surface.stopMotion(); panel.orderOut(nil) }
}
