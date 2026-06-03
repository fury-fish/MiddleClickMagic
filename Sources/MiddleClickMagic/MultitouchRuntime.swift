import Darwin
import Foundation
import MiddleClickMagicCore

private let multitouchFrameworkPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
private let mtContactStride = 96
private let mtNormalizedXOffset = 32
private let mtNormalizedYOffset = 36

private typealias MTDeviceRef = UnsafeMutableRawPointer
private typealias MTContactFrameCallback = @convention(c) (
    MTDeviceRef?,
    UnsafeMutableRawPointer?,
    Int32,
    Double,
    Int32
) -> Int32

private typealias MTDeviceCreateListFunction = @convention(c) () -> Unmanaged<CFArray>?
private typealias MTRegisterContactFrameCallbackFunction = @convention(c) (MTDeviceRef?, MTContactFrameCallback?) -> Void
private typealias MTUnregisterContactFrameCallbackFunction = @convention(c) (MTDeviceRef?, MTContactFrameCallback?) -> Void
private typealias MTDeviceStartFunction = @convention(c) (MTDeviceRef?, Int32) -> Int32
private typealias MTDeviceStopFunction = @convention(c) (MTDeviceRef?) -> Int32
private typealias MTDeviceIsBuiltInFunction = @convention(c) (MTDeviceRef?) -> Int32
private typealias MTContactIsActiveFunction = @convention(c) (UnsafeMutableRawPointer?) -> Int32

private var activeTouchTracker: MagicMouseTouchTracker?

private let mtContactFrameCallback: MTContactFrameCallback = { device, contacts, contactCount, timestamp, frame in
    activeTouchTracker?.handleContactFrame(
        device: device,
        contacts: contacts,
        contactCount: contactCount,
        timestamp: timestamp,
        frame: frame
    )
    return 0
}

enum MultitouchRuntimeError: Error, CustomStringConvertible {
    case frameworkUnavailable(String)
    case symbolUnavailable(String)
    case noDeviceList
    case noEligibleDevices

    var description: String {
        switch self {
        case .frameworkUnavailable(let message):
            return "Could not load MultitouchSupport.framework: \(message)"
        case .symbolUnavailable(let symbol):
            return "Missing MultitouchSupport symbol: \(symbol)"
        case .noDeviceList:
            return "MultitouchSupport did not return a device list."
        case .noEligibleDevices:
            return "No external multitouch device was found. Connect a Magic Mouse, or run with --include-built-in to test on a built-in trackpad."
        }
    }
}

final class MultitouchSupportRuntime {
    private let handle: UnsafeMutableRawPointer

    fileprivate let createDeviceList: MTDeviceCreateListFunction
    fileprivate let registerContactFrameCallback: MTRegisterContactFrameCallbackFunction
    fileprivate let unregisterContactFrameCallback: MTUnregisterContactFrameCallbackFunction
    fileprivate let startDevice: MTDeviceStartFunction
    fileprivate let stopDevice: MTDeviceStopFunction
    fileprivate let isDeviceBuiltIn: MTDeviceIsBuiltInFunction?
    fileprivate let isContactActive: MTContactIsActiveFunction?

    init() throws {
        guard let handle = dlopen(multitouchFrameworkPath, RTLD_NOW) else {
            let message = String(cString: dlerror())
            throw MultitouchRuntimeError.frameworkUnavailable(message)
        }

        self.handle = handle
        createDeviceList = try Self.loadSymbol("MTDeviceCreateList", from: handle)
        registerContactFrameCallback = try Self.loadSymbol("MTRegisterContactFrameCallback", from: handle)
        unregisterContactFrameCallback = try Self.loadSymbol("MTUnregisterContactFrameCallback", from: handle)
        startDevice = try Self.loadSymbol("MTDeviceStart", from: handle)
        stopDevice = try Self.loadSymbol("MTDeviceStop", from: handle)
        isDeviceBuiltIn = Self.loadOptionalSymbol("MTDeviceIsBuiltIn", from: handle)
        isContactActive = Self.loadOptionalSymbol("MTContact_isActive", from: handle)
    }

    deinit {
        dlclose(handle)
    }

    private static func loadSymbol<T>(_ name: String, from handle: UnsafeMutableRawPointer) throws -> T {
        guard let symbol = dlsym(handle, name) else {
            throw MultitouchRuntimeError.symbolUnavailable(name)
        }

        return unsafeBitCast(symbol, to: T.self)
    }

    private static func loadOptionalSymbol<T>(_ name: String, from handle: UnsafeMutableRawPointer) -> T? {
        guard let symbol = dlsym(handle, name) else {
            return nil
        }

        return unsafeBitCast(symbol, to: T.self)
    }
}

final class MagicMouseTouchTracker {
    private var settings: MiddleClickSettings
    private var detector: MiddleClickDetector
    private let runtime: MultitouchSupportRuntime
    private let lock = NSLock()

