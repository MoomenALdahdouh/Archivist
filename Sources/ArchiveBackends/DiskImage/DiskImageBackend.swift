import Foundation
import ArchiveCore

/// DMG inspect/extract via `/usr/bin/hdiutil`. Creation of signed/compressed disk images is not advertised.
public final class DiskImageBackend: ArchiveBackend, Sendable {
    public let kind: BackendKind = .diskImage
    public let supportedFormats: Set<ArchiveFormat> = [.dmg]

    public init() {}

    public func capabilities(for format: ArchiveFormat) -> FormatCapabilities {
        FormatCatalog.capabilities(format, sevenZipAvailable: false, unrarAvailable: false)
    }

    public func inspect(_ source: URL, password: String?) async throws -> ArchiveInfo {
        _ = password
        let size = UInt64((try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        return ArchiveInfo(
            format: .dmg,
            backend: .diskImage,
            capabilities: capabilities(for: .dmg),
            entryCount: 1,
            totalUncompressedSize: size,
            compressedSize: size,
            warnings: ["DMG contents are exposed by attaching the image with hdiutil."]
        )
    }

    public func listContents(_ source: URL, password: String?) -> AsyncThrowingStream<ArchiveEntry, any Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(
                ArchiveEntry(path: source.lastPathComponent, kind: .file, uncompressedSize: 0)
            )
            continuation.finish()
        }
    }

    public func extract(
        _ source: URL,
        to destination: URL,
        options: ExtractionOptions,
        progress: @escaping ProgressHandler
    ) async throws {
        _ = options
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let mount = destination.appendingPathComponent(".archivist-dmg-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let attach = try HelperRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/hdiutil"),
            arguments: ["attach", source.path, "-nobrowse", "-readonly", "-mountpoint", mount.path]
        )
        if attach.exitCode != 0 {
            throw ArchiveError.fromBackendMessage(attach.stderr)
        }
        defer {
            _ = try? HelperRunner.run(
                executable: URL(fileURLWithPath: "/usr/bin/hdiutil"),
                arguments: ["detach", mount.path, "-force"]
            )
        }
        let contents = try FileManager.default.contentsOfDirectory(at: mount, includingPropertiesForKeys: nil)
        for item in contents {
            let dest = destination.appendingPathComponent(item.lastPathComponent)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: item, to: dest)
        }
        progress(ProgressEngine().snapshot(completedBytes: 1, totalBytes: 1))
    }

    public func create(
        from sources: [URL],
        destination: URL,
        options: CompressionOptions,
        progress: @escaping ProgressHandler
    ) async throws {
        throw ArchiveError.formatNotCreatable(.dmg)
    }

    public func test(
        _ source: URL,
        password: String?,
        progress: @escaping ProgressHandler
    ) async throws -> ArchiveIntegrityResult {
        _ = password
        let result = try HelperRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/hdiutil"),
            arguments: ["verify", source.path]
        )
        progress(ProgressEngine().snapshot(completedBytes: 1, totalBytes: 1))
        if result.exitCode == 0 {
            return ArchiveIntegrityResult(status: .ok)
        }
        return ArchiveIntegrityResult(status: .corrupted, errors: [ArchiveError.redact(result.stderr)])
    }
}
