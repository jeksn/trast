import CoreGraphics

public enum LayoutEngine {
    public struct Request {
        public var usableArea: CGRect
        public var currentFrame: CGRect
        public var width: WindowDimension?
        public var height: WindowDimension?
        public var anchor: Anchor
        public var offsetX: WindowDimension
        public var offsetY: WindowDimension

        public init(
            usableArea: CGRect,
            currentFrame: CGRect,
            width: WindowDimension?,
            height: WindowDimension?,
            anchor: Anchor,
            offsetX: WindowDimension,
            offsetY: WindowDimension
        ) {
            self.usableArea = usableArea
            self.currentFrame = currentFrame
            self.width = width
            self.height = height
            self.anchor = anchor
            self.offsetX = offsetX
            self.offsetY = offsetY
        }
    }

    public static func frame(for request: Request) -> CGRect {
        let area = request.usableArea
        let width = max(0, resolve(request.width, axisLength: area.width, fallback: request.currentFrame.width))
        let height = max(0, resolve(request.height, axisLength: area.height, fallback: request.currentFrame.height))

        let baseX: CGFloat
        switch request.anchor.horizontal {
        case .left: baseX = area.minX
        case .center: baseX = area.midX - width / 2
        case .right: baseX = area.maxX - width
        case .keep: baseX = request.currentFrame.minX
        }

        let baseY: CGFloat
        switch request.anchor.vertical {
        case .top: baseY = area.maxY - height
        case .center: baseY = area.midY - height / 2
        case .bottom: baseY = area.minY
        case .keep: baseY = request.currentFrame.minY
        }

        let x = baseX + resolve(request.offsetX, axisLength: area.width, fallback: 0)
        let y = baseY - resolve(request.offsetY, axisLength: area.height, fallback: 0)

        return CGRect(x: x, y: y, width: width, height: height)
    }

    public static func usableArea(in visibleFrame: CGRect, gap: CGFloat) -> CGRect {
        guard gap > 0 else { return visibleFrame }
        return visibleFrame.insetBy(dx: gap, dy: gap)
    }

    public static func frameForNextDisplay(
        currentFrame: CGRect,
        currentUsable: CGRect,
        nextUsable: CGRect
    ) -> CGRect {
        guard currentUsable.width > 0, currentUsable.height > 0 else {
            return CGRect(x: nextUsable.minX, y: nextUsable.minY, width: currentFrame.width, height: currentFrame.height)
        }
        let relX = (currentFrame.minX - currentUsable.minX) / currentUsable.width
        let relY = (currentFrame.minY - currentUsable.minY) / currentUsable.height
        let newX = nextUsable.minX + relX * nextUsable.width
        let newY = nextUsable.minY + relY * nextUsable.height
        return CGRect(x: newX, y: newY, width: currentFrame.width, height: currentFrame.height)
    }

    private static func resolve(_ dimension: WindowDimension?, axisLength: CGFloat, fallback: CGFloat) -> CGFloat {
        switch dimension {
        case .percent(let value): return axisLength * value / 100
        case .points(let value): return value
        case nil: return fallback
        }
    }
}
