import ApplicationServices
import CoreGraphics
import Foundation
import MiddleClickMagicCore

enum MiddleClickEventTapError: Error, CustomStringConvertible {
    case accessibilityNotGranted
    case eventTapCreationFailed
    case runLoopSourceCreationFailed

    var description: String {
        switch self {
        case .accessibilityNotGranted:
            return "Accessibility permission is not granted yet."
        case .eventTapCreationFailed:
            return "Could not create the mouse event tap. Check Accessibility permission and restart the tool."
        case .runLoopSourceCreationFailed:
            return "Could not create a run loop source for the mouse event tap."
        }
    }
}

private let middleClickEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let tap = Unmanaged<MiddleClickEventTap>.fromOpaque(userInfo).takeUnretainedValue()
    return tap.handle(type: type, event: event)
}

final class MiddleClickEventTap {
    var onCalibrationTouch: ((TouchSample) -> Void)?

    private let touchTracker: MagicMouseTouchTracker
    private var settings: MiddleClickSettings
    private let eventSource = CGEventSource(stateID: .hidSystemState)

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isConvertingClick = false
    private var isCalibrationArmed = false
    private var lastMouseLogUptime: TimeInterval = 0

    init(touchTracker: MagicMouseTouchTracker, settings: MiddleClickSettings) {
        self.touchTracker = touchTracker
        self.settings = settings
    }

    static func accessibilityTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func postTestMiddleClick() {
        let source = CGEventSource(stateID: .hidSystemState)
        let location = CGEvent(source: source)?.location ?? CGPoint.zero

        for type in [CGEventType.otherMouseDown, CGEventType.otherMouseUp] {
            guard let event = CGEvent(
                mouseEventSource: source,
                mouseType: type,
                mouseCursorPosition: location,
                mouseButton: .center
            ) else {
                continue
            }

            event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(CGMouseButton.center.rawValue))
            event.post(tap: .cghidEventTap)
        }
    }

    func start() throws {
        AppLogger.log("Accessibility trusted: \(Self.accessibilityTrusted(prompt: false))")
        guard Self.accessibilityTrusted(prompt: true) else {
            throw MiddleClickEventTapError.accessibilityNotGranted
        }

        let mask = eventMask([
            .leftMouseDown,
            .leftMouseUp,
            .leftMouseDragged,
            .rightMouseDown,
            .rightMouseUp,
            .rightMouseDragged,
        ])

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: middleClickEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw MiddleClickEventTapError.eventTapCreationFailed
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            throw MiddleClickEventTapError.runLoopSourceCreationFailed
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        AppLogger.log("Mouse event tap started")
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        runLoopSource = nil
        eventTap = nil
        isConvertingClick = false
    }

    func updateSettings(_ settings: MiddleClickSettings) {
        self.settings = settings
    }

    func armCalibration() {
        isCalibrationArmed = true
        AppLogger.log("Calibration armed for next click")
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            AppLogger.log("Mouse event tap disabled by system: \(type.rawValue). Re-enabling.")
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            isConvertingClick = false
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .leftMouseDown, .rightMouseDown:
            if isCalibrationArmed, let touch = touchTracker.latestFreshTouch() {
                isCalibrationArmed = false
                onCalibrationTouch?(touch)
                isConvertingClick = true
                AppLogger.log(String(format: "Calibration click captured at touch (%.3f, %.3f)", touch.x, touch.y))
                postMiddleEvent(matching: event, type: .otherMouseDown)
                return nil
            }

            let shouldConvert = touchTracker.shouldConvertToMiddleClick()
            logMouseEvent(type: type, shouldConvert: shouldConvert, location: event.location)
            if shouldConvert {
                isConvertingClick = true
                debugPrint("middle down at \(format(location: event.location))")
                postMiddleEvent(matching: event, type: .otherMouseDown)
                return nil
            }

            isConvertingClick = false
            return Unmanaged.passUnretained(event)

        case .leftMouseDragged, .rightMouseDragged:
            guard isConvertingClick else {
                return Unmanaged.passUnretained(event)
            }

            postMiddleEvent(matching: event, type: .otherMouseDragged)
            return nil

        case .leftMouseUp, .rightMouseUp:
            guard isConvertingClick else {
                return Unmanaged.passUnretained(event)
            }

            isConvertingClick = false
            debugPrint("middle up at \(format(location: event.location))")
            postMiddleEvent(matching: event, type: .otherMouseUp)
            return nil

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func postMiddleEvent(matching originalEvent: CGEvent, type: CGEventType) {
        guard let middleEvent = CGEvent(
            mouseEventSource: eventSource,
            mouseType: type,
            mouseCursorPosition: originalEvent.location,
            mouseButton: .center
        ) else {
            return
        }

        middleEvent.flags = originalEvent.flags
        middleEvent.setIntegerValueField(.mouseEventButtonNumber, value: Int64(CGMouseButton.center.rawValue))
        middleEvent.post(tap: .cghidEventTap)
        AppLogger.log("Posted middle event type \(type.rawValue) at \(format(location: originalEvent.location))")
    }

    private func logMouseEvent(type: CGEventType, shouldConvert: Bool, location: CGPoint) {
        let now = ProcessInfo.processInfo.systemUptime
        guard shouldConvert || now - lastMouseLogUptime > 0.5 else {
            return
        }

        lastMouseLogUptime = now
        AppLogger.log("Mouse event type \(type.rawValue) at \(format(location: location)); shouldConvert=\(shouldConvert)")
    }

    private func debugPrint(_ message: String) {
        guard settings.debug else {
            return
        }

        Swift.print(message)
    }

    private func format(location: CGPoint) -> String {
        String(format: "%.0f, %.0f", location.x, location.y)
    }
}

private func eventMask(_ eventTypes: [CGEventType]) -> CGEventMask {
    eventTypes.reduce(CGEventMask(0)) { mask, type in
        mask | (CGEventMask(1) << Int(type.rawValue))
    }
}
