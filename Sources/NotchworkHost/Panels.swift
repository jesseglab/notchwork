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
    @Published var housing: CGFloat = 0
    @Published var topHeight: CGFloat = 28
    @Published var wing: CGFloat = 36
}
@MainActor final class PanelManager {
    private let store: ActivityStore
    let state = PanelState()
    private var windows: [HostPanel] = []
    private var surfaces: [LiquidSurfaceView] = []
    private var opened = [false]
    private var suppressed = [false]
    private var outside: [Date?] = [nil]
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
                ActivityList(store: store, close: { [weak self] in self?.close(0) }, settings: { [weak self] in self?.settings?() })
            }, compact: header)
        surfaces = [notch]
        for (index, title) in ["Notchwork · Notch"].enumerated() {
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
        store.onPresent = { [weak self] in self?.open(0, focus: true) }
        store.onLayoutChanged = { [weak self] in self?.layout(animated: true) }
        layout(animated: false)
    }
    func open(_ index: Int, focus: Bool = false) {
        guard windows.indices.contains(index) else { return }
        if opened[index] {
            if focus { layout(animated: true); windows[index].makeKeyAndOrderFront(nil) }
            return
        }
        opened[index] = true; outside[index] = nil
        layout(animated: true)
        if focus { windows[index].makeKeyAndOrderFront(nil) }
    }
    func close(_ index: Int) {
        store.endPresentation()
        opened[index] = false; suppressed[index] = true; outside[index] = nil
        windows[index].makeFirstResponder(nil); windows[index].resignKey()
        layout(animated: true)
    }
    private func layout(animated: Bool) {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        let frame = screen.frame
        let geometry = NotchGeometry(screen: frame, safeTop: screen.safeAreaInsets.top,
                                     leftArea: screen.auxiliaryTopLeftArea, rightArea: screen.auxiliaryTopRightArea,
                                     hasActivity: store.visibleActivities.contains { $0 != nil },
                                     singlePresentation: store.presentationActivities.count == 1)
        if state.housing != geometry.housing { state.housing = geometry.housing }
        if state.topHeight != geometry.topHeight { state.topHeight = geometry.topHeight }
        if state.wing != geometry.wing { state.wing = geometry.wing }
        let compact = geometry.compact, expanded = geometry.expanded
        let animate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        surfaces[0].move(compact: compact, expanded: expanded, open: opened[0], animated: animate)
        windows[0].orderFrontRegardless()
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
        store.onLayoutChanged = nil; store.onPresent = nil
    }
}
