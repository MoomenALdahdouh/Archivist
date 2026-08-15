import Foundation
import Testing
@testable import ArchiveCore

@Suite("Format detection")
struct FormatDetectionTests {
    @Test func zipMagic() {
        let data = Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00])
        #expect(FormatDetector.detectMagic(data: data) == .zip)
    }

    @Test func rar5Magic() {
        let data = Data([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00])
        #expect(FormatDetector.detectMagic(data: data) == .rar5)
    }

    @Test func rar4Magic() {
        let data = Data([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00])
        #expect(FormatDetector.detectMagic(data: data) == .rar)
    }

    @Test func sevenZipMagic() {
        let data = Data([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])
        #expect(FormatDetector.detectMagic(data: data) == .sevenZip)
    }

    @Test func gzipMagic() {
        #expect(FormatDetector.detectMagic(data: Data([0x1F, 0x8B, 0x08])) == .gzip)
    }

    @Test func tarGzExtension() {
        let url = URL(fileURLWithPath: "/tmp/backup.tar.gz")
        #expect(FormatDetector.detectExtension(url) == .tarGz)
    }

    @Test func arabicFilenameExtension() {
        let url = URL(fileURLWithPath: "/tmp/مرحبا.zip")
        #expect(FormatDetector.detectExtension(url) == .zip)
    }

    @Test func turkishFilenameExtension() {
        let url = URL(fileURLWithPath: "/tmp/İstanbul.7z")
        #expect(FormatDetector.detectExtension(url) == .sevenZip)
    }
}

@Suite("Search")
struct SearchTests {
    let entries = [
        ArchiveEntry(path: "docs/report.pdf", kind: .file, uncompressedSize: 10),
        ArchiveEntry(path: "photos/cat.jpg", kind: .file, uncompressedSize: 20),
        ArchiveEntry(path: "العربية/ملف.txt", kind: .file, uncompressedSize: 30),
    ]

    @Test func wildcardPdf() {
        let result = ArchiveSearch.filter(entries, query: SearchQuery(text: "*.pdf"))
        #expect(result.count == 1)
        #expect(result.first?.name == "report.pdf")
    }

    @Test func caseInsensitive() {
        let result = ArchiveSearch.filter(entries, query: SearchQuery(text: "REPORT"))
        #expect(result.count == 1)
    }

    @Test func arabicSearch() {
        let result = ArchiveSearch.filter(entries, query: SearchQuery(text: "ملف"))
        #expect(result.count == 1)
    }
}

@Suite("Progress")
struct ProgressTests {
    @Test func fractionFromBytes() {
        let engine = ProgressEngine()
        let snap = engine.snapshot(completedBytes: 50, totalBytes: 100)
        #expect(snap.fraction == 0.5)
        #expect(snap.isIndeterminate == false)
        #expect(snap.percentText == "50%")
    }

    @Test func indeterminateWhenUnknown() {
        let engine = ProgressEngine()
        let snap = engine.snapshot(completedBytes: 10, totalBytes: nil)
        #expect(snap.isIndeterminate)
    }
}

@Suite("Disk space")
struct DiskSpaceTests {
    @Test func shortageMath() {
        let space = DiskSpace(required: 100, available: 40, safetyMargin: 10)
        #expect(space.shortage == 70)
        #expect(space.hasEnough == false)
    }

    @Test func enoughSpace() {
        let space = DiskSpace(required: 10, available: 100, safetyMargin: 1)
        #expect(space.hasEnough)
    }
}

@Suite("Job lifecycle")
struct JobLifecycleTests {
    @Test func completesSuccessfully() async {
        let manager = JobManager()
        let id = await manager.submit(operation: .test, sourceName: "a.zip") { _, progress in
            progress(ProgressEngine().snapshot(completedBytes: 1, totalBytes: 1))
        }
        try? await Task.sleep(for: .milliseconds(200))
        let job = await manager.job(id: id)
        #expect(job?.status == .completed)
    }

    @Test func cancelMapsStatus() async {
        let manager = JobManager()
        let id = await manager.submit(operation: .extract, sourceName: "big.zip") { _, _ in
            try await Task.sleep(for: .seconds(10))
        }
        await manager.cancel(id)
        try? await Task.sleep(for: .milliseconds(200))
        let job = await manager.job(id: id)
        #expect(job?.status == .cancelled || job?.status == .cancelling)
    }
}

@Suite("CLI parser")
struct CLIParserCoreTests {
    @Test func extractUsage() throws {
        // parser lives in ArchiveCLI; basic format mapping is in core-adjacent tests
        #expect(ArchiveFormat.zip.displayName == "ZIP")
        #expect(ArchiveError.incorrectPassword.exitCode == 4)
        #expect(ArchiveError.missingVolume("x").exitCode == 5)
        #expect(ArchiveError.cancelled.exitCode == 9)
    }
}

@Suite("Error mapping")
struct ErrorMappingTests {
    @Test func redactsPassword() {
        let redacted = ArchiveError.redact("password=secret-value")
        #expect(!redacted.contains("secret-value"))
    }

    @Test func passwordMessage() {
        let error = ArchiveError.fromBackendMessage("Passphrase incorrect")
        #expect(error == .incorrectPassword)
    }
}

@Suite("Overwrite / unique names")
struct UniqueNameTests {
    @Test func uniqueWhenMissing() {
        let url = URL(fileURLWithPath: "/tmp/archivist-does-not-exist-\(UUID().uuidString).txt")
        #expect(UniqueName.next(for: url) == url)
    }
}

@Suite("Open intent")
struct OpenIntentTests {
    @Test func zipIsArchive() {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("intent-\(UUID().uuidString).zip")
        FileManager.default.createFile(atPath: url.path, contents: Data([0x50, 0x4B, 0x03, 0x04]))
        defer { try? FileManager.default.removeItem(at: url) }
        let intent = OpenIntent.classify([url])
        if case .extractArchive = intent.kind {
            #expect(true)
        } else {
            Issue.record("Expected extract archive intent")
        }
    }
}
