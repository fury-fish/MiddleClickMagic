import Foundation

enum LaunchAgentError: Error, CustomStringConvertible {
    case executablePathUnavailable

    var description: String {
        switch self {
        case .executablePathUnavailable:
            return "Could not determine the current executable path."
        }
    }
}

struct LaunchAgentManager {
    static let label = "com.middleclickmagic.agent"

    private var fileManager: FileManager { .default }

    var launchAgentURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(Self.label).plist")
    }

    var isEnabled: Bool {
        fileManager.fileExists(atPath: launchAgentURL.path)
    }

    func install() throws {
        let directory = launchAgentURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": Self.label,
            "ProgramArguments": [try executablePath()],
            "RunAtLoad": true,
            "KeepAlive": false,
            "StandardOutPath": logPath(name: "stdout.log"),
            "StandardErrorPath": logPath(name: "stderr.log"),
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: launchAgentURL, options: .atomic)
    }

    func uninstall() throws {
        guard isEnabled else {
            return
        }

        try fileManager.removeItem(at: launchAgentURL)
    }

    private func executablePath() throws -> String {
        if let path = Bundle.main.executableURL?.standardizedFileURL.path, fileManager.isExecutableFile(atPath: path) {
            return path
        }

        let argumentPath = CommandLine.arguments[0]
        let url: URL
        if argumentPath.hasPrefix("/") {
            url = URL(fileURLWithPath: argumentPath)
        } else {
            url = URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent(argumentPath)
        }

        let path = url.standardizedFileURL.path
        guard fileManager.isExecutableFile(atPath: path) else {
            throw LaunchAgentError.executablePathUnavailable
        }

        return path
    }

    private func logPath(name: String) -> String {
        logDirectoryURL
            .appendingPathComponent(name)
            .path
    }

    private var logDirectoryURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/MiddleClickMagic", isDirectory: true)
    }
}
