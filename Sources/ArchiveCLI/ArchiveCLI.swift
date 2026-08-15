import Foundation
import ArchiveCore
import ArchiveBackends

public enum CLICommand: String, Sendable {
    case list, inspect, extract, create, test, formats, help
}

public struct CLIOptions: Sendable {
    public var command: CLICommand
    public var archive: URL?
    public var destination: URL?
    public var sources: [URL]
    public var format: ArchiveFormat
    public var password: String?
    public var json: Bool
    public var quiet: Bool
    public var overwrite: OverwritePolicy
    public var selected: [String]

    public init(
        command: CLICommand,
        archive: URL? = nil,
        destination: URL? = nil,
        sources: [URL] = [],
        format: ArchiveFormat = .zip,
        password: String? = nil,
        json: Bool = false,
        quiet: Bool = false,
        overwrite: OverwritePolicy = .neverReplace,
        selected: [String] = []
    ) {
        self.command = command
        self.archive = archive
        self.destination = destination
        self.sources = sources
        self.format = format
        self.password = password
        self.json = json
        self.quiet = quiet
        self.overwrite = overwrite
        self.selected = selected
    }
}

public enum CLIParser {
    public static func parse(_ arguments: [String]) throws -> CLIOptions {
        let args = Array(arguments.dropFirst())
        if args.isEmpty { return CLIOptions(command: .help) }
        let commandName = args[0].lowercased()
        if commandName == "-h" || commandName == "--help" { return CLIOptions(command: .help) }
        guard let command = CLICommand(rawValue: commandName) else {
            throw ArchiveError.invalidArguments("Unknown command: \(args[0])")
        }
        var archive: URL?
        var destination: URL?
        var sources: [URL] = []
        var format: ArchiveFormat = .zip
        var password: String?
        var json = false
        var quiet = false
        var overwrite = OverwritePolicy.neverReplace
        var selected: [String] = []
        var positional: [String] = []
        var index = 1
        while index < args.count {
            let arg = args[index]
            switch arg {
            case "--json": json = true
            case "--quiet", "-q": quiet = true
            case "--password", "-p":
                index += 1
                guard index < args.count else { throw ArchiveError.invalidArguments("Missing password value") }
                password = args[index]
            case "--format":
                index += 1
                guard index < args.count else { throw ArchiveError.invalidArguments("Missing format value") }
                format = parseFormat(args[index])
            case "--overwrite":
                index += 1
                guard index < args.count else { throw ArchiveError.invalidArguments("Missing overwrite value") }
                overwrite = OverwritePolicy(rawValue: args[index]) ?? .neverReplace
            case "--include":
                index += 1
                guard index < args.count else { throw ArchiveError.invalidArguments("Missing include value") }
                selected.append(args[index])
            case "-h", "--help":
                return CLIOptions(command: .help)
            default:
                if arg.hasPrefix("-") {
                    throw ArchiveError.invalidArguments("Unknown option: \(arg)")
                }
                positional.append(arg)
            }
            index += 1
        }
        switch command {
        case .list, .inspect, .test:
            guard let first = positional.first else { throw ArchiveError.invalidArguments("Missing archive path") }
            archive = URL(fileURLWithPath: first)
        case .extract:
            guard positional.count >= 2 else { throw ArchiveError.invalidArguments("Usage: extract ARCHIVE DEST") }
            archive = URL(fileURLWithPath: positional[0])
            destination = URL(fileURLWithPath: positional[1])
        case .create:
            guard positional.count >= 2 else { throw ArchiveError.invalidArguments("Usage: create SOURCE... ARCHIVE") }
            archive = URL(fileURLWithPath: positional.last!)
            sources = positional.dropLast().map { URL(fileURLWithPath: $0) }
            destination = archive
            if format == .zip, let dest = destination {
                if let detected = FormatDetector.detectExtension(dest) {
                    format = detected
                }
            }
        case .formats, .help:
            break
        }
        return CLIOptions(
            command: command,
            archive: archive,
            destination: destination,
            sources: sources,
            format: format,
            password: password,
            json: json,
            quiet: quiet,
            overwrite: overwrite,
            selected: selected
        )
    }

    public static func parseFormat(_ raw: String) -> ArchiveFormat {
        let key = raw.lowercased().replacingOccurrences(of: ".", with: "")
        switch key {
        case "zip": return .zip
        case "7z", "7zip", "sevenzip": return .sevenZip
        case "tar": return .tar
        case "targz", "tgz": return .tarGz
        case "tarbz2", "tbz2", "tbz": return .tarBz2
        case "tarxz", "txz": return .tarXz
        case "tarzst", "tarzstd": return .tarZstd
        case "gz", "gzip": return .gzip
        case "bz2", "bzip2": return .bzip2
        case "xz": return .xz
        case "zst", "zstd": return .zstd
        case "lz4": return .lz4
        default: return .zip
        }
    }
}

