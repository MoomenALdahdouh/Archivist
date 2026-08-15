import Foundation
import ArchiveCore
import ArchiveBackends
import ArchiveCLI

enum TestFail: Error {
    case failed(String)
}

@main
enum ArchiveTestRunner {
    static func main() async {
        var failed = 0
        var passed = 0

        func check(_ name: String, _ body: () throws -> Void) {
            do {
                try body()
                passed += 1
            } catch {
                failed += 1
                fputs("FAIL \(name): \(error)\n", stderr)
            }
        }

        func checkAsync(_ name: String, _ body: () async throws -> Void) async {
            do {
                try await body()
                passed += 1
            } catch {
                failed += 1
                fputs("FAIL \(name): \(error)\n", stderr)
            }
        }

        check("zip magic") {
            let data = Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00])
            try expect(FormatDetector.detectMagic(data: data) == .zip)
        }
        check("rar5 magic") {
            try expect(FormatDetector.detectMagic(data: Data([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00])) == .rar5)
        }
        check("7z magic") {
            try expect(FormatDetector.detectMagic(data: Data([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])) == .sevenZip)
        }
        check("gzip magic") {
            try expect(FormatDetector.detectMagic(data: Data([0x1F, 0x8B, 0x08])) == .gzip)
        }
        check("tar.gz extension") {
            try expect(FormatDetector.detectExtension(URL(fileURLWithPath: "/tmp/backup.tar.gz")) == .tarGz)
        }
        check("arabic zip extension") {
            try expect(FormatDetector.detectExtension(URL(fileURLWithPath: "/tmp/مرحبا.zip")) == .zip)
        }
        check("turkish 7z extension") {
            try expect(FormatDetector.detectExtension(URL(fileURLWithPath: "/tmp/İstanbul.7z")) == .sevenZip)
        }

        let entries = [
            ArchiveEntry(path: "docs/report.pdf", kind: .file, uncompressedSize: 10),
            ArchiveEntry(path: "photos/cat.jpg", kind: .file, uncompressedSize: 20),
            ArchiveEntry(path: "العربية/ملف.txt", kind: .file, uncompressedSize: 30),
        ]
        check("wildcard pdf") {
            try expect(ArchiveSearch.filter(entries, query: SearchQuery(text: "*.pdf")).count == 1)
        }
        check("case insensitive search") {
            try expect(ArchiveSearch.filter(entries, query: SearchQuery(text: "REPORT")).count == 1)
        }
        check("arabic search") {
            try expect(ArchiveSearch.filter(entries, query: SearchQuery(text: "ملف")).count == 1)
        }

        check("progress fraction") {
            let snap = ProgressEngine().snapshot(completedBytes: 50, totalBytes: 100)
            try expect(snap.fraction == 0.5)
            try expect(snap.percentText == "50%")
        }
        check("disk shortage") {
            let space = DiskSpace(required: 100, available: 40, safetyMargin: 10)
            try expect(space.shortage == 70)
        }
        check("redact password") {
            try expect(!ArchiveError.redact("password=secret-value").contains("secret-value"))
        }
        check("map password error") {
            try expect(ArchiveError.fromBackendMessage("Passphrase incorrect") == .incorrectPassword)
        }
        check("exit codes") {
            try expect(ArchiveError.incorrectPassword.exitCode == 4)
            try expect(ArchiveError.cancelled.exitCode == 9)
        }

        let guardrail = ExtractionGuard()
        let dest = URL(fileURLWithPath: "/tmp/archivist-safe-dest")
        for path in ["../file", "../../etc/passwd", "/absolute/path", "~/secret", "foo/../../etc/passwd", "ok\0hidden"] {
            check("reject \(path)") {
                do {
                    _ = try guardrail.validatedRelativePath(path)
                    throw TestFail.failed("should reject")
                } catch is ArchiveError {
                    return
                }
            }
        }
        check("unicode relative path") {
            _ = try guardrail.validatedRelativePath("العربية/مجلد/ملف.txt")
            _ = try guardrail.validatedRelativePath("İstanbul/çalışma.docx")
            _ = try guardrail.validatedRelativePath("日本語.txt")
        }
        check("resolved stays inside") {
            let url = try guardrail.resolvedURL(entryPath: "a/b/c.txt", destination: dest)
            try expect(url.path.hasPrefix(dest.path))
        }
        check("symlink escape") {
            do {
                try guardrail.validateSymlinkTarget("/etc/passwd", linkURL: dest.appendingPathComponent("link"), destination: dest)
                throw TestFail.failed("should reject")
            } catch is ArchiveError {}
        }
        check("bomb") {
            let g = ExtractionGuard(limits: SafetyLimits(bombRatio: 100, bombMinimumUncompressedBytes: 1_000))
            do {
                try g.checkBomb(compressed: 10, uncompressed: 5_000)
                throw TestFail.failed("should reject bomb")
            } catch is ArchiveError {}
        }

        check("cli help") {
            let options = try CLIParser.parse(["archivemgr", "help"])
            try expect(options.command == .help)
        }
        check("cli extract parse") {
            let options = try CLIParser.parse(["archivemgr", "extract", "a.zip", "/tmp/out", "--quiet"])
            try expect(options.command == .extract && options.quiet)
        }
        check("cli unknown") {
            do {
                _ = try CLIParser.parse(["archivemgr", "explode"])
                throw TestFail.failed("should fail")
            } catch is ArchiveError {}
        }

        check("cli rar format") {
            let options = try CLIParser.parse(["archivemgr", "create", "a.txt", "out.rar", "--format", "rar"])
            try expect(options.format == .rar5)
        }

        await checkAsync("job completes") {
            let manager = JobManager()
            let id = await manager.submit(operation: .test, sourceName: "a.zip") { _, progress in
                progress(ProgressEngine().snapshot(completedBytes: 1, totalBytes: 1))
            }
            try await Task.sleep(for: .milliseconds(250))
            let job = await manager.job(id: id)
            try expect(job?.status == .completed)
        }

        await checkAsync("zip round trip") { try await roundTrip(.zip) }
        await checkAsync("tar round trip") { try await roundTrip(.tar) }
        await checkAsync("tar.gz round trip") { try await roundTrip(.tarGz) }
        await checkAsync("7z round trip") { try await roundTrip(.sevenZip) }
        await checkAsync("rar round trip") { try await roundTrip(.rar5) }
        await checkAsync("gzip round trip") { try await gzipRoundTrip() }
        await checkAsync("unicode filenames") { try await unicodeRoundTrip() }
        await checkAsync("inspect without extract") {
            let (archive, _) = try await makeSample(.zip)
            defer { try? FileManager.default.removeItem(at: archive.deletingLastPathComponent()) }
            let info = try await DefaultBackends.makeEngine().inspect(archive)
            try expect(info.entryCount >= 1)
        }
        await checkAsync("test archive") {
            let (archive, _) = try await makeSample(.tar)
            defer { try? FileManager.default.removeItem(at: archive.deletingLastPathComponent()) }
            let result = try await DefaultBackends.makeEngine().test(archive)
            try expect(result.status == .ok || result.status == .warnings)
        }
        await checkAsync("cli help exit") {
            let code = await ArchiveCLIRunner.run(arguments: ["archivemgr", "help"])
            try expect(code == 0)
        }
        await checkAsync("cli unknown exit") {
            let code = await ArchiveCLIRunner.run(arguments: ["archivemgr", "explode"])
            try expect(code == 2)
        }

        print("Passed: \(passed)  Failed: \(failed)")
        if failed > 0 { exit(1) }
    }
}

