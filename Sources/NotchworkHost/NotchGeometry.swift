import CoreGraphics

/// Keep the resting surface tied to the hardware; content size only affects the open surface.
struct NotchGeometry {
    let housing: CGFloat
    let topHeight: CGFloat
    let wing: CGFloat
    let compact: CGRect
    let expanded: CGRect

    init(screen: CGRect, safeTop: CGFloat, leftArea: CGRect?, rightArea: CGRect?,
         hasActivity: Bool, singlePresentation: Bool) {
        let gap = leftArea.flatMap { left in rightArea.map { $0.minX - left.maxX } } ?? 0
        let hasNotch = safeTop > 0 && gap > 0
        housing = hasNotch ? gap : 0
        topHeight = hasNotch ? safeTop : 28
        wing = hasNotch && !hasActivity ? 2 : 28
        let center = hasNotch ? leftArea!.maxX + housing / 2 : screen.midX
        let width = housing + wing * 2
        let height = topHeight + (hasNotch ? 2 : 0)
        compact = CGRect(x: center - width / 2, y: screen.maxY - height, width: width, height: height)
        // Both frames share an anchor so the morph never slides away from the camera.
        let availableWidth = max(width, 2 * min(center - screen.minX, screen.maxX - center) - 24)
        let expandedWidth = max(width, min(singlePresentation ? 560 : 920, availableWidth))
        let expandedHeight = min(480, screen.height - 24)
        expanded = CGRect(x: center - expandedWidth / 2, y: screen.maxY - expandedHeight,
                          width: expandedWidth, height: expandedHeight)
    }
}
