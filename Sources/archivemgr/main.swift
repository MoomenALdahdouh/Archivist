import ArchiveCLI
import Foundation

@main
enum ArchivemgrMain {
    static func main() async {
        let code = await ArchiveCLIRunner.run(arguments: CommandLine.arguments)
        exit(code)
    }
}