func expect(_ condition: Bool, _ message: String = "assertion failed") throws {
    if !condition { throw TestFail.failed(message) }
}

func roundTrip(_ format: ArchiveFormat) async throws {
    let (archive, originalHash) = try await makeSample(format)
    let root = archive.deletingLastPathComponent()
    defer { try? FileManager.default.removeItem(at: root) }
    let extracted = root.appendingPathComponent("extracted", isDirectory: true)
    try await DefaultBackends.makeEngine().extract(archive, to: extracted, options: ExtractionOptions(overwrite: .alwaysReplace))
    let extractedFile = try firstFile(in: extracted)
    try expect(try ContentHash.sha256File(at: extractedFile) == originalHash)
}

func gzipRoundTrip() async throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("gz-\(UUID().uuidString)", isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }
    let source = root.appendingPathComponent("payload.bin")
    try Data("gzip-roundtrip".utf8).write(to: source)
    let archive = root.appendingPathComponent("payload.bin.gz")
    let extracted = root.appendingPathComponent("out", isDirectory: true)
    let engine = DefaultBackends.makeEngine()
    try await engine.create(from: [source], destination: archive, options: CompressionOptions(format: .gzip, level: .fast))
    try await engine.extract(archive, to: extracted, options: ExtractionOptions(overwrite: .alwaysReplace))
    let extractedFile = try firstFile(in: extracted)
    try expect(try ContentHash.sha256File(at: source) == ContentHash.sha256File(at: extractedFile))
}

func unicodeRoundTrip() async throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("uni-\(UUID().uuidString)", isDirectory: true)
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
        var found = false
        let enumerator = FileManager.default.enumerator(at: extracted, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            if url.lastPathComponent == name { found = true }
        }
        try expect(found, "missing \(name)")
    }
}

func makeSample(_ format: ArchiveFormat) async throws -> (URL, String) {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("rt-\(UUID().uuidString)", isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    let folder = root.appendingPathComponent("sample", isDirectory: true)
    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appendingPathComponent("hello.txt")
    try Data("hello \(format.rawValue)\n".utf8).write(to: file)
    let archive = root.appendingPathComponent("sample.\(format.defaultExtension)")
    try await DefaultBackends.makeEngine().create(from: [folder], destination: archive, options: CompressionOptions(format: format, level: .fast))
    return (archive, try ContentHash.sha256File(at: file))
}

func firstFile(in directory: URL) throws -> URL {
    let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
    while let url = enumerator?.nextObject() as? URL {
        if (try url.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true {
            return url
        }
    }
    throw TestFail.failed("no extracted file")
}
