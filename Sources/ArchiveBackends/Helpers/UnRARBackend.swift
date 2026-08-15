import Foundation
import ArchiveCore

public final class UnRARBackend: ArchiveBackend, Sendable {
    public let kind: BackendKind = .unrarHelper

    public let supportedFormats: Set<ArchiveFormat> = [.rar, .rar5]

    public init() {}

    public var isAvailable: Bool { HelperLocator.find(names: ["ArchivistUnrar", "unrar"]) != nil }

    public func capabilities(for format: ArchiveFormat) -> FormatCapabilities {
        FormatCatalog.capabilities(format, sevenZipAvailable: false, unrarAvailable: isAvailable)
    }

    public func inspect(_ source: URL, password: String?) async throws -> ArchiveInfo {
        let entries = try await listAll(source, password: password)
        let total = entries.reduce(UInt64(0)) { $0 + $1.uncompressedSize }
        let compressed = UInt64((try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        let detection = FormatDetector.detect(url: source)
        return ArchiveInfo(
            format: detection.format == .rar5 ? .rar5 : .rar,
            backend: .unrarHelper,
            capabilities: capabilities(for: detection.format),
            entryCount: UInt64(entries.count),
            totalUncompressedSize: total,
            compressedSize: compressed,
            isEncrypted: entries.contains(where: \.isEncrypted)
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
        var args = ["x", "-o+", "-y"]
        if let password = options.password, !password.isEmpty {
            args.append("-p\(password)")
        } else {
            args.append("-p-")
        }
        args.append(source.path)
        if !options.extractAll {
            args.append(contentsOf: options.selectedPaths.sorted())
        }
        args.append(destination.path.hasSuffix("/") ? destination.path : destination.path + "/")
        let result = try HelperRunner.run(executable: exe, arguments: args)
        try mapExit(result)
        progress(ProgressEngine().snapshot(completedBytes: 1, totalBytes: 1))
    }

    public func create(
        from sources: [URL],
        destination: URL,
        options: CompressionOptions,
        progress: @escaping ProgressHandler
    ) async throws {
        throw ArchiveError.formatNotCreatable(.rar)
    }

    public func test(
        _ source: URL,
        password: String?,
        progress: @escaping ProgressHandler
    ) async throws -> ArchiveIntegrityResult {
        let exe = try executable()
        var args = ["t", "-y"]
        if let password, !password.isEmpty {
            args.append("-p\(password)")
        } else {
            args.append("-p-")
        }
        args.append(source.path)
        let result = try HelperRunner.run(executable: exe, arguments: args)
        let blob = (result.stdout + result.stderr).lowercased()
        if blob.contains("wrong password") || blob.contains("incorrect password") {
            return ArchiveIntegrityResult(status: .wrongPassword)
        }
        if result.exitCode != 0 {
            if blob.contains("crc") { return ArchiveIntegrityResult(status: .crcMismatch) }
            if blob.contains("missing volume") || blob.contains("cannot find volume") {
                return ArchiveIntegrityResult(status: .missingVolume)
            }
            return ArchiveIntegrityResult(status: .corrupted, errors: [ArchiveError.redact(result.stderr)])
        }
        return ArchiveIntegrityResult(status: .ok)
    }

    private func listAll(_ source: URL, password: String?) async throws -> [ArchiveEntry] {
        let exe = try executable()
        var args = ["vt", "-y"]
        if let password, !password.isEmpty {
            args.append("-p\(password)")
        } else {
            args.append("-p-")
        }
        args.append(source.path)
        let result = try HelperRunner.run(executable: exe, arguments: args)
        try mapExit(result)
        return parseVerbose(result.stdout)
    }

    private func parseVerbose(_ text: String) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        var name: String?
        var size: UInt64 = 0
        var packed: UInt64?
        var encrypted = false
        var isDir = false
        func flush() {
            guard let name else { return }
            entries.append(
                ArchiveEntry(
                    path: name,
                    kind: isDir ? .directory : .file,
                    uncompressedSize: size,
                    compressedSize: packed,
                    isEncrypted: encrypted
                )
            )
        }
        for line in text.split(whereSeparator: \.isNewline) {
            let raw = String(line).trimmingCharacters(in: .whitespaces)
            if raw.lowercased().hasPrefix("name:") {
                flush()
                name = String(raw.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                size = 0
                packed = nil
                encrypted = false
                isDir = false
            } else if raw.lowercased().hasPrefix("size:") {
                size = UInt64(raw.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
            } else if raw.lowercased().hasPrefix("packed size:") || raw.lowercased().hasPrefix("packed:") {
                packed = UInt64(raw.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? "")
            } else if raw.lowercased().contains("encrypted") && raw.lowercased().contains("yes") {
                encrypted = true
            } else if raw.lowercased().hasPrefix("type:") && raw.lowercased().contains("directory") {
                isDir = true
            }
        }
        flush()
        return entries
    }

    private func executable() throws -> URL {
        guard let url = HelperLocator.find(names: ["ArchivistUnrar", "unrar"]) else {
            throw ArchiveError.helperMissing("UnRAR (ArchivistUnrar / unrar)")
        }
        return url
    }

    private func mapExit(_ result: HelperResult) throws {
        if result.exitCode == 0 { return }
        let blob = (result.stdout + "\n" + result.stderr)
        let lower = blob.lowercased()
        if lower.contains("wrong password") || lower.contains("incorrect password") {
            throw ArchiveError.incorrectPassword
        }
        if lower.contains("cannot find volume") || lower.contains("missing volume") {
            throw ArchiveError.missingVolume(ArchiveError.redact(blob))
        }
        throw ArchiveError.fromBackendMessage(ArchiveError.redact(blob))
    }
}
