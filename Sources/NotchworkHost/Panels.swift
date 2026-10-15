import AppKit
import SwiftUI
import NotchworkKit

final class HostPanel: NSPanel {
    var escape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { escape?() }
    override func keyDown(with event: NSEvent) { if event.keyCode == 53 { escape?() } else { super.keyDown(with: event) } }
    override func sendEvent(_ event: NSEvent) { if event.type == .leftMouseDown { makeKey() }; super.sendEvent(event) }
    init(_ title: String) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        self.title = title; isReleasedWhenClosed = false; isOpaque = false; backgroundColor = .clear
        hasShadow = false; hidesOnDeactivate = false; acceptsMouseMovedEvents = true
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        appearance = NSAppearance(named: .darkAqua)
    }
}
@MainActor final class PanelState: ObservableObject {
    @Published var housing: CGFloat = 180
    @Published var topHeight: CGFloat = 32
    @Published var wing: CGFloat = 86
}
@MainActor final class PanelManager {
    private let store: ActivityStore
    let state = PanelState()
    private var windows: [HostPanel] = []
    private var surfaces: [LiquidSurfaceView] = []
    private var opened = [false, false, false]
    private var suppressed = [false, false, false]
    private var outside: [Date?] = [nil, nil, nil]
    private var timer: Timer?
    private var monitors: [Any] = []
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    var settings: (() -> Void)?
    init(store: ActivityStore) {
        self.store = store
        let header = NotchHeader(store: store, state: state, open: { [weak self] in self?.open(0, focus: true) })
        let notch = LiquidSurfaceView(edge: .notch,
            expanded: VStack(spacing: 0) {
                header
                ActivityList(store: store, side: nil, close: { [weak self] in self?.close(0) }, settings: { [weak self] in self?.settings?() })
            }, compact: header)
        let left = LiquidSurfaceView(edge: .leftDrawer,
            expanded: ActivityList(store: store, side: .left, close: { [weak self] in self?.close(1) }, settings: { [weak self] in self?.settings?() }),
            compact: DrawerTab(side: .left, open: { [weak self] in self?.open(1, focus: true) }))
        let right = LiquidSurfaceView(edge: .drawer,
            expanded: ActivityList(store: store, side: .right, close: { [weak self] in self?.close(2) }, settings: { [weak self] in self?.settings?() }),
            compact: DrawerTab(side: .right, open: { [weak self] in self?.open(2, focus: true) }))
        surfaces = [notch, left, right]
        for (index, title) in ["Notchwork · Notch", "Notchwork · Left drawer", "Notchwork · Right drawer"].enumerated() {
            let panel = HostPanel(title); panel.contentView = surfaces[index]
            panel.escape = { [weak self] in self?.close(index) }
            surfaces[index].onPointerEntered = { [weak self] in
                guard let self, self.store.preferences.hoverToOpen, !self.suppressed[index],
                      self.surfaces[index].containsHoverPoint(NSEvent.mouseLocation, expanded: false) else { return }
                self.open(index)
            }
            windows.append(panel)
        }
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in MainActor.assumeIsolated { self?.pointerMoved() } }) { monitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in MainActor.assumeIsolated { self?.pointerMoved() }; return event }) { monitors.append(monitor) }
        for (center, name) in [(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification),
                               (NSWorkspace.shared.notificationCenter, NSWorkspace.activeSpaceDidChangeNotification),
                               (NSWorkspace.shared.notificationCenter, NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)] {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.layout(animated: false) } }
            observers.append((center, observer))
        }
        store.onLayoutChanged = { [weak self] in self?.layout(animated: true) }
        layout(animated: false)
    }
    func open(_ index: Int, focus: Bool = false) {
        guard windows.indices.contains(index), !opened[index] else { return }
        opened[index] = true; outside[index] = nil
        layout(animated: true)
        if focus { windows[index].makeKeyAndOrderFront(nil) }
    }
    func close(_ index: Int) {
        opened[index] = false; suppressed[index] = true; outside[index] = nil
        windows[index].makeFirstResponder(nil); windows[index].resignKey()
        layout(animated: true)
    }
    private func layout(animated: Bool) {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        let frame = screen.frame, visible = screen.visibleFrame
        let housing = screen.auxiliaryTopLeftArea.flatMap { left in screen.auxiliaryTopRightArea.map { max(0, $0.minX - left.maxX) } } ?? 150
        let top = max(28, screen.safeAreaInsets.top)
        let count = max(store.preferences.left.filter(\.enabled).count, store.preferences.right.filter(\.enabled).count, 1)
        let wing = CGFloat(count) * 74 + 12
        if state.housing != housing { state.housing = housing }
        if state.topHeight != top { state.topHeight = top }
        if state.wing != wing { state.wing = wing }
        let width = min(frame.width - 24, housing + wing * 2)
        let expandedWidth = max(width, min(560, frame.width - 24))
        let compact = CGRect(x: frame.midX - width / 2, y: frame.maxY - top - 6, width: width, height: top + 6)
        let expanded = CGRect(x: frame.midX - expandedWidth / 2, y: frame.maxY - min(480, frame.height - 24), width: expandedWidth, height: min(480, frame.height - 24))
        let animate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        surfaces[0].move(compact: compact, expanded: expanded, open: opened[0], animated: animate)
        windows[0].orderFrontRegardless()
        for index in 1...2 {
            let preference = index == 1 ? store.preferences.leftDrawer : store.preferences.rightDrawer
            guard preference.enabled else { opened[index] = false; surfaces[index].stopMotion(); windows[index].orderOut(nil); continue }
            let size = CGSize(width: min(420, visible.width / 2 - 16), height: min(680, visible.height - 32))
            let handle = CGRect(x: index == 1 ? frame.minX : frame.maxX - 26, y: visible.midY - 48, width: 26, height: 96)
            let content = CGRect(x: index == 1 ? frame.minX : frame.maxX - size.width, y: visible.midY - size.height / 2, width: size.width, height: size.height)
            surfaces[index].move(compact: handle, expanded: content, open: opened[index], animated: animate)
            windows[index].orderFrontRegardless()
        }
    }
    private func pointerMoved() {
        guard NSApp.modalWindow == nil, !NSApp.windows.contains(where: { $0.isVisible && $0.className.contains("Menu") }) else { return }
        timer?.invalidate(); timer = nil
        let point = NSEvent.mouseLocation, now = Date()
        var deadline: Date?
        for index in windows.indices where windows[index].isVisible {
            surfaces[index].updatePointerPassThrough()
            if surfaces[index].containsHoverPoint(point, expanded: opened[index]) {
                outside[index] = nil
                if store.preferences.hoverToOpen && !suppressed[index] { open(index) }
            } else {
                suppressed[index] = false
                guard opened[index] else { continue }
                if windows[index].isKeyWindow, let editor = windows[index].firstResponder as? NSTextView, editor.isEditable { continue }
                if outside[index] == nil { outside[index] = now }
                let date = outside[index]!.addingTimeInterval(0.65)
                if date <= now { close(index) }
                else { deadline = min(deadline ?? date, date) }
            }
        }
        if let deadline {
            timer = Timer.scheduledTimer(withTimeInterval: max(0.01, deadline.timeIntervalSinceNow), repeats: false) { [weak self] _ in MainActor.assumeIsolated { self?.pointerMoved() } }
        }
    }
    func stop() {
        timer?.invalidate(); monitors.forEach(NSEvent.removeMonitor)
        for (center, observer) in observers { center.removeObserver(observer) }
        surfaces.forEach { $0.stopMotion() }; windows.forEach { $0.orderOut(nil) }
        store.onLayoutChanged = nil
    }
}
