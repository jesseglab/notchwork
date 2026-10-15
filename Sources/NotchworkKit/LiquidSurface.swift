import AppKit
import QuartzCore
import SwiftUI

/// Exact critically damped motion. Retargeting changes the destination, not position or velocity.
struct LiquidSpring {
    var value: CGFloat
    var velocity: CGFloat = 0
    var target: CGFloat
    var frequency: CGFloat

    init(_ value: CGFloat, frequency: CGFloat = 20) {
        self.value = value; target = value; self.frequency = frequency
    }
    mutating func advance(_ seconds: TimeInterval) {
        let t = CGFloat(max(0, seconds))
        let displacement = value - target
        let impulse = velocity + frequency * displacement
        let decay = exp(-frequency * t)
        value = target + (displacement + impulse * t) * decay
        velocity = (velocity - frequency * impulse * t) * decay
    }
    mutating func settle() { value = target; velocity = 0 }
    func isSettled(position: CGFloat = 0.05, speed: CGFloat = 0.5) -> Bool {
        abs(value - target) < position && abs(velocity) < speed
    }
}

public enum LiquidEdge { case notch, drawer, leftDrawer }

enum LiquidShape {
    static func reveal(_ progress: CGFloat) -> CGFloat {
        let t = min(1, max(0, (progress - 0.12) / 0.76))
        return t * t * (3 - 2 * t)
    }
    static func path(in rect: CGRect, edge: LiquidEdge, progress: CGFloat) -> CGPath {
        if edge == .leftDrawer {
            var transform = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: rect.minX + rect.maxX, ty: 0)
            return path(in: rect, edge: .drawer, progress: progress).copy(using: &transform)!
        }
        let path = CGMutablePath()
        let x = rect.minX, y = rect.minY, right = rect.maxX, top = rect.maxY
        let p = min(1, max(0, progress))
        let radius = min(rect.height / 2, rect.width / 2, 15 + 11 * p)
        let control: CGFloat = 0.72
        if edge == .notch {
            let shoulder = min(rect.height / 4, 5 + 7 * p)
            let left = x + shoulder, r = right - shoulder
            path.move(to: CGPoint(x: x, y: top))
            path.addCurve(to: CGPoint(x: left, y: top - shoulder),
                          control1: CGPoint(x: left, y: top), control2: CGPoint(x: left, y: top - shoulder * (1 - control)))
            path.addLine(to: CGPoint(x: left, y: y + radius))
            path.addCurve(to: CGPoint(x: left + radius, y: y),
                          control1: CGPoint(x: left, y: y + radius * (1 - control)), control2: CGPoint(x: left + radius * (1 - control), y: y))
            path.addLine(to: CGPoint(x: r - radius, y: y))
            path.addCurve(to: CGPoint(x: r, y: y + radius),
                          control1: CGPoint(x: r - radius * (1 - control), y: y), control2: CGPoint(x: r, y: y + radius * (1 - control)))
            path.addLine(to: CGPoint(x: r, y: top - shoulder))
            path.addCurve(to: CGPoint(x: right, y: top),
                          control1: CGPoint(x: r, y: top - shoulder * (1 - control)), control2: CGPoint(x: r, y: top))
        } else {
            path.move(to: CGPoint(x: right, y: top))
            path.addLine(to: CGPoint(x: x + radius, y: top))
            path.addCurve(to: CGPoint(x: x, y: top - radius),
                          control1: CGPoint(x: x + radius * (1 - control), y: top), control2: CGPoint(x: x, y: top - radius * (1 - control)))
            path.addLine(to: CGPoint(x: x, y: y + radius))
            path.addCurve(to: CGPoint(x: x + radius, y: y),
                          control1: CGPoint(x: x, y: y + radius * (1 - control)), control2: CGPoint(x: x + radius * (1 - control), y: y))
            path.addLine(to: CGPoint(x: right, y: y))
        }
        path.closeSubpath()
        return path
    }
}

/// The window is a stationary canvas during motion. Only its mask and content layers change per frame.
@MainActor public final class LiquidSurfaceView: NSView {
    private let edge: LiquidEdge
    private let expandedHost: NSView
    private let compactHost: NSView
    private let surfaceMask = CAShapeLayer()
    private var width = LiquidSpring(1, frequency: 24)
    private var height = LiquidSpring(1, frequency: 19)
    private var progress = LiquidSpring(0, frequency: 20)
    private var displayDriver: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var canvas = CGRect.zero
    private var compactFrame = CGRect.zero
    private var expandedFrame = CGRect.zero
    private var targetFrame = CGRect.zero
    private var initialized = false
    private var tracking: NSTrackingArea?
    public private(set) var isAnimating = false
    public private(set) var presentedFrame = CGRect.zero
    public var onSettled: (() -> Void)?
    public var onPointerEntered: (() -> Void)?

