import Foundation
import MiddleClickMagicCore

struct CLIOptions {
    var settings = MiddleClickSettings()
    var showHelp = false
    var centerWidthProvided = false
    var wideAreaEnabled: Bool?
    var launchAgentAction: LaunchAgentAction?
}

enum LaunchAgentAction {
    case install
    case uninstall
    case status
}

enum CLIOptionsError: Error, CustomStringConvertible {
    case missingValue(String)
    case invalidNumber(option: String, value: String)
    case unknownOption(String)

    var description: String {
        switch self {
        case .missingValue(let option):
            return "Missing value for \(option)."
        case .invalidNumber(let option, let value):
            return "Invalid number for \(option): \(value)."
        case .unknownOption(let option):
            return "Unknown option: \(option)."
        }
    }
}

enum CLIOptionsParser {
    static let helpText = """
    MiddleClickMagic

    Convert a physical Magic Mouse click in the center zone into a middle-click.

    Usage:
      MiddleClickMagic [options]

    Options:
      -h, --help                 Show this help.
      --debug                    Print touch samples and converted clicks.
      --include-built-in         Also listen to built-in trackpads.
      --wide-area                Use a wider middle-click area.
      --center-width <value>     Center zone width, normalized. Default: 0.24.
      --max-touch-age <seconds>  Max age of the last touch sample. Default: 0.35.
      --install-launch-agent     Run this tool at login.
      --uninstall-launch-agent   Stop running this tool at login.
      --launch-agent-status      Print whether run-at-login is enabled.

    Notes:
      The app needs macOS Accessibility permission.
      It uses Apple's private MultitouchSupport.framework, so macOS updates can break it.
    """

    static func parse(_ arguments: [String]) throws -> CLIOptions {
        var options = CLIOptions()
        var index = 1

        while index < arguments.count {
            let argument = arguments[index]

            switch argument {
            case "-h", "--help":
                options.showHelp = true
            case "--debug":
                options.settings.debug = true
            case "--include-built-in":
                options.settings.includeBuiltInDevices = true
            case "--wide-area":
                options.wideAreaEnabled = true
                options.settings.centerWidth = MiddleClickSettings.wideCenterWidth
            case "--center-width":
                let value = try value(after: argument, arguments: arguments, index: &index)
                options.settings.centerWidth = try parseDouble(value, option: argument)
                options.centerWidthProvided = true
            case "--max-touch-age":
                let value = try value(after: argument, arguments: arguments, index: &index)
                options.settings.maxTouchAge = try parseDouble(value, option: argument)
            case "--install-launch-agent":
                options.launchAgentAction = .install
            case "--uninstall-launch-agent":
                options.launchAgentAction = .uninstall
            case "--launch-agent-status":
                options.launchAgentAction = .status
            default:
                if argument.hasPrefix("--center-width=") {
                    let value = String(argument.dropFirst("--center-width=".count))
                    options.settings.centerWidth = try parseDouble(value, option: "--center-width")
                    options.centerWidthProvided = true
                } else if argument.hasPrefix("--max-touch-age=") {
                    let value = String(argument.dropFirst("--max-touch-age=".count))
                    options.settings.maxTouchAge = try parseDouble(value, option: "--max-touch-age")
                } else {
                    throw CLIOptionsError.unknownOption(argument)
                }
            }

            index += 1
        }

        return options
    }

    private static func value(after option: String, arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw CLIOptionsError.missingValue(option)
        }

        index = valueIndex
        return arguments[valueIndex]
    }

    private static func parseDouble(_ value: String, option: String) throws -> Double {
        guard let number = Double(value), number.isFinite, number > 0 else {
            throw CLIOptionsError.invalidNumber(option: option, value: value)
        }

        return number
    }
}