    private var deviceList: CFArray?
    private var registeredDevices: [MTDeviceRef] = []
    private var latestTouches: [TouchSample] = []
    private var lastDebugPrintUptime: TimeInterval = 0
    private var lastFrameLogUptime: TimeInterval = 0

    init(settings: MiddleClickSettings) throws {
        self.settings = settings
        detector = MiddleClickDetector(settings: settings)
        runtime = try MultitouchSupportRuntime()
    }

    func start() throws {
        guard let list = runtime.createDeviceList()?.takeRetainedValue() else {
            throw MultitouchRuntimeError.noDeviceList
        }

        deviceList = list
        activeTouchTracker = self

        let count = CFArrayGetCount(list)
        AppLogger.log("Multitouch device list count: \(count)")
        for index in 0..<count {
            guard let value = CFArrayGetValueAtIndex(list, index) else {
                continue
            }

            let device = MTDeviceRef(mutating: value)
            let builtIn = runtime.isDeviceBuiltIn?(device) != 0
            guard settings.includeBuiltInDevices || !builtIn else {
                debugPrint("Skipping built-in multitouch device #\(index).")
                AppLogger.log("Skipping built-in multitouch device #\(index)")
                continue
            }

            runtime.registerContactFrameCallback(device, mtContactFrameCallback)
            _ = runtime.startDevice(device, 0)
            registeredDevices.append(device)
            debugPrint("Listening to multitouch device #\(index), built-in: \(builtIn).")
            AppLogger.log("Listening to multitouch device #\(index), built-in: \(builtIn)")
        }

        guard !registeredDevices.isEmpty else {
            activeTouchTracker = nil
            AppLogger.log("No eligible multitouch devices")
            throw MultitouchRuntimeError.noEligibleDevices
        }
    }

    func stop() {
        for device in registeredDevices {
            runtime.unregisterContactFrameCallback(device, mtContactFrameCallback)
            _ = runtime.stopDevice(device)
        }

        registeredDevices.removeAll()
        activeTouchTracker = nil
    }

    func shouldConvertToMiddleClick(now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        lock.lock()
        let touches = latestTouches
        lock.unlock()

        return detector.shouldConvertToMiddleClick(touches: touches, now: now)
    }

    func latestFreshTouch(now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> TouchSample? {
        lock.lock()
        let touches = latestTouches
        lock.unlock()

        return touches.first { now - $0.capturedAtUptime <= settings.maxTouchAge }
    }

    func updateSettings(_ settings: MiddleClickSettings) {
        lock.lock()
        self.settings = settings
        detector = MiddleClickDetector(settings: settings)
        lock.unlock()
    }

    fileprivate func handleContactFrame(
        device: MTDeviceRef?,
        contacts: UnsafeMutableRawPointer?,
        contactCount: Int32,
        timestamp: Double,
        frame: Int32
    ) {
        guard let contacts, contactCount > 0 else {
            lock.lock()
            latestTouches = []
            lock.unlock()
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        var samples: [TouchSample] = []
        samples.reserveCapacity(Int(contactCount))

        for offset in 0..<Int(contactCount) {
            let contact = contacts.advanced(by: offset * mtContactStride)
            if let isContactActive = runtime.isContactActive, isContactActive(contact) == 0 {
                continue
            }

            let x = Double(contact.load(fromByteOffset: mtNormalizedXOffset, as: Float.self))
            let y = Double(contact.load(fromByteOffset: mtNormalizedYOffset, as: Float.self))

            guard x.isFinite, y.isFinite, abs(x) <= 1.25, abs(y) <= 1.25 else {
                continue
            }

            samples.append(TouchSample(x: x, y: y, capturedAtUptime: now))
        }

        lock.lock()
        latestTouches = samples
        lock.unlock()

        logTouchSamples(samples, frame: frame, now: now)
        debugTouchSamples(samples, timestamp: timestamp, frame: frame, now: now)
    }

    private func logTouchSamples(_ samples: [TouchSample], frame: Int32, now: TimeInterval) {
        guard now - lastFrameLogUptime > 1.0 else {
            return
        }

        lastFrameLogUptime = now
        let formatted = samples
            .map { String(format: "(%.3f, %.3f)", $0.x, $0.y) }
            .joined(separator: " ")
        AppLogger.log("Touch frame \(frame), count: \(samples.count), samples: \(formatted)")
    }

    private func debugTouchSamples(_ samples: [TouchSample], timestamp: Double, frame: Int32, now: TimeInterval) {
        guard settings.debug, now - lastDebugPrintUptime > 0.35 else {
            return
        }

        lastDebugPrintUptime = now
        let formatted = samples
            .map { String(format: "(%.3f, %.3f)", $0.x, $0.y) }
            .joined(separator: " ")
        Swift.print("touch frame \(frame) ts \(String(format: "%.3f", timestamp)): \(formatted)")
    }

    private func debugPrint(_ message: String) {
        guard settings.debug else {
            return
        }

        Swift.print(message)
    }
}
