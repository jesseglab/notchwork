import SwiftUI
import NotchworkKit

struct SettingsView: View {
    @ObservedObject var store: ActivityStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTCHWORK").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.mint)
                        Text("Your notch. Your apps.").font(.system(size: 28, weight: .medium))
                        Text("A morphing container for the apps you choose.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "rectangle.topthird.inset.filled").font(.system(size: 32)).foregroundStyle(.mint)
                }
                VStack(alignment: .leading, spacing: 16) {
                    Text("ITEMS IN THE NOTCH").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.mint)
                    Picker("Items", selection: Binding(get: { store.preferences.mode }, set: { store.endPresentation(); store.preferences.mode = $0; store.save() })) {
                        Text("One").tag(NotchLayoutMode.single)
                        Text("Two").tag(NotchLayoutMode.dual)
                        Text("Multiple").tag(NotchLayoutMode.multiple)
                    }.pickerStyle(.segmented)
                    switch store.preferences.mode {
                    case .single:
                        Text("One app gets the whole morphing container and all of its controls.").foregroundStyle(.secondary)
                        sourcePicker(Binding(get: { store.preferences.singleSourceID }, set: { store.preferences.singleSourceID = $0; store.save() }))
                    case .dual:
                        Text("Keep one app on the left and another on the right.").foregroundStyle(.secondary)
                        HStack {
                            VStack(alignment: .leading) { Text("Left"); sourcePicker(slotBinding(.left, 0).sourceID, excluding: store.preferences.right[0].sourceID) }
                            VStack(alignment: .leading) { Text("Right"); sourcePicker(slotBinding(.right, 0).sourceID, excluding: store.preferences.left[0].sourceID) }
                        }
                    case .multiple:
                        Text("All enabled apps can take a turn. The two highest-priority apps appear: high, then mid, then low. New updates win ties; unchanged heartbeats keep their place.").foregroundStyle(.secondary)
                    }
                }.padding(18).background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
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
                        }.toggleStyle(.checkbox)
                    }
                }.padding(18).background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
                HStack {
                    Spacer()
                    Button("Open integration folder") { NSWorkspace.shared.open(store.directory) }
                }
                Text(store.connectionStatus).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                Text("Local container and API. Connected apps own their content and actions. Activities expire automatically when an app stops sending updates.")
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
    func sourcePicker(_ selection: Binding<String?>, excluding: String? = nil) -> some View {
        Picker("App", selection: selection) {
            Text("Automatic").tag(nil as String?)
            ForEach(store.preferences.sources.filter { ($0.enabled && $0.id != excluding) || $0.id == selection.wrappedValue }) { source in Text(source.name).tag(Optional(source.id)) }
        }.labelsHidden()
    }
}
