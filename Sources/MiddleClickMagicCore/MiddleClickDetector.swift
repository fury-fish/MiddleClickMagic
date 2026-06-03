import Foundation

public struct MiddleClickSettings: Equatable {
    public static let defaultCenterWidth = 0.24
    public static let wideCenterWidth = 0.38

    public var centerWidth: Double
    public var centerX: Double
    public var maxTouchAge: TimeInterval
    public var includeBuiltInDevices: Bool
    public var debug: Bool

    public init(
        centerWidth: Double = MiddleClickSettings.defaultCenterWidth,
        centerX: Double = 0.5,
        maxTouchAge: TimeInterval = 0.35,
        includeBuiltInDevices: Bool = false,
        debug: Bool = false
    ) {
        self.centerWidth = centerWidth
        self.centerX = centerX
        self.maxTouchAge = maxTouchAge
        self.includeBuiltInDevices = includeBuiltInDevices
        self.debug = debug
    }
}

public struct TouchSample: Equatable {
    public var x: Double
    public var y: Double
    public var capturedAtUptime: TimeInterval

    public init(x: Double, y: Double, capturedAtUptime: TimeInterval) {
        self.x = x
        self.y = y
        self.capturedAtUptime = capturedAtUptime
    }
}

public struct MiddleClickDetector {
    public var settings: MiddleClickSettings

    public init(settings: MiddleClickSettings = MiddleClickSettings()) {
        self.settings = settings
    }

    public func shouldConvertToMiddleClick(touches: [TouchSample], now: TimeInterval) -> Bool {
        touches.contains { touch in
            now - touch.capturedAtUptime <= settings.maxTouchAge
                && isInMiddleZone(x: touch.x, y: touch.y)
        }
    }

    public func isInMiddleZone(x: Double, y: Double) -> Bool {
        guard x.isFinite, y.isFinite else {
            return false
        }

        if (0.0...1.0).contains(x), (0.0...1.0).contains(y) {
            let halfWidth = settings.centerWidth / 2.0
            return abs(x - settings.centerX) <= halfWidth
        }

        if (-1.0...1.0).contains(x), (-1.0...1.0).contains(y) {
            return abs(x) <= settings.centerWidth
        }

        return false
    }
}
