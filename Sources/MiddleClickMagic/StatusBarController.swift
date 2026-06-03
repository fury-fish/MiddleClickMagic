import AppKit

final class StatusBarController: NSObject {
    var onToggleWideArea: (() -> Void)?
    var onToggleRunAtLogin: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem: NSStatusItem
    private var wideAreaEnabled = false
    private var runAtLoginEnabled = false

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.image = Self.makeMenuBarIcon()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "MiddleClickMagic"
        rebuildMenu()
    }

    func update(wideAreaEnabled: Bool, runAtLoginEnabled: Bool) {
        self.wideAreaEnabled = wideAreaEnabled
        self.runAtLoginEnabled = runAtLoginEnabled
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let wideAreaItem = NSMenuItem(
            title: "Wide area middle click",
            action: #selector(toggleWideArea),
            keyEquivalent: ""
        )
        wideAreaItem.target = self
        wideAreaItem.state = wideAreaEnabled ? .on : .off
        menu.addItem(wideAreaItem)

        let runAtLoginItem = NSMenuItem(
            title: "Run at Login",
            action: #selector(toggleRunAtLogin),
            keyEquivalent: ""
        )
        runAtLoginItem.target = self
        runAtLoginItem.state = runAtLoginEnabled ? .on : .off
        menu.addItem(runAtLoginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    @objc private func toggleWideArea() {
        onToggleWideArea?()
    }

    @objc private func toggleRunAtLogin() {
        onToggleRunAtLogin?()
    }

    @objc private func quit() {
        onQuit?()
    }

    private static func makeMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.black.setStroke()
        NSColor.black.setFill()

        let mouseRect = NSRect(x: 5.0, y: 1.8, width: 8.0, height: 14.4)
        let mousePath = NSBezierPath(roundedRect: mouseRect, xRadius: 4.0, yRadius: 4.0)
        mousePath.lineWidth = 1.6
        mousePath.stroke()

        let targetRect = NSRect(x: 7.0, y: 7.0, width: 4.0, height: 4.0)
        let targetPath = NSBezierPath(ovalIn: targetRect)
        targetPath.lineWidth = 1.4
        targetPath.stroke()

        let dotRect = NSRect(x: 8.35, y: 8.35, width: 1.3, height: 1.3)
        NSBezierPath(ovalIn: dotRect).fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