    public init<Expanded: View, Compact: View>(edge: LiquidEdge, expanded: Expanded, compact: Compact) {
        self.edge = edge
        let expandedHost = NSHostingView(rootView: expanded)
        let compactHost = NSHostingView(rootView: compact)
        expandedHost.sizingOptions = []; compactHost.sizingOptions = []
        self.expandedHost = expandedHost; self.compactHost = compactHost
        super.init(frame: .zero)
        autoresizingMask = [.width, .height]
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.mask = surfaceMask
        surfaceMask.fillColor = NSColor.black.cgColor
        for host in [expandedHost, compactHost] {
            host.wantsLayer = true
        }
        addSubview(compactHost)
    }
    required public init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func move(compact: CGRect, expanded: CGRect, open: Bool, animated: Bool) {
        guard let window else { return }
        let target = open ? expanded : compact
        let sameDestination = initialized && targetFrame == target && progress.target == (open ? 1 : 0)
        if sameDestination && animated { return }
        compactFrame = compact; expandedFrame = expanded; targetFrame = target
        width.frequency = open ? 24 : 29
        height.frequency = open ? 19 : 24
        progress.frequency = open ? 20 : 25
        if !initialized && animated {
            initialized = true
            width.value = compact.width; height.value = compact.height
            progress.value = 0
            canvas = compact
            presentedFrame = compact
        }
        width.target = target.width; height.target = target.height; progress.target = open ? 1 : 0
        if !initialized || !animated {
            initialized = true
            width.settle(); height.settle(); progress.settle()
            stopMotion()
            canvas = target
            window.setFrame(canvas, display: false)
            arrangeHosts()
            render()
            onSettled?()
            return
        }
        // Keep the old canvas through a reversal: neither the text nor the window origin jumps.
        canvas = canvas.union(target).union(presentedFrame)
        window.setFrame(canvas, display: false)
        arrangeHosts()
        render()
        if displayDriver == nil {
            isAnimating = true
            lastTimestamp = nil
            let driver = displayLink(target: self, selector: #selector(displayFrame(_:)))
            driver.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
            displayDriver = driver
            driver.add(to: .main, forMode: .common)
        }
    }
    public func stopMotion() {
        displayDriver?.invalidate(); displayDriver = nil
        lastTimestamp = nil; isAnimating = false
    }
    private func local(_ screenRect: CGRect) -> CGRect {
        screenRect.offsetBy(dx: -canvas.minX, dy: -canvas.minY)
    }
    private func arrangeHosts() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        if progress.target > 0 && expandedHost.superview == nil { addSubview(expandedHost, positioned: .below, relativeTo: compactHost) }
        expandedHost.layer?.transform = CATransform3DIdentity
        compactHost.frame = local(compactFrame)
        expandedHost.frame = local(expandedFrame)
        surfaceMask.frame = bounds
        if expandedHost.superview != nil { expandedHost.layoutSubtreeIfNeeded() }
        compactHost.layoutSubtreeIfNeeded()
        CATransaction.commit()
    }
    @objc private func displayFrame(_ driver: CADisplayLink) {
        let timestamp = driver.targetTimestamp
        let elapsed = lastTimestamp.map { max(0, timestamp - $0) } ?? max(1 / 120, driver.duration)
        lastTimestamp = timestamp
        width.advance(elapsed); height.advance(elapsed); progress.advance(elapsed)
        if width.isSettled() && height.isSettled() && progress.isSettled(position: 0.001, speed: 0.01) {
            width.settle(); height.settle(); progress.settle()
            stopMotion()
            canvas = targetFrame
            window?.setFrame(canvas, display: false)
            arrangeHosts()
        }
        render()
        if !isAnimating { onSettled?() }
    }
    private func render() {
        let w = max(1, width.value), h = max(1, height.value)
        switch edge {
        case .notch:
            presentedFrame = CGRect(x: expandedFrame.midX - w / 2, y: expandedFrame.maxY - h, width: w, height: h)
        case .leftDrawer:
            presentedFrame = CGRect(x: expandedFrame.minX, y: expandedFrame.midY - h / 2, width: w, height: h)
        case .drawer:
            presentedFrame = CGRect(x: expandedFrame.maxX - w, y: expandedFrame.midY - h / 2, width: w, height: h)
        }
        let reveal = LiquidShape.reveal(progress.value)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        surfaceMask.frame = bounds
        surfaceMask.path = LiquidShape.path(in: local(presentedFrame), edge: edge, progress: progress.value)
        expandedHost.isHidden = reveal <= 0
        compactHost.isHidden = reveal >= 1
        expandedHost.layer?.opacity = Float(reveal)
        compactHost.layer?.opacity = Float(1 - min(1, reveal * 2.5))
        // Small translations keep console glyphs at their native scale throughout the reveal.
        expandedHost.layer?.transform = CATransform3DMakeTranslation(edge == .notch ? 0 : (edge == .leftDrawer ? -20 : 20) * (1 - reveal),
                                                                   edge == .notch ? 9 * (1 - reveal) : 0, 0)
        CATransaction.commit()
        // Detached hosting views retain their UI state without rendering hidden terminal output.
        if !isAnimating && progress.target == 0 && progress.value == 0 { expandedHost.removeFromSuperview() }
        updatePointerPassThrough()
    }
    public func containsScreenPoint(_ point: CGPoint) -> Bool {
        guard initialized else { return false }
        return surfaceMask.path?.contains(CGPoint(x: point.x - canvas.minX, y: point.y - canvas.minY)) == true
    }
    public func updatePointerPassThrough() {
        let ignore = !containsScreenPoint(NSEvent.mouseLocation)
        if window?.ignoresMouseEvents != ignore { window?.ignoresMouseEvents = ignore }
    }
    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard surfaceMask.path?.contains(point) == true else { return nil }
        return super.hitTest(point)
    }
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area); tracking = area
    }
    public override func mouseEntered(with event: NSEvent) {
        if containsScreenPoint(NSEvent.mouseLocation) { onPointerEntered?() }
    }
}
