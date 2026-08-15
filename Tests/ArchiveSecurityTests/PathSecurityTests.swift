import Foundation
import Testing
@testable import ArchiveCore

@Suite("Zip Slip / path traversal")
struct ZipSlipTests {
    let guardrail = ExtractionGuard()
    let destination = URL(fileURLWithPath: "/tmp/archivist-safe-dest")

    @Test(arguments: [
        "../file",
        "../../etc/passwd",
        "../../../Users/foo",
        "/absolute/path",
        "~/secret",
        "..\\windows",
        "foo/../../etc/passwd",
        "C:\\Windows\\system32",
    ])
    func rejectsUnsafePaths(_ path: String) {
        #expect(throws: ArchiveError.self) {
            _ = try guardrail.validatedRelativePath(path)
        }
    }

    @Test func rejectsNullByte() {
        #expect(throws: ArchiveError.self) {
            _ = try guardrail.validatedRelativePath("ok\0hidden")
        }
    }

    @Test func acceptsRelativeUnicode() throws {
        let path = try guardrail.validatedRelativePath("العربية/مجلد/ملف.txt")
        #expect(path.contains("ملف.txt"))
        let istanbul = try guardrail.validatedRelativePath("İstanbul/çalışma.docx")
        #expect(istanbul.contains("çalışma.docx"))
        let jp = try guardrail.validatedRelativePath("日本語.txt")
        #expect(jp == "日本語.txt")
    }

    @Test func resolvedURLStaysInsideDestination() throws {
        let url = try guardrail.resolvedURL(entryPath: "a/b/c.txt", destination: destination)
        #expect(url.path.hasPrefix(destination.path))
    }

    @Test func symlinkEscapeRejected() {
        let link = destination.appendingPathComponent("link")
        #expect(throws: ArchiveError.self) {
            try guardrail.validateSymlinkTarget("/etc/passwd", linkURL: link, destination: destination)
        }
        #expect(throws: ArchiveError.self) {
            try guardrail.validateSymlinkTarget("../../outside", linkURL: link, destination: destination)
        }
    }

    @Test func nestedRelativeSymlinkAllowed() throws {
        let link = destination.appendingPathComponent("dir/link")
        try guardrail.validateSymlinkTarget("sibling.txt", linkURL: link, destination: destination)
    }
}

@Suite("Decompression bomb")
struct BombTests {
    @Test func flagsHugeRatio() {
        let guardrail = ExtractionGuard(limits: SafetyLimits(
            bombRatio: 100,
            bombMinimumUncompressedBytes: 1_000
        ))
        #expect(throws: ArchiveError.self) {
            try guardrail.checkBomb(compressed: 10, uncompressed: 5_000)
        }
    }

    @Test func allowsNormalRatio() throws {
        let guardrail = ExtractionGuard()
        try guardrail.checkBomb(compressed: 50, uncompressed: 100)
    }
}

@Suite("Safety limits")
struct SafetyLimitTests {
    @Test func fileCount() {
        let guardrail = ExtractionGuard(limits: SafetyLimits(maximumFileCount: 2))
        #expect(throws: ArchiveError.self) {
            try guardrail.checkCounts(files: 3, bytes: 10)
        }
    }

    @Test func pathLength() {
        let guardrail = ExtractionGuard(limits: SafetyLimits(maximumPathLength: 4))
        #expect(throws: ArchiveError.self) {
            _ = try guardrail.validatedRelativePath("abcdef")
        }
    }
}

@Suite("Fuzz path validation")
struct PathFuzzTests {
    @Test func randomPathsNeverEscape() {
        var rng = SplitMix64(seed: 0xA5A5_C0FF_EE11)
        let dest = URL(fileURLWithPath: "/tmp/archivist-fuzz-dest")
        let guardrail = ExtractionGuard()
        for _ in 0..<500 {
            let path = randomPath(&rng)
            do {
                let url = try guardrail.resolvedURL(entryPath: path, destination: dest)
                #expect(url.standardizedFileURL.path.hasPrefix(dest.standardizedFileURL.path))
            } catch is ArchiveError {
                // Rejection is success for unsafe inputs.
            } catch {
                Issue.record("Unexpected error \(error)")
            }
        }
    }
}

struct SplitMix64 {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

func randomPath(_ rng: inout SplitMix64) -> String {
    let tokens = ["a", "b", "..", ".", "/", "~", "etc", "passwd", "ملف", "İ", "*", " ", "\0", "C:", "foo"]
    let count = Int(rng.next() % 6) + 1
    var parts: [String] = []
    for _ in 0..<count {
        parts.append(tokens[Int(rng.next() % UInt64(tokens.count))])
    }
    return parts.joined(separator: "/")
}
