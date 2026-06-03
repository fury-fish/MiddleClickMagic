import AppKit
import Foundation

@main
struct MiddleClickMagic {
    static func main() {
        do {
            let options = try CLIOptionsParser.parse(CommandLine.arguments)
            if options.showHelp {
                print(CLIOptionsParser.helpText)
                return
            }

            if let action = options.launchAgentAction {
                try handleLaunchAgentAction(action)
                return
            }

            let app = NSApplication.shared
            let delegate = MiddleClickAppDelegate(options: options)
            app.delegate = delegate
            app.run()
        } catch {
            fputs("MiddleClickMagic error: \(error)\n", stderr)
            fputs("Run with --help for usage.\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    private static func handleLaunchAgentAction(_ action: LaunchAgentAction) throws {
        let manager = LaunchAgentManager()
        switch action {
        case .install:
            try manager.install()
            print("Run at Login enabled.")
        case .uninstall:
            try manager.uninstall()
            print("Run at Login disabled.")
        case .status:
            print(manager.isEnabled ? "Run at Login enabled." : "Run at Login disabled.")
        }
    }
}
