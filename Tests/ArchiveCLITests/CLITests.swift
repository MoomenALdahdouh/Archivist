import Foundation
import Testing
import ArchiveCLI
import ArchiveCore

@Suite("CLI")
struct CLITests {
    @Test func helpExitZero() async {
        let code = await ArchiveCLIRunner.run(arguments: ["archivemgr", "help"])
        #expect(code == 0)
    }

    @Test func unknownCommand() async {
        let code = await ArchiveCLIRunner.run(arguments: ["archivemgr", "explode"])
        #expect(code == 2)
    }

    @Test func missingArchive() async {
        let code = await ArchiveCLIRunner.run(arguments: ["archivemgr", "list"])
        #expect(code == 2)
    }

    @Test func parseExtract() throws {
        let options = try CLIParser.parse(["archivemgr", "extract", "a.zip", "/tmp/out", "--quiet"])
        #expect(options.command == .extract)
        #expect(options.quiet)
        #expect(options.destination?.path == "/tmp/out")
    }

    @Test func parseCreateFormat() throws {
        let options = try CLIParser.parse(["archivemgr", "create", "src", "out.7z", "--format", "7z"])
        #expect(options.format == .sevenZip)
    }
}
