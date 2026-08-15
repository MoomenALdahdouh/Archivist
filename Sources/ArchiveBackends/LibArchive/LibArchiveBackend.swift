import Foundation
import ArchiveCore
import CLibArchive

public final class LibArchiveBackend: ArchiveBackend, Sendable {
    public let kind: BackendKind = .libarchive
    private let log = ArchiveLogger(category: .backend)

    public let supportedFormats: Set<ArchiveFormat> = [
        .zip, .zipx, .sevenZip, .rar, .rar5,
        .tar, .tarGz, .tarBz2, .tarXz, .tarZstd, .tarLz4, .pax, .cpgz,
        .gzip, .bzip2, .xz, .lzma, .lzip, .compressZ, .zstd, .lz4,
        .cab, .iso, .cpio, .ar, .xar,
        .jar, .war, .ear, .apk, .ipa, .xpi, .appx, .xip,
    ]

    public init() {}

    public func capabilities(for format: ArchiveFormat) -> FormatCapabilities {
        FormatCatalog.capabilities(format, sevenZipAvailable: false, unrarAvailable: false)
    }

    public func inspect(_ source: URL, password: String?) async throws -> ArchiveInfo {
        try Task.checkCancellation()
        let detection = FormatDetector.detect(url: source)
        if detection.format.isSingleFileCompression {
            let compressed = UInt64((try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            return ArchiveInfo(
                format: detection.format,
                backend: .libarchive,
                capabilities: capabilities(for: detection.format),
                entryCount: 1,
                totalUncompressedSize: 0,
                compressedSize: compressed
            )
        }
        var entryCount: UInt64 = 0
        var total: UInt64 = 0
        var encrypted = false
        var warnings: [String] = []
        var formatName = detection.format.displayName
        try enumerate(source, password: password, skipData: true) { archive, entry, item in
            entryCount += 1
            total += item.uncompressedSize
            if item.isEncrypted { encrypted = true }
            formatName = LibArchiveFormatMap.readFormatName(archive)
            if entryCount > 50_000_000 {
                throw ArchiveError.safetyLimitExceeded("Excessive entry count")
            }
        }
        let compressed = UInt64((try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        if encrypted && (detection.format == .sevenZip || detection.format == .rar || detection.format == .rar5) {
            warnings.append("libarchive cannot decrypt this format; use the 7-Zip or UnRAR helper.")
        }
        return ArchiveInfo(
            format: detection.format == .unknown ? mapFormatName(formatName) : detection.format,
            formatName: formatName,
            backend: .libarchive,
            capabilities: capabilities(for: detection.format),
            entryCount: entryCount,
            totalUncompressedSize: total,
            compressedSize: compressed,
            isEncrypted: encrypted,
            warnings: warnings
        )
    }

    public func listContents(_ source: URL, password: String?) -> AsyncThrowingStream<ArchiveEntry, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.enumerate(source, password: password, skipData: true) { _, _, entry in
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
        let detection = FormatDetector.detect(url: source)
        if detection.format.isSingleFileCompression {
            try extractSingleFile(source, to: destination, format: detection.format, progress: progress)
            return
        }
        let guardrail = ExtractionGuard(limits: options.safety)
        let engine = ProgressEngine()
        var written: UInt64 = 0
        var files: UInt64 = 0
        let info = try await inspect(source, password: options.password)
        let total = info.totalUncompressedSize
        try await enumerate(source, password: options.password, skipData: false) { archive, entryPtr, entry in
            try Task.checkCancellation()
            guard options.includes(path: entry.path) else {
                _ = archive_read_data_skip(archive)
                return
            }
            let relative: String
            if options.preserveFolders {
                relative = try guardrail.validatedRelativePath(entry.path)
            } else {
                relative = (try guardrail.validatedRelativePath(entry.path) as NSString).lastPathComponent
            }
            if relative.isEmpty && entry.kind == .directory { return }
            let outputURL = try guardrail.resolvedURL(entryPath: relative, destination: destination)

            switch entry.kind {
            case .directory:
                try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
                try applyMetadata(outputURL, entry: entry, options: options)
            case .symbolicLink:
                guard options.preserveSymlinks, let target = entry.symlinkTarget else {
                    _ = archive_read_data_skip(archive)
                    return
                }
                try guardrail.validateSymlinkTarget(target, linkURL: outputURL, destination: destination)
                try prepareOutput(outputURL, options: options)
                try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.createSymbolicLink(atPath: outputURL.path, withDestinationPath: target)
            case .file, .hardLink, .other:
                if entry.kind == .other {
                    _ = archive_read_data_skip(archive)
                    return
                }
                try prepareOutput(outputURL, options: options)
                try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                FileManager.default.createFile(atPath: outputURL.path, contents: nil)
                let handle = try FileHandle(forWritingTo: outputURL)
                defer { try? handle.close() }
                try copyData(from: archive, to: handle) { chunk in
                    written += chunk
                    files = max(files, UInt64(1))
                    progress(engine.snapshot(completedBytes: written, totalBytes: total == 0 ? nil : total, currentItem: entry.path))
                }
                try applyMetadata(outputURL, entry: entry, options: options)
                files += 1
                try guardrail.checkCounts(files: files, bytes: written)
            }
        }
        progress(engine.snapshot(completedBytes: written, totalBytes: total == 0 ? written : total))
    }

    public func create(
        from sources: [URL],
        destination: URL,
        options: CompressionOptions,
        progress: @escaping ProgressHandler
    ) async throws {
        if options.format.isSingleFileCompression {
            try await createSingleFile(from: sources, destination: destination, options: options, progress: progress)
            return
        }
        let walker = FileTreeWalker(followSymlinks: options.followSymlinks)
        let items = try walker.walk(sources)
        let total = walker.totalBytes(items)
        let parent = destination.deletingLastPathComponent()
        let temp = AtomicFile.uniqueTemporaryURL(in: parent, name: destination.lastPathComponent)
        let engine = ProgressEngine()
        var written: UInt64 = 0

        let archive = archive_write_new()
        guard let archive else { throw ArchiveError.backendFailure("archive_write_new failed") }
        defer { archive_write_free(archive) }
        try LibArchiveFormatMap.write(archive: archive, format: options.format, level: options.level)
        if let password = options.password, !password.isEmpty {
            if options.format == .zip {
                try LibArchive.check(archive_write_set_passphrase(archive, password), archive)
                _ = archive_write_set_format_option(archive, "zip", "encryption", "zipcrypto")
            } else if options.format == .sevenZip {
                throw ArchiveError.backendFailure("Encrypted 7Z creation requires the 7-Zip helper.")
            }
        }
        try LibArchive.withPath(temp) { path in
            try LibArchive.check(archive_write_open_filename(archive, path), archive)
        }
        defer { archive_write_close(archive) }

        for item in items {
            try Task.checkCancellation()
            let entry = archive_entry_new()
            guard let entry else { throw ArchiveError.backendFailure("archive_entry_new failed") }
            defer { archive_entry_free(entry) }
            archive_entry_set_pathname_utf8(entry, item.relativePath)
            if item.isDirectory {
                archive_entry_set_filetype(entry, LibArchive.aeIFDIR)
                archive_entry_set_perm(entry, 0o755)
                archive_entry_set_size(entry, 0)
                try LibArchive.check(archive_write_header(archive, entry), archive)
                continue
            }
            if item.isSymlink && options.preserveSymlinks {
                let target = try FileManager.default.destinationOfSymbolicLink(atPath: item.url.path)
                archive_entry_set_filetype(entry, LibArchive.aeIFLNK)
                archive_entry_set_symlink_utf8(entry, target)
                archive_entry_set_perm(entry, 0o755)
                archive_entry_set_size(entry, 0)
                try LibArchive.check(archive_write_header(archive, entry), archive)
                continue
            }
            archive_entry_set_filetype(entry, LibArchive.aeIFREG)
            archive_entry_set_size(entry, Int64(clamping: item.size))
            if options.preservePermissions {
                let attrs = try FileManager.default.attributesOfItem(atPath: item.url.path)
                if let perm = attrs[.posixPermissions] as? NSNumber {
                    archive_entry_set_perm(entry, perm.uint16Value)
                } else {
                    archive_entry_set_perm(entry, 0o644)
                }
            } else {
                archive_entry_set_perm(entry, 0o644)
            }
            if options.preserveTimestamps {
                let attrs = try FileManager.default.attributesOfItem(atPath: item.url.path)
                if let date = attrs[.modificationDate] as? Date {
                    archive_entry_set_mtime(entry, time_t(date.timeIntervalSince1970), 0)
                }
            }
            try LibArchive.check(archive_write_header(archive, entry), archive)
            if item.size > 0 {
                let handle = try FileHandle(forReadingFrom: item.url)
                defer { try? handle.close() }
                while true {
                    try Task.checkCancellation()
                    let chunk = try handle.read(upToCount: 64 * 1024) ?? Data()
                    if chunk.isEmpty { break }
                    let wrote = chunk.withUnsafeBytes { ptr -> Int in
                        guard let base = ptr.bindMemory(to: UInt8.self).baseAddress else { return -1 }
                        return archive_write_data(archive, base, chunk.count)
                    }
                    if wrote < 0 { throw ArchiveError.fromBackendMessage(LibArchive.string(archive_error_string(archive)) ?? "write failed") }
                    written += UInt64(chunk.count)
                    progress(engine.snapshot(completedBytes: written, totalBytes: total, currentItem: item.relativePath))
                }
            }
        }
        try LibArchive.check(archive_write_close(archive), archive)
        try AtomicFile.replace(original: destination, withTemporary: temp)
        progress(engine.snapshot(completedBytes: total, totalBytes: total))
    }

    public func test(
        _ source: URL,
        password: String?,
        progress: @escaping ProgressHandler
    ) async throws -> ArchiveIntegrityResult {
        let engine = ProgressEngine()
        var tested: UInt64 = 0
        var bytes: UInt64 = 0
        var warnings: [String] = []
        do {
            try await enumerate(source, password: password, skipData: false) { archive, _, entry in
                try Task.checkCancellation()
                var buffer = [UInt8](repeating: 0, count: 64 * 1024)
                while true {
                    let n = archive_read_data(archive, &buffer, buffer.count)
                    if n == 0 { break }
                    if n < 0 {
                        throw ArchiveError.fromBackendMessage(LibArchive.string(archive_error_string(archive)) ?? "read failed")
                    }
                    bytes += UInt64(n)
                }
                tested += 1
                progress(engine.snapshot(completedBytes: bytes, totalBytes: nil, currentItem: entry.path, itemsCompleted: tested, isIndeterminate: true))
            }
            return ArchiveIntegrityResult(status: warnings.isEmpty ? .ok : .warnings, testedEntries: tested, warnings: warnings)
        } catch ArchiveError.incorrectPassword {
            return ArchiveIntegrityResult(status: .wrongPassword, testedEntries: tested)
        } catch ArchiveError.unexpectedEnd {
            return ArchiveIntegrityResult(status: .corrupted, testedEntries: tested, errors: ["Unexpected end of archive"])
        } catch {
            return ArchiveIntegrityResult(status: .corrupted, testedEntries: tested, errors: [error.localizedDescription])
        }
    }

    // MARK: - Internals

    private func extractSingleFile(
        _ source: URL,
        to destination: URL,
        format: ArchiveFormat,
        progress: @escaping ProgressHandler
    ) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        var outName = source.deletingPathExtension().lastPathComponent
        if outName.isEmpty { outName = "extracted" }
        let output = destination.appendingPathComponent(outName)
        let tool: URL
        let args: [String]
        switch format {
        case .gzip:
            tool = URL(fileURLWithPath: "/usr/bin/gzip")
            args = ["-dc", source.path]
        case .bzip2:
            tool = URL(fileURLWithPath: "/usr/bin/bzip2")
            args = ["-dc", source.path]
        default:
            // Fall back to libarchive streaming into the output file.
            let archive = archive_read_new()
            guard let archive else { throw ArchiveError.backendFailure("archive_read_new failed") }
            defer { archive_read_free(archive) }
            archive_read_support_filter_all(archive)
            archive_read_support_format_raw(archive)
            try LibArchive.withPath(source) { path in
                try LibArchive.check(archive_read_open_filename(archive, path, 65_536), archive)
            }
            var entry: OpaquePointer?
            try LibArchive.check(archive_read_next_header(archive, &entry), archive)
            FileManager.default.createFile(atPath: output.path, contents: nil)
            let handle = try FileHandle(forWritingTo: output)
            defer { try? handle.close() }
            try copyData(from: archive, to: handle) { _ in }
            progress(ProgressEngine().snapshot(completedBytes: 1, totalBytes: 1))
            return
        }
        let process = Process()
        process.executableURL = tool
        process.arguments = args
        FileManager.default.createFile(atPath: output.path, contents: nil)
        let outHandle = try FileHandle(forWritingTo: output)
        process.standardOutput = outHandle
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        try outHandle.close()
        if process.terminationStatus != 0 {
            throw ArchiveError.corrupted("Single-file decompress failed")
        }
        progress(ProgressEngine().snapshot(completedBytes: 1, totalBytes: 1))
    }

    private func enumerate(
        _ source: URL,
        password: String?,
        skipData: Bool,
        body: (OpaquePointer, OpaquePointer, ArchiveEntry) throws -> Void
    ) throws {
        let archive = archive_read_new()
        guard let archive else { throw ArchiveError.backendFailure("archive_read_new failed") }
        defer { archive_read_free(archive) }
        archive_read_support_filter_all(archive)
        archive_read_support_format_all(archive)
        if let password, !password.isEmpty {
            archive_read_add_passphrase(archive, password)
        }
        try LibArchive.withPath(source) { path in
            try LibArchive.check(archive_read_open_filename(archive, path, 65_536), archive)
        }
        while true {
            try Task.checkCancellation()
            var entry: OpaquePointer?
            let status = archive_read_next_header(archive, &entry)
            if status == LibArchive.eof { break }
            try LibArchive.check(status, archive)
            guard let entry else { continue }
            let item = makeEntry(entry)
            try body(archive, entry, item)
            if skipData {
                _ = archive_read_data_skip(archive)
            }
        }
    }

    private func makeEntry(_ entry: OpaquePointer) -> ArchiveEntry {
        let rawPath = LibArchive.string(archive_entry_pathname_utf8(entry))
            ?? LibArchive.string(archive_entry_pathname(entry))
            ?? "unnamed"
        let filetype = UInt32(archive_entry_filetype(entry))
        let kind: ArchiveEntryKind
        if filetype == LibArchive.aeIFDIR {
            kind = .directory
        } else if filetype == LibArchive.aeIFLNK {
            kind = .symbolicLink
        } else {
            kind = .file
        }
        let size: UInt64 = archive_entry_size_is_set(entry) != 0 ? UInt64(max(0, archive_entry_size(entry))) : 0
        var modified: Date?
        if archive_entry_mtime_is_set(entry) != 0 {
            modified = Date(timeIntervalSince1970: TimeInterval(archive_entry_mtime(entry)))
        }
        let perm: UInt16? = archive_entry_perm_is_set(entry) != 0 ? UInt16(archive_entry_perm(entry)) : nil
        let encrypted = archive_entry_is_encrypted(entry) != 0
        let symlink = LibArchive.string(archive_entry_symlink_utf8(entry)) ?? LibArchive.string(archive_entry_symlink(entry))
        return ArchiveEntry(
            path: rawPath,
            kind: kind,
            uncompressedSize: size,
            modified: modified,
            posixPermissions: perm,
            isEncrypted: encrypted,
            symlinkTarget: symlink
        )
    }

    private func copyData(
        from archive: OpaquePointer,
        to handle: FileHandle,
        onChunk: (UInt64) throws -> Void
    ) throws {
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            try Task.checkCancellation()
            let n = archive_read_data(archive, &buffer, buffer.count)
            if n == 0 { break }
            if n < 0 {
                throw ArchiveError.fromBackendMessage(LibArchive.string(archive_error_string(archive)) ?? "read failed")
            }
            let count = Int(n)
            try handle.write(contentsOf: Data(buffer[0..<count]))
            try onChunk(UInt64(count))
        }
    }

    private func prepareOutput(_ url: URL, options: ExtractionOptions) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        switch options.overwrite {
        case .alwaysReplace:
            try fm.removeItem(at: url)
        case .neverReplace:
            throw ArchiveError.fileExists(url.path)
        case .replaceIfNewer:
            return
        case .renameAutomatically:
            break
        case .ask:
            throw ArchiveError.fileExists(url.path)
        }
    }

    private func applyMetadata(_ url: URL, entry: ArchiveEntry, options: ExtractionOptions) throws {
        var attrs: [FileAttributeKey: Any] = [:]
        if options.preserveTimestamps, let modified = entry.modified {
            attrs[.modificationDate] = modified
        }
        if options.preservePermissions, let perm = entry.posixPermissions {
            attrs[.posixPermissions] = perm
        }
        if !attrs.isEmpty {
            try FileManager.default.setAttributes(attrs, ofItemAtPath: url.path)
        }
    }

    private func createSingleFile(
        from sources: [URL],
        destination: URL,
        options: CompressionOptions,
        progress: @escaping ProgressHandler
    ) async throws {
        let files = sources.filter { url in
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            return !isDir.boolValue
        }
        guard files.count == 1 else {
            throw ArchiveError.invalidArguments("Single-file formats require exactly one file.")
        }
        try await create(from: files, destination: destination, options: options, progress: progress, forceRaw: true)
    }

    private func create(
        from sources: [URL],
        destination: URL,
        options: CompressionOptions,
        progress: @escaping ProgressHandler,
        forceRaw: Bool
    ) async throws {
        _ = forceRaw
        let walker = FileTreeWalker(followSymlinks: true)
        let items = try walker.walk(sources).filter { !$0.isDirectory }
        guard let item = items.first else {
            throw ArchiveError.invalidArguments("No file to compress.")
        }
        let parent = destination.deletingLastPathComponent()
        let temp = AtomicFile.uniqueTemporaryURL(in: parent, name: destination.lastPathComponent)
        let archive = archive_write_new()
        guard let archive else { throw ArchiveError.backendFailure("archive_write_new failed") }
        defer { archive_write_free(archive) }
        try LibArchiveFormatMap.write(archive: archive, format: options.format, level: options.level)
        try LibArchive.withPath(temp) { path in
            try LibArchive.check(archive_write_open_filename(archive, path), archive)
        }
        let entry = archive_entry_new()
        guard let entry else { throw ArchiveError.backendFailure("archive_entry_new failed") }
        defer { archive_entry_free(entry) }
        archive_entry_set_pathname_utf8(entry, item.relativePath)
        archive_entry_set_filetype(entry, LibArchive.aeIFREG)
        archive_entry_set_size(entry, Int64(clamping: item.size))
        archive_entry_set_perm(entry, 0o644)
        try LibArchive.check(archive_write_header(archive, entry), archive)
        let engine = ProgressEngine()
        var written: UInt64 = 0
        let handle = try FileHandle(forReadingFrom: item.url)
        defer { try? handle.close() }
        while true {
            try Task.checkCancellation()
            let chunk = try handle.read(upToCount: 64 * 1024) ?? Data()
            if chunk.isEmpty { break }
            let wrote = chunk.withUnsafeBytes { ptr -> Int in
                guard let base = ptr.bindMemory(to: UInt8.self).baseAddress else { return -1 }
                return archive_write_data(archive, base, chunk.count)
            }
            if wrote < 0 { throw ArchiveError.backendFailure("write failed") }
            written += UInt64(chunk.count)
            progress(engine.snapshot(completedBytes: written, totalBytes: item.size, currentItem: item.relativePath))
        }
        try LibArchive.check(archive_write_close(archive), archive)
        try AtomicFile.replace(original: destination, withTemporary: temp)
    }

    private func mapFormatName(_ name: String) -> ArchiveFormat {
        let lower = name.lowercased()
        if lower.contains("zip") { return .zip }
        if lower.contains("7z") || lower.contains("7-zip") { return .sevenZip }
        if lower.contains("rar5") { return .rar5 }
        if lower.contains("rar") { return .rar }
        if lower.contains("tar") { return .tar }
        if lower.contains("iso") { return .iso }
        if lower.contains("cab") { return .cab }
        if lower.contains("cpio") { return .cpio }
        if lower.contains("xar") { return .xar }
        return .unknown
    }
}

private struct SkipEntry: Error {}

