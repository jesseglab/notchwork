import SwiftUI
import NotchworkKit

struct SettingsView: View {
    @ObservedObject var store: ActivityStore
    @ObservedObject var integrations: Integrations
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTCHWORK / CONTROL ROOM").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.mint)
                        Text("Make room for your apps.").font(.system(size: 28, weight: .medium))
                        Text("Give each side a job. Let the important things through.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "rectangle.topthird.inset.filled").font(.system(size: 32)).foregroundStyle(.mint)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("LIVE INTEGRATIONS").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.mint)
                    Toggle("Apple Music", isOn: Binding(get: { integrations.musicEnabled }, set: { integrations.setMusic($0) }))
                    Text(integrations.musicStatus).font(.system(size: 11)).foregroundStyle(.secondary)
                    if integrations.musicEnabled { Button("Reconnect Music") { integrations.setMusic(true) } }
                    Toggle("Spotify", isOn: Binding(get: { integrations.spotifyEnabled }, set: { integrations.setSpotify($0) }))
                    Text(integrations.spotifyStatus).font(.system(size: 11)).foregroundStyle(.secondary)
                    if integrations.spotifyEnabled { Button("Reconnect Spotify") { integrations.setSpotify(true) } }
                    Toggle("Portkeeper", isOn: Binding(get: { integrations.portkeeperEnabled }, set: { integrations.setPortkeeper($0) }))
                    Text(integrations.portkeeperStatus).font(.system(size: 11)).foregroundStyle(.secondary)
                    Text("Builds & scripts: run a command through notchworkctl run to show its live result.").font(.system(size: 11)).foregroundStyle(.secondary)
                }.toggleStyle(.checkbox).padding(18).background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
                HStack(alignment: .top, spacing: 20) {
                    slotGroup(.left)
                    slotGroup(.right)
                }
                HStack(alignment: .top, spacing: 20) {
                    drawerGroup(.left)
                    drawerGroup(.right)
                }
                Toggle("Expand on hover", isOn: Binding(get: { store.preferences.hoverToOpen }, set: { store.preferences.hoverToOpen = $0; store.save() }))
                VStack(alignment: .leading, spacing: 12) {
                    Text("CONNECTED APPS").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.mint)
                    if store.preferences.sources.isEmpty { Text("Apps appear here when they send their first activity.").foregroundStyle(.secondary) }
                    ForEach(Array(store.preferences.sources.enumerated()), id: \.element.id) { index, source in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(source.name)
                                Text(source.id).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Show", isOn: Binding(get: { store.preferences.sources[index].enabled }, set: { store.preferences.sources[index].enabled = $0; store.save() }))
                            Toggle("Custom UI", isOn: Binding(get: { store.preferences.sources[index].allowCustomInterface == true }, set: { store.preferences.sources[index].allowCustomInterface = $0; store.save() })).help("Allow this trusted app’s HTML, JavaScript, and controls inside Notchwork.")
                            Toggle("Allow priority", isOn: Binding(get: { store.preferences.sources[index].canInterrupt }, set: { store.preferences.sources[index].canInterrupt = $0; store.save() }))
                        }.toggleStyle(.checkbox)
                    }
                }.padding(18).background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
                HStack {
                    Button("Load examples") { store.loadExamples() }
                    Button("Try a priority alert") { store.showPriorityExample() }
                    Spacer()
                    Button("Open integration folder") { NSWorkspace.shared.open(store.directory) }
                }
                Text(store.connectionStatus).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                Text("Private to this Mac. Integrations use a local token. Activities expire automatically; commands run only when you explicitly invoke the command-line wrapper. Music access is optional.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(28)
        }.frame(width: 780, height: 750).background(Color(white: 0.025)).foregroundStyle(.white).preferredColorScheme(.dark)
    }
    func slotBinding(_ side: NotchSide, _ index: Int) -> Binding<SlotPreference> {
        Binding(get: { side == .left ? store.preferences.left[index] : store.preferences.right[index] }, set: {
            if side == .left { store.preferences.left[index] = $0 } else { store.preferences.right[index] = $0 }
            store.save()
        })
    }
    func slotGroup(_ side: NotchSide) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(side.rawValue.uppercased()) OF THE NOTCH").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.mint)
            ForEach(0..<3, id: \.self) { index in
                let binding = slotBinding(side, index)
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Slot \(index + 1)", isOn: binding.enabled).toggleStyle(.checkbox)
                    if binding.wrappedValue.enabled {
                        sourcePicker(binding.sourceID)
                        Toggle("Allow priority interruptions", isOn: binding.allowInterruptions).font(.system(size: 11)).foregroundStyle(.secondary).toggleStyle(.checkbox)
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
    }
    func drawerGroup(_ side: NotchSide) -> some View {
        let binding = Binding<DrawerPreference>(get: { side == .left ? store.preferences.leftDrawer : store.preferences.rightDrawer }, set: {
            if side == .left { store.preferences.leftDrawer = $0 } else { store.preferences.rightDrawer = $0 }; store.save()
        })
        return VStack(alignment: .leading, spacing: 12) {
            Text("\(side.rawValue.uppercased()) EDGE DRAWER").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.mint)
            Toggle("Show drawer", isOn: binding.enabled).toggleStyle(.checkbox)
            sourcePicker(binding.sourceID).disabled(!binding.wrappedValue.enabled)
            Text("Automatic follows each activity’s preferred side.").font(.system(size: 11)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
    }
    func sourcePicker(_ selection: Binding<String?>) -> some View {
        Picker("App", selection: selection) {
            Text("Automatic").tag(nil as String?)
            ForEach(store.preferences.sources) { source in Text(source.name).tag(Optional(source.id)) }
        }.labelsHidden()
    }
}
