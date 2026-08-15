import Foundation
import ArchiveCore

public enum HelperLocator {
    public static func find(names: [String], bundledFolder: String = "Helpers") -> URL? {
        var candidates: [URL] = []
        let bundle = Bundle.main.bundleURL
        let helpers = bundle.appendingPathComponent("Contents", isDirectory: true).appendingPathComponent(bundledFolder, isDirectory: true)
        for name in names {
            candidates.append(helpers.appendingPathComponent(name))
        }
        let exeDir = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.deletingLastPathComponent()
        for name in names {
            candidates.append(exeDir.appendingPathComponent(name))
            candidates.append(exeDir.appendingPathComponent("Helpers").appendingPathComponent(name))
        }
        let extras = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
        for dir in extras {
            for name in names {
                candidates.append(URL(fileURLWithPath: dir).appendingPathComponent(name))
            }
        }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}

public struct HelperResult: Sendable {
    public var exitCode: Int32
    public var stdout: String
    public var stderr: String
}

public enum HelperRunner {
    public static func run(
        executable: URL,
        arguments: [String],
        extraEnvironment: [String: String] = [:],
        onStderrLine: (@Sendable (String) -> Void)? = nil
    ) throws -> HelperResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(extraEnvironment) { _, new in new }
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if let onStderrLine {
            for line in stderr.split(separator: "\n") {
                onStderrLine(String(line))
            }
        }
        return HelperResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}
