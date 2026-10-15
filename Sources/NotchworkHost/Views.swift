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
            slots(.left).frame(width: state.wing, alignment: .trailing)
            Color.clear.frame(width: state.housing).accessibilityHidden(true)
            slots(.right).frame(width: state.wing, alignment: .leading)
        }.frame(maxWidth: .infinity).frame(height: state.topHeight).foregroundStyle(mint)
    }
    func slots(_ side: NotchSide) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(store.slots(side).enumerated()), id: \.offset) { _, card in
                SlotButton(card: card, height: state.topHeight, open: open)
            }
        }.padding(.horizontal, 6)
    }
}
private struct SlotButton: View {
    let card: NotchActivity?
    let height: CGFloat
    let open: () -> Void
    private var label: String { card.map { $0.sourceName + ": " + $0.title } ?? "Empty slot · configure Notchwork" }
    private var color: Color { card?.priority == .urgent ? .orange : mint }
    var body: some View {
        Button(action: open) {
            HStack(spacing: 4) {
                ActivityIconView(card: card).foregroundStyle(color)
                if let card {
                    Text(card.title).lineLimit(1).font(.system(size: 9, weight: .medium, design: .monospaced))
                }
            }.frame(width: 68, height: height)
        }.buttonStyle(.plain).help(label).accessibilityLabel(label)
    }
}
struct DrawerTab: View {
    var side: NotchSide
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            VStack(spacing: 14) {
                Image(systemName: side == .left ? "chevron.right" : "chevron.left")
                RoundedRectangle(cornerRadius: 2).frame(width: 3, height: 25).opacity(0.5)
            }.font(.system(size: 10, weight: .semibold)).foregroundStyle(mint).frame(maxWidth: .infinity, maxHeight: .infinity)
        }.buttonStyle(.plain).accessibilityLabel("Open \(side.rawValue) drawer")
    }
}
struct ActivityList: View {
    @ObservedObject var store: ActivityStore
    var side: NotchSide?
    var close: () -> Void
    var settings: () -> Void
    var cards: [NotchActivity] { store.cards(side ?? .left, drawer: side != nil) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(side.map { "\($0.rawValue.uppercased()) DRAWER" } ?? "NOTCHWORK").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(mint)
                    Text(side == nil ? "Your apps, within reach." : "Live activities").font(.system(size: 18, weight: .medium))
                }
                Spacer()
                Button(action: settings) { Image(systemName: "slider.horizontal.3") }.help("Configure slots and drawers")
                Button(action: close) { Image(systemName: "xmark") }.help("Collapse")
            }.buttonStyle(.plain).padding(22)
            Divider().overlay(mint.opacity(0.15))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if cards.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "square.stack.3d.up").font(.system(size: 30)).foregroundStyle(mint)
                            Text("A place for your apps.").font(.system(size: 22, weight: .medium))
                            Text("Connect an app or load examples to try slots, priority activities, and both edge drawers.").foregroundStyle(.secondary)
                            Button("Load examples") { store.loadExamples() }.buttonStyle(.borderedProminent).tint(mint).foregroundStyle(.black)
                        }.padding(.vertical, 20)
                    }
                    ForEach(cards, id: \.stableKey) { card in
                        if let interface = card.interface, store.permitsInterface(card) {
                            CustomInterfaceView(interface: interface) { action, value in
                                store.invoke(sourceID: card.sourceID, activityID: card.id, action: action, value: value)
                            }.frame(height: interface.height).clipShape(RoundedRectangle(cornerRadius: 16))
                        } else { ActivityCard(card: card, dismiss: { store.dismiss(card) }) }
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
    private static let cache = NSCache<NSString, NSImage>()
    private var image: NSImage? {
        guard let encoded = card?.iconPNG else { return nil }
        if let cached = Self.cache.object(forKey: encoded as NSString) { return cached }
        guard let data = Data(base64Encoded: encoded), let image = NSImage(data: data) else { return nil }
        Self.cache.countLimit = 64; Self.cache.setObject(image, forKey: encoded as NSString)
        return image
    }
    var body: some View {
        if let image { Image(nsImage: image).resizable().scaledToFit().frame(width: 22, height: 22) }
        else { Image(systemName: icon(card?.symbol ?? "circle.dotted")) }
    }
}
