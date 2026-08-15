import Foundation
import ArchiveCore

public final class SevenZipBackend: ArchiveBackend, Sendable {
    public let kind: BackendKind = .sevenZipHelper
    private let log = ArchiveLogger(category: .backend)

    public let supportedFormats: Set<ArchiveFormat> = [
        .sevenZip, .zip, .zipx, .tar, .wim, .msi, .cab, .iso, .gzip, .bzip2, .xz, .lzma, .zstd, .lz4,
        .rar, .rar5,
    ]

    public init() {}

    public var isAvailable: Bool { HelperLocator.find(names: ["Archivist7z", "7zz", "7z"]) != nil }

    public func capabilities(for format: ArchiveFormat) -> FormatCapabilities {
        FormatCatalog.capabilities(format, sevenZipAvailable: isAvailable, unrarAvailable: false)
    }

    public func inspect(_ source: URL, password: String?) async throws -> ArchiveInfo {
        let entries = try await listAll(source, password: password)
        let encrypted = entries.contains(where: \.isEncrypted)
        let total = entries.reduce(UInt64(0)) { $0 + $1.uncompressedSize }
        let compressed = UInt64((try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        let detection = FormatDetector.detect(url: source)
        return ArchiveInfo(
            format: detection.format,
            backend: .sevenZipHelper,
            capabilities: capabilities(for: detection.format),
            entryCount: UInt64(entries.count),
            totalUncompressedSize: total,
            compressedSize: compressed,
            isEncrypted: encrypted
        )
    }

    public func listContents(_ source: URL, password: String?) -> AsyncThrowingStream<ArchiveEntry, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for entry in try await self.listAll(source, password: password) {
                        continuation.yield(entry)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func extract(
        _ source: URL,
        to destination: URL,
        options: ExtractionOptions,
        progress: @escaping ProgressHandler
    ) async throws {
        let exe = try executable()
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        var args = ["x", "-y", "-bb1", "-bsp1", "-o\(destination.path)", source.path]
        if let password = options.password, !password.isEmpty {
            args.insert("-p\(password)", at: 1)
        }
        if !options.extractAll {
            args.append(contentsOf: options.selectedPaths.sorted())
        }
        let engine = ProgressEngine()
        progress(engine.snapshot(completedBytes: 0, totalBytes: nil, isIndeterminate: true))
        let result = try HelperRunner.run(executable: exe, arguments: args)
        try mapExit(result)
        progress(engine.snapshot(completedBytes: 1, totalBytes: 1))
    }

    public func create(
        from sources: [URL],
        destination: URL,
        options: CompressionOptions,
        progress: @escaping ProgressHandler
    ) async throws {
        if options.format == .rar || options.format == .rar5 {
            throw ArchiveError.formatNotCreatable(options.format)
        }
        let exe = try executable()
        let parent = destination.deletingLastPathComponent()
        let temp = AtomicFile.uniqueTemporaryURL(in: parent, name: destination.lastPathComponent)
        var args = ["a", "-y", "-bb1"]
        args.append(typeFlag(options.format))
        args.append("-mx=\(max(0, options.level.numericLevel))")
        if let password = options.password, !password.isEmpty {
            args.append("-p\(password)")
            if options.encryptFilenames, options.format == .sevenZip {
                args.append("-mhe=on")
            }
        }
        if let bytes = options.split.bytes, bytes > 0 {
            args.append("-v\(bytes)b")
        }
        args.append(temp.path)
        args.append(contentsOf: sources.map(\.path))
        let engine = ProgressEngine()
        progress(engine.snapshot(completedBytes: 0, totalBytes: nil, isIndeterminate: true))
        let result = try HelperRunner.run(executable: exe, arguments: args)
        try mapExit(result)
        if options.split.bytes != nil {
            // 7-Zip writes temp.001 etc. Move the first volume into place if needed.
            let first = URL(fileURLWithPath: temp.path + ".001")
            if FileManager.default.fileExists(atPath: first.path) {
                let destFirst = URL(fileURLWithPath: destination.path + ".001")
                try AtomicFile.replace(original: destFirst, withTemporary: first)
            } else {
                try AtomicFile.replace(original: destination, withTemporary: temp)
            }
        } else {
            try AtomicFile.replace(original: destination, withTemporary: temp)
        }
        progress(engine.snapshot(completedBytes: 1, totalBytes: 1))
    }

    public func test(
        _ source: URL,
        password: String?,
        progress: @escaping ProgressHandler
    ) async throws -> ArchiveIntegrityResult {
        let exe = try executable()
        var args = ["t", "-bb1", source.path]
        if let password, !password.isEmpty {
            args.insert("-p\(password)", at: 1)
        }
        progress(ProgressEngine().snapshot(completedBytes: 0, totalBytes: nil, isIndeterminate: true))
        let result = try HelperRunner.run(executable: exe, arguments: args)
        if result.exitCode == 2 {
            let lower = (result.stdout + result.stderr).lowercased()
            if lower.contains("wrong password") || lower.contains("cannot open encrypted") {
                return ArchiveIntegrityResult(status: .wrongPassword)
            }
            return ArchiveIntegrityResult(status: .corrupted, errors: [ArchiveError.redact(result.stderr)])
        }
        if result.exitCode != 0 {
            return ArchiveIntegrityResult(status: .warnings, warnings: [ArchiveError.redact(result.stderr)])
        }
        return ArchiveIntegrityResult(status: .ok)
    }

    private func listAll(_ source: URL, password: String?) async throws -> [ArchiveEntry] {
        let exe = try executable()
        var args = ["l", "-slt", "-ba", source.path]
        if let password, !password.isEmpty {
            args.insert("-p\(password)", at: 1)
        }
        let result = try HelperRunner.run(executable: exe, arguments: args)
        try mapExit(result)
        return parseTechnicalList(result.stdout)
    }

    private func parseTechnicalList(_ text: String) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        var current: [String: String] = [:]
        func flush() {
            guard let path = current["Path"], !path.isEmpty else {
                current.removeAll()
                return
            }
            let folder = (current["Folder"] ?? current["Attributes"] ?? "").contains("D")
            let size = UInt64(current["Size"] ?? "0") ?? 0
            let packed = UInt64(current["Packed Size"] ?? current["PackedSize"] ?? "")
            let encrypted = (current["Encrypted"] ?? "").contains("+")
            var modified: Date?
            if let mtime = current["Modified"] {
                modified = SevenZipBackend.dateParser.date(from: mtime)
            }
            entries.append(
                ArchiveEntry(
                    path: path,
                    kind: folder ? .directory : .file,
                    uncompressedSize: size,
                    compressedSize: packed,
                    modified: modified,
                    isEncrypted: encrypted,
                    compressionMethod: current["Method"]
                )
            )
            current.removeAll()
        }
        for line in text.split(whereSeparator: \.isNewline) {
            let raw = String(line)
            if raw.trimmingCharacters(in: .whitespaces).isEmpty {
                flush()
                continue
            }
            if let eq = raw.firstIndex(of: "=") {
                let key = String(raw[..<eq]).trimmingCharacters(in: .whitespaces)
                let value = String(raw[raw.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
                current[key] = value
            }
        }
        flush()
        return entries
    }

    private func executable() throws -> URL {
        guard let url = HelperLocator.find(names: ["Archivist7z", "7zz", "7z"]) else {
            throw ArchiveError.helperMissing("7-Zip (Archivist7z / 7zz)")
        }
        return url
    }

    private func typeFlag(_ format: ArchiveFormat) -> String {
        switch format {
        case .sevenZip: return "-t7z"
        case .zip, .zipx: return "-tzip"
        case .tar: return "-ttar"
        case .wim: return "-twim"
        case .gzip: return "-tgzip"
        case .bzip2: return "-tbzip2"
        case .xz: return "-txz"
        case .lzma: return "-tlzma"
        case .iso: return "-tiso"
        default: return "-t7z"
        }
    }

    private func mapExit(_ result: HelperResult) throws {
        if result.exitCode == 0 { return }
        let blob = (result.stdout + "\n" + result.stderr)
        let lower = blob.lowercased()
        if lower.contains("wrong password") { throw ArchiveError.incorrectPassword }
        if result.exitCode == 255 { throw ArchiveError.cancelled }
        throw ArchiveError.fromBackendMessage(ArchiveError.redact(blob))
    }

    private static let dateParser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
}

