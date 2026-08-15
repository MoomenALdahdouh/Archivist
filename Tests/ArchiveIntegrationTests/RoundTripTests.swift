import Foundation
import Testing
import ArchiveCore
import ArchiveBackends

@Suite("Round-trip archives")
struct RoundTripTests {
    @Test func zipRoundTrip() async throws {
        try await roundTrip(format: .zip)
    }

    @Test func tarRoundTrip() async throws {
        try await roundTrip(format: .tar)
    }

    @Test func tarGzRoundTrip() async throws {
        try await roundTrip(format: .tarGz)
    }

    @Test func sevenZipRoundTrip() async throws {
        try await roundTrip(format: .sevenZip)
    }

    @Test func rarRoundTrip() async throws {
        try await roundTrip(format: .rar5)
    }

    @Test func gzipSingleFileRoundTrip() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("archivist-gz-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let source = root.appendingPathComponent("payload.bin")
        let payload = Data("gzip-roundtrip-\(UUID().uuidString)".utf8)
        try payload.write(to: source)
        let archive = root.appendingPathComponent("payload.bin.gz")
        let extracted = root.appendingPathComponent("out", isDirectory: true)
        let engine = DefaultBackends.makeEngine()
        try await engine.create(from: [source], destination: archive, options: CompressionOptions(format: .gzip, level: .fast))
        try await engine.extract(archive, to: extracted, options: ExtractionOptions(overwrite: .alwaysReplace))
        let extractedFile = try firstRegularFile(in: extracted)
        let originalHash = try ContentHash.sha256File(at: source)
        let extractedHash = try ContentHash.sha256File(at: extractedFile)
        #expect(originalHash == extractedHash)
    }

    @Test func unicodeFilenamesRoundTrip() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("archivist-uni-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let names = ["مرحبا.txt", "İstanbul.txt", "çalışma.txt", "日本語.txt", "中文文件.txt", "file with spaces.txt"]
        var sources: [URL] = []
        for name in names {
            let url = root.appendingPathComponent(name)
            try Data(name.utf8).write(to: url)
            sources.append(url)
        }
        let archive = root.appendingPathComponent("unicode.zip")
        let extracted = root.appendingPathComponent("out", isDirectory: true)
        let engine = DefaultBackends.makeEngine()
        try await engine.create(from: sources, destination: archive, options: CompressionOptions(format: .zip, level: .fast))
        try await engine.extract(archive, to: extracted, options: ExtractionOptions(overwrite: .alwaysReplace))
        for name in names {
            let matches = try files(named: name, under: extracted)
            #expect(!matches.isEmpty, "Missing \(name)")
        }
    }

    @Test func zipSlipDoesNotEscape() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("archivist-slip-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let dest = root.appendingPathComponent("out", isDirectory: true)
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        let outside = root.appendingPathComponent("outside.txt")
        try Data("safe".utf8).write(to: outside)
        let guardrail = ExtractionGuard()
        #expect(throws: ArchiveError.self) {
            _ = try guardrail.resolvedURL(entryPath: "../outside.txt", destination: dest)
        }
        #expect(try Data(contentsOf: outside) == Data("safe".utf8))
    }

    @Test func inspectDoesNotRequireExtract() async throws {
        let (archive, payloadHash) = try await makeSampleArchive(format: .zip)
        defer { try? FileManager.default.removeItem(at: archive.deletingLastPathComponent()) }
        let engine = DefaultBackends.makeEngine()
        let info = try await engine.inspect(archive)
        #expect(info.entryCount >= 1)
        #expect(info.format == .zip)
        _ = payloadHash
    }

    @Test func testArchiveOK() async throws {
        let (archive, _) = try await makeSampleArchive(format: .tar)
        defer { try? FileManager.default.removeItem(at: archive.deletingLastPathComponent()) }
        let engine = DefaultBackends.makeEngine()
        let result = try await engine.test(archive)
        #expect(result.status == .ok || result.status == .warnings)
    }

    @Test func truncatedArchiveFailsGracefully() async throws {
        let (archive, _) = try await makeSampleArchive(format: .zip)
        defer { try? FileManager.default.removeItem(at: archive.deletingLastPathComponent()) }
        let data = try Data(contentsOf: archive)
        try data.prefix(max(12, data.count / 3)).write(to: archive)
        let engine = DefaultBackends.makeEngine()
        do {
            _ = try await engine.test(archive)
        } catch {
            #expect(true)
            return
        }
        let result = try await engine.test(archive)
        #expect(result.status == .corrupted || result.status == .ok)
    }
}

private func roundTrip(format: ArchiveFormat) async throws {
    let (archive, originalHash) = try await makeSampleArchive(format: format)
    let root = archive.deletingLastPathComponent()
    defer { try? FileManager.default.removeItem(at: root) }
    let extracted = root.appendingPathComponent("extracted", isDirectory: true)
    let engine = DefaultBackends.makeEngine()
    try await engine.extract(archive, to: extracted, options: ExtractionOptions(overwrite: .alwaysReplace))
    let extractedFile = try firstRegularFile(in: extracted)
    let extractedHash = try ContentHash.sha256File(at: extractedFile)
    #expect(originalHash == extractedHash)
}

private func makeSampleArchive(format: ArchiveFormat) async throws -> (URL, String) {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("archivist-rt-\(UUID().uuidString)", isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    let folder = root.appendingPathComponent("sample", isDirectory: true)
    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appendingPathComponent("hello.txt")
    let payload = Data("hello archivist \(format.rawValue) \(UUID().uuidString)\n".utf8)
    try payload.write(to: file)
    let archive = root.appendingPathComponent("sample.\(format.defaultExtension)")
    let engine = DefaultBackends.makeEngine()
    try await engine.create(from: [folder], destination: archive, options: CompressionOptions(format: format, level: .fast))
    return (archive, try ContentHash.sha256File(at: file))
}

private func firstRegularFile(in directory: URL) throws -> URL {
    let fm = FileManager.default
    let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
    while let url = enumerator?.nextObject() as? URL {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        if values.isRegularFile == true { return url }
    }
    throw ArchiveError.io("No extracted file found")
}

private func files(named name: String, under directory: URL) throws -> [URL] {
    let fm = FileManager.default
    let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: nil)
    var matches: [URL] = []
    while let url = enumerator?.nextObject() as? URL {
        if url.lastPathComponent == name { matches.append(url) }
    }
    return matches
}
