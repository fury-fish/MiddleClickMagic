import AppKit
import MiddleClickMagicCore

final class MiddleClickAppDelegate: NSObject, NSApplicationDelegate {
    private var settings: MiddleClickSettings
    private var wideAreaEnabled: Bool
    private let launchAgentManager = LaunchAgentManager()

    private var statusBarController: StatusBarController?
    private var touchTracker: MagicMouseTouchTracker?
    private var eventTap: MiddleClickEventTap?
    private var runtimeStatus = "Starting"

    init(options: CLIOptions) {
        settings = options.settings

        if let wideAreaEnabled = options.wideAreaEnabled {
            self.wideAreaEnabled = wideAreaEnabled
        } else if options.centerWidthProvided {
            self.wideAreaEnabled = false
        } else {
            self.wideAreaEnabled = AppPreferences.wideAreaMiddleClickEnabled
        }

        if self.wideAreaEnabled {
            settings.centerWidth = MiddleClickSettings.wideCenterWidth
        }

        if let centerX = AppPreferences.middleClickCenterX {
            settings.centerX = centerX
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppLogger.log("Application launched: \(Bundle.main.bundlePath)")

        let controller = StatusBarController()
        controller.onToggleWideArea = { [weak self] in self?.toggleWideArea() }
        controller.onToggleRunAtLogin = { [weak self] in self?.toggleRunAtLogin() }
        controller.onQuit = { NSApp.terminate(nil) }
        statusBarController = controller

        startRuntime()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopRuntime()
    }

    func startRuntime() {
        stopRuntime()
        AppLogger.log("Starting runtime with centerX=\(settings.centerX), centerWidth=\(settings.centerWidth), maxTouchAge=\(settings.maxTouchAge)")

        do {
            let tracker = try MagicMouseTouchTracker(settings: settings)
            try tracker.start()

            let tap = MiddleClickEventTap(touchTracker: tracker, settings: settings)
            tap.onCalibrationTouch = { [weak self] touch in
                self?.applyCalibratedCenterX(touch.x)
            }
            do {
                try tap.start()
            } catch {
                tracker.stop()
                throw error
            }

            touchTracker = tracker
            eventTap = tap
            runtimeStatus = "Running"
            AppLogger.log("Runtime status: Running")
        } catch MiddleClickEventTapError.accessibilityNotGranted {
            runtimeStatus = "Accessibility permission needed"
            AppLogger.log("Runtime status: Accessibility permission needed")
        } catch MultitouchRuntimeError.noEligibleDevices {
            runtimeStatus = "No Magic Mouse found"
            AppLogger.log("Runtime status: No Magic Mouse found")
        } catch {
            runtimeStatus = "Error: \(error)"
            AppLogger.log("Runtime status error: \(error)")
        }

        refreshStatusMenu()
    }

    private func applyCalibratedCenterX(_ centerX: Double, persist: Bool = true) {
        settings.centerX = centerX
        if persist {
            AppPreferences.middleClickCenterX = centerX
        }

        touchTracker?.updateSettings(settings)
        eventTap?.updateSettings(settings)
        runtimeStatus = "Running"
        AppLogger.log(String(format: "Middle calibration applied: centerX=%.3f", centerX))
        refreshStatusMenu()
    }

    private func stopRuntime() {
        eventTap?.stop()
        touchTracker?.stop()
        eventTap = nil
        touchTracker = nil
    }

    private func toggleWideArea() {
        wideAreaEnabled.toggle()
        AppPreferences.wideAreaMiddleClickEnabled = wideAreaEnabled
        settings.centerWidth = wideAreaEnabled
            ? MiddleClickSettings.wideCenterWidth
            : MiddleClickSettings.defaultCenterWidth

        touchTracker?.updateSettings(settings)
        eventTap?.updateSettings(settings)
        refreshStatusMenu()
    }

    private func toggleRunAtLogin() {
        do {
            if launchAgentManager.isEnabled {
                try launchAgentManager.uninstall()
            } else {
                try launchAgentManager.install()
            }
            runtimeStatus = touchTracker == nil ? runtimeStatus : "Running"
        } catch {
            runtimeStatus = "Run at Login error: \(error)"
        }

        refreshStatusMenu()
    }

    private func refreshStatusMenu() {
        statusBarController?.update(
            wideAreaEnabled: wideAreaEnabled,
            runAtLoginEnabled: launchAgentManager.isEnabled
        )
    }
}
