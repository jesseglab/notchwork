import AppKit
import SwiftUI
import NotchworkKit

private let mint = Color(red: 0.43, green: 1, blue: 0.66)
private func icon(_ name: String) -> String { NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil ? name : "app" }
struct NotchHeader: View {
    @ObservedObject var store: ActivityStore
    @ObservedObject var state: PanelState
    let open: () -> Void
    var body: some View {
        HStack(spacing: 0) {
            let card = store.visibleActivities.first ?? nil
            SlotButton(card: card, width: state.wing, height: state.topHeight, open: open)
            Color.clear.frame(width: state.housing).accessibilityHidden(true)
            if store.preferences.mode == .single {
                Button(action: open) {
                    Group {
                        if let card {
                            Circle().fill(card.priority == .urgent ? Color.orange : mint).frame(width: 4, height: 4)
                        } else { Color.clear }
                    }.frame(width: state.wing, height: state.topHeight).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .help(card?.title ?? "Configure Notchwork")
                    .accessibilityLabel(card.map { $0.sourceName + ": " + $0.title } ?? "Configure Notchwork")
            } else {
                SlotButton(card: store.slots(.right).first ?? nil, width: state.wing, height: state.topHeight, open: open)
            }
        }.frame(maxWidth: .infinity).frame(height: state.topHeight).foregroundStyle(mint)
    }
}
private struct SlotButton: View {
    let card: NotchActivity?
    let width: CGFloat
    let height: CGFloat
    let open: () -> Void
    private var label: String { card.map { $0.sourceName + ": " + $0.title } ?? "Empty slot · configure Notchwork" }
    var body: some View {
        Button(action: open) {
            Group {
                if let card {
                    ActivityIconView(card: card, size: 16)
                        .foregroundStyle(card.priority == .urgent ? Color.orange : mint)
                } else { Color.clear }
            }.frame(width: width, height: height).contentShape(Rectangle())
        }.buttonStyle(.plain).help(label).accessibilityLabel(label)
    }
}
struct ActivityList: View {
    @ObservedObject var store: ActivityStore
    var close: () -> Void
    var settings: () -> Void
    var cards: [NotchActivity] { store.presentationActivities.compactMap { $0 } }
    var body: some View {
        if store.presentationActivities.count == 1, let card = cards.first,
           let interface = card.interface, store.permitsInterface(card) {
            VStack(spacing: 0) {
                HStack {
                    Text(card.title.uppercased()).font(.system(size: 9, design: .monospaced))
                    Spacer()
                    Button { store.userPinned.toggle() } label: { Image(systemName: store.userPinned ? "pin.fill" : "pin") }.help(store.userPinned ? "Unpin notch panel" : "Keep notch panel open")
                    Button(action: settings) { Image(systemName: "slider.horizontal.3") }.help("Notchwork settings")
                    Button(action: close) { Image(systemName: "xmark") }.help("Collapse")
                }.buttonStyle(.plain).foregroundStyle(mint).padding(.horizontal, 22).frame(height: 30)
                CustomInterfaceView(interface: interface) { action, value in
                    store.invoke(sourceID: card.sourceID, activityID: card.id, action: action, value: value)
                }.id(card.stableKey).padding(.horizontal, 12)
                Spacer(minLength: 10)
            }.background(.black).preferredColorScheme(.dark)
        } else { standardContent }
    }
    private var standardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("NOTCHWORK").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(mint)
                    Text(store.presentationActivities.count == 1 ? (cards.first?.sourceName ?? "Choose an app") : "Your apps, within reach.").font(.system(size: 18, weight: .medium))
                }
                Spacer()
                Button(action: settings) { Image(systemName: "slider.horizontal.3") }.help("Configure the notch")
                Button(action: close) { Image(systemName: "xmark") }.help("Collapse")
            }.buttonStyle(.plain).padding(22)
            Divider().overlay(mint.opacity(0.15))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if cards.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "square.stack.3d.up").font(.system(size: 30)).foregroundStyle(mint)
                            Text("A place for your apps.").font(.system(size: 22, weight: .medium))
                            Text("Apps connect through the Notchwork API. Choose how they share the container in settings.").foregroundStyle(.secondary)
                            Button("Settings") { settings() }.buttonStyle(.borderedProminent).tint(mint).foregroundStyle(.black)
                        }.padding(.vertical, 20)
                    }
                    if store.presentationActivities.count == 1 {
                        if let card = cards.first { content(card) }
                    } else {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(Array(store.presentationActivities.enumerated()), id: \.offset) { index, card in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(index == 0 ? "LEFT" : "RIGHT").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                                    if let card { content(card) }
                                    else { Text("No active app").foregroundStyle(.secondary).padding(.vertical, 24) }
                                }.frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                        }
                    }
                }.padding(20)
            }
            HStack {
                Circle().fill(mint).frame(width: 5, height: 5)
                Text("LOCAL · \(cards.count) ACTIVITIES").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
            }.padding(.horizontal, 22).padding(.bottom, 18)
        }.foregroundStyle(.white).background(.black).preferredColorScheme(.dark)
    }
    @ViewBuilder private func content(_ card: NotchActivity) -> some View {
        if let interface = card.interface, store.permitsInterface(card) {
            CustomInterfaceView(interface: interface) { action, value in
                store.invoke(sourceID: card.sourceID, activityID: card.id, action: action, value: value)
            }.id(card.stableKey).frame(height: interface.height).clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if card.interface != nil {
                    Text("App controls are turned off for \(card.sourceName).").font(.system(size: 12))
                    Button("Enable \(card.sourceName) controls") {
                        if let index = store.preferences.sources.firstIndex(where: { $0.id == card.sourceID }) {
                            store.preferences.sources[index].allowCustomInterface = true
                            store.save()
                        }
                    }.buttonStyle(.borderedProminent)
                }
                ActivityCard(card: card, dismiss: { store.dismiss(card) })
            }
        }
    }

}
extension NotchActivity { var stableKey: String { sourceID + "/" + id } }
struct ActivityCard: View {
    let card: NotchActivity
    let dismiss: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ActivityIconView(card: card).font(.system(size: 20)).foregroundStyle(card.priority == .urgent ? .orange : mint).frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.sourceName.uppercased()).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                    Text(card.title).font(.system(size: 16, weight: .semibold))
                    if !card.subtitle.isEmpty { Text(card.subtitle).font(.system(size: 12)).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 4)
                Button(action: dismiss) { Image(systemName: "xmark").font(.system(size: 9)) }.buttonStyle(.plain).help("Dismiss this activity")
            }
            if let progress = card.progress { ProgressView(value: progress).tint(mint).accessibilityLabel("\(Int(progress * 100)) percent") }
            if !card.details.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(card.details.enumerated()), id: \.offset) { _, line in Text(line).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled) }
                }
            }
            if !card.actions.isEmpty {
                HStack {
                    ForEach(Array(card.actions.enumerated()), id: \.offset) { _, action in
                        Button(action.title) { if let url = URL(string: action.url) { NSWorkspace.shared.open(url) } }.buttonStyle(.bordered).tint(mint)
                    }
                }
            }
        }.padding(16).background(Color(white: 0.065), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(card.priority == .urgent ? Color.orange.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1))
    }
}

private struct ActivityIconView: View {
    let card: NotchActivity?
    var size: CGFloat = 22
    private static let cache = NSCache<NSString, NSImage>()
    private var image: NSImage? {
        guard let encoded = card?.iconPNG else { return nil }
        if let cached = Self.cache.object(forKey: encoded as NSString) { return cached }
        guard let data = Data(base64Encoded: encoded), let image = NSImage(data: data) else { return nil }
        Self.cache.countLimit = 64; Self.cache.setObject(image, forKey: encoded as NSString)
        return image
    }
    var body: some View {
        if let image { Image(nsImage: image).resizable().scaledToFit().frame(width: size, height: size) }
        else { Image(systemName: icon(card?.symbol ?? "circle.dotted")).resizable().scaledToFit().frame(width: size, height: size) }
    }
}
