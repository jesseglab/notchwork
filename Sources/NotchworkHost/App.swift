import AppKit
import SwiftUI
import NotchworkKit
import Darwin

@main struct NotchworkApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: ActivityStore!
    private var integrations: Integrations!
    private var panels: PanelManager!
    private var server: LocalServer?
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var lockFile: Int32 = -1
    func applicationDidFinishLaunching(_ notification: Notification) {
        let preview = CommandLine.arguments.contains("--preview")
        let directory = preview ? FileManager.default.temporaryDirectory.appendingPathComponent("Notchwork-preview") : HostConnection.defaultFile.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        lockFile = Darwin.open(directory.appendingPathComponent("host.lock").path, O_CREAT | O_RDWR, 0o600)
        guard lockFile >= 0, flock(lockFile, LOCK_EX | LOCK_NB) == 0 else { NSApp.terminate(nil); return }
        store = ActivityStore(directory: directory)
        integrations = Integrations(store: store, restore: !preview)
        panels = PanelManager(store: store)
        panels.settings = { [weak self] in self?.showSettings() }
        server = LocalServer(file: directory.appendingPathComponent("connection.json"), handle: { [weak self] command in
            await self?.store.respond(command) ?? HostResponse(ok: false, message: "Host unavailable.")
        }, status: { [weak self] in self?.store.connectionStatus = $0 })
        do { try server?.start() } catch { store.connectionStatus = "Could not start local API: " + error.localizedDescription }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "Notchwork")
        let menu = NSMenu()
        for (title, action, key) in [("Configure Notchwork…", #selector(showSettings), ","), ("Open activities", #selector(showActivities), ""), ("Quit Notchwork", #selector(quit), "q")] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = self; menu.addItem(item)
        }
        statusItem.menu = menu
        if preview { store.loadExamples() }
        showSettings()
    }
    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 780, height: 750), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Notchwork · Control room"; window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(store: store, integrations: integrations))
            window.center(); settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func showActivities() { panels.open(0, focus: true) }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        integrations?.stop(); panels?.stop(); store?.stop(); server?.stop()
        if lockFile >= 0 { Darwin.close(lockFile) }
    }
}
