import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ArchiveCore
import ArchiveBackends

@main
struct ArchivistMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Archivist") {
            ContentView()
                .environmentObject(appDelegate.model)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("Open…") { appDelegate.model.presentOpenPanel() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Extract…") { appDelegate.model.presentExtractSheet() }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(appDelegate.model.session == nil)
                Button("Compress…") { appDelegate.model.presentCompressPanel() }
                    .keyboardShortcut("k", modifiers: .command)
                Button("Test Archive") { appDelegate.model.testCurrent() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                    .disabled(appDelegate.model.session == nil)
            }
            CommandMenu("Archive") {
                Button("Get Info") { appDelegate.model.showInspector.toggle() }
                    .keyboardShortcut("i", modifiers: .command)
                Button("Refresh") { Task { await appDelegate.model.reload() } }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appDelegate.model)
        }

        Window("Jobs", id: "jobs") {
            JobsView()
                .environmentObject(appDelegate.model)
                .frame(minWidth: 520, minHeight: 240)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        Task { try? await TempDirectoryManager.shared.prepareRoot() }
        claimRARFileHandler()
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let intent = OpenIntent.classify(urls)
        switch intent.kind {
        case .extractArchive(let archive):
            model.extractFromFinder(archive)
        default:
            model.handleDroppedURLs(urls)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        true
    }

    @objc func extractHere(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        handleService(pboard, action: .extractHere)
    }

    @objc func extractTo(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        handleService(pboard, action: .extractTo)
    }

    @objc func compressHereRAR(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        handleService(pboard, action: .compressHereRAR)
    }

    @objc func compressZIP(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        handleService(pboard, action: .compressZIP)
    }

    @objc func compressHereZIP(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        handleService(pboard, action: .compressHereZIP)
    }

    @objc func compress7Z(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        handleService(pboard, action: .compress7Z)
    }

    @objc func compressHere7Z(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        handleService(pboard, action: .compressHere7Z)
    }

    @objc func testArchive(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        handleService(pboard, action: .test)
    }

    private enum ServiceAction {
        case extractHere, extractTo, compressZIP, compress7Z, compressHereZIP, compressHere7Z, compressHereRAR, test
    }

    @MainActor
    private func handleService(_ pboard: NSPasteboard, action: ServiceAction) {
        let urls = urlsFromPasteboard(pboard)
        guard !urls.isEmpty else { return }
        switch action {
        case .extractHere:
            for url in urls {
                model.extractFromFinder(url)
            }
        case .extractTo:
            model.handleDroppedURLs(urls)
        case .compressZIP:
            model.compress(urls: urls, format: .zip)
        case .compress7Z:
            model.compress(urls: urls, format: .sevenZip)
        case .compressHereZIP:
            model.compressHere(urls: urls, format: .zip)
        case .compressHere7Z:
            model.compressHere(urls: urls, format: .sevenZip)
        case .compressHereRAR:
            model.compressHere(urls: urls, format: .rar5)
        case .test:
            if let archive = urls.first {
                model.test(archive: archive)
            }
        }
    }

    private func urlsFromPasteboard(_ pboard: NSPasteboard) -> [URL] {
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            return urls.map(\.standardizedFileURL)
        }
        if let filenames = pboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String],
           !filenames.isEmpty {
            return filenames.map { URL(fileURLWithPath: $0) }
        }
        if let strings = pboard.propertyList(forType: .string) as? [String] {
            return strings.map { URL(fileURLWithPath: $0) }
        }
        return []
    }

    private func claimRARFileHandler() {
        let appURL = Bundle.main.bundleURL
        var types: [UTType] = []
        types.append(contentsOf: ["rar", "cbr"].compactMap { UTType(filenameExtension: $0) })
        types.append(contentsOf: ["app.archivist.rar-archive", "com.rarlab.rar-archive"].compactMap { UTType($0) })
        for type in types {
            NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: type) { _ in }
        }
    }
}