public enum ArchiveCLIRunner {
    public static func run(arguments: [String], engine: ArchiveEngine = DefaultBackends.makeEngine()) async -> Int32 {
        do {
            let options = try CLIParser.parse(arguments)
            return try await execute(options, engine: engine)
        } catch let error as ArchiveError {
            fputs(error.userMessage + "\n", stderr)
            return error.exitCode
        } catch {
            fputs(error.localizedDescription + "\n", stderr)
            return 1
        }
    }

    public static func execute(_ options: CLIOptions, engine: ArchiveEngine) async throws -> Int32 {
        switch options.command {
        case .help:
            print(helpText)
            return 0
        case .formats:
            print(formatsText)
            return 0
        case .inspect:
            let info = try await engine.inspect(options.archive!, password: options.password)
            if options.json {
                printJSON(info)
            } else if !options.quiet {
                print("Format: \(info.format.displayName)")
                print("Entries: \(info.entryCount)")
                print("Uncompressed: \(ByteCountFormat.string(from: info.totalUncompressedSize))")
                print("Compressed: \(ByteCountFormat.string(from: info.compressedSize))")
                print("Encrypted: \(info.isEncrypted ? "yes" : "no")")
                if !info.warnings.isEmpty {
                    print("Warnings: \(info.warnings.joined(separator: "; "))")
                }
            }
            return 0
        case .list:
            let entries = try await engine.list(options.archive!, password: options.password)
            if options.json {
                printJSON(entries)
            } else if !options.quiet {
                for entry in entries {
                    let size = ByteCountFormat.string(from: entry.uncompressedSize)
                    print("\(entry.isDirectory ? "D" : "F")\t\(size)\t\(entry.path)")
                }
            }
            return 0
        case .extract:
            var extractOptions = ExtractionOptions(
                selectedPaths: Set(options.selected),
                extractAll: options.selected.isEmpty,
                overwrite: options.overwrite,
                password: options.password
            )
            if options.overwrite == .ask {
                extractOptions.overwrite = .neverReplace
            }
            try await engine.extract(options.archive!, to: options.destination!, options: extractOptions) { snapshot in
                if !options.quiet && !options.json {
                    fputs("\r\(snapshot.percentText) \(snapshot.bytesText) \(snapshot.speedText)    ", stderr)
                }
            }
            if !options.quiet { fputs("\n", stderr) }
            return 0
        case .create:
            let compression = CompressionOptions(format: options.format, password: options.password)
            try await engine.create(from: options.sources, destination: options.destination!, options: compression) { snapshot in
                if !options.quiet && !options.json {
                    fputs("\r\(snapshot.percentText) \(snapshot.bytesText) \(snapshot.speedText)    ", stderr)
                }
            }
            if !options.quiet { fputs("\n", stderr) }
            return 0
        case .test:
            let result = try await engine.test(options.archive!, password: options.password)
            if options.json {
                printJSON(result)
            } else if !options.quiet {
                print(result.userMessage)
                for warning in result.warnings { print("Warning: \(warning)") }
                for error in result.errors { print("Error: \(error)") }
            }
            return result.status == .ok || result.status == .warnings ? 0 : 3
        }
    }

    public static let helpText = """
    archivemgr — Archivist command-line interface

    Usage:
      archivemgr list ARCHIVE
      archivemgr inspect ARCHIVE
      archivemgr extract ARCHIVE DEST
      archivemgr create SOURCE... ARCHIVE [--format zip|7z|tar|tar.gz|...]
      archivemgr test ARCHIVE
      archivemgr formats

    Options:
      --password, -p   Archive password (not logged)
      --json           Machine-readable output on stdout
      --quiet, -q      Suppress progress
      --overwrite      neverReplace | alwaysReplace | replaceIfNewer | renameAutomatically
      --include        Extract only this entry (repeatable)
      --format         Creation format

    Exit codes:
      0 success
      1 general error
      2 invalid arguments
      3 archive corrupted
      4 wrong password
      5 missing volume
      6 unsupported format
      7 permission error
      8 disk space error
      9 cancelled
    """

    public static let formatsText = """
    Create: ZIP, 7Z, TAR, TAR.GZ, TAR.BZ2, TAR.XZ, TAR.ZST, GZ, BZ2, XZ, LZMA, ZSTD, LZ4
    Extract: those plus RAR/RAR5 (UnRAR helper), CAB, ISO, CPIO, AR, XAR, ZIP containers, WIM/MSI (7-Zip helper), DMG (hdiutil)
    RAR creation is not supported.
    """

    private static func printJSON<T: Encodable>(_ value: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(value), let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
