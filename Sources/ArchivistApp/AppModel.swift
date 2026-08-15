import AppKit
import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ArchiveCore
import ArchiveBackends

@MainActor
final class AppModel: ObservableObject {
    let engine: ArchiveEngine
    let jobManager: JobManager

    @Published var session: ArchiveSession?
    @Published var jobs: [ArchiveJob] = []
    @Published var search = SearchQuery(text: "")
    @Published var errorBanner: String?
    @Published var showExtractSheet = false
    @Published var showCompressSheet = false
    @Published var showPasswordSheet = false
    @Published var showInspector = true
    @Published var showJobs = false
    @Published var passwordDraft = ""
    @Published var rememberPassword = false
    @Published var settings = AppSettings()
    @Published var history: [HistoryRecord] = []
    @Published var extractDestination: URL?
    @Published var compressSources: [URL] = []
    @Published var compressFormat: ArchiveFormat = .zip
    @Published var compressLevel: CompressionLevel = .normal
    @Published var compressPassword = ""
    @Published var compressConfirm = ""
    @Published var pendingOpen: URL?
    @Published var previewEntry: ArchiveEntry?
    @Published var selectedEntryIDs: Set<String> = []

    private var passwordContinuation: CheckedContinuation<String?, Never>?
    private let passwordStore = PasswordStore()

    init(engine: ArchiveEngine = DefaultBackends.makeEngine(), jobManager: JobManager = .shared) {
        self.engine = engine
        self.jobManager = jobManager
        Task { [weak self] in
            guard let self else { return }
            self.settings = await SettingsStore.shared.current()
            self.history = await HistoryStore.shared.all()
            for await job in await self.jobManager.updates() {
                await MainActor.run {
                    self.refreshJobs()
                    _ = job
                }
            }
        }
        refreshJobs()
    }

    var filteredEntries: [ArchiveEntry] {
        guard let session else { return [] }
        return ArchiveSearch.filter(session.visibleEntries, query: search)
    }

    func refreshJobs() {
        Task {
            let snapshot = await jobManager.snapshot()
            await MainActor.run { self.jobs = snapshot }
        }
    }

    func handleDroppedURLs(_ urls: [URL]) {
        let intent = OpenIntent.classify(urls)
        switch intent.kind {
        case .extractArchive(let archive):
            Task { await open(archive) }
        case .compressSources(let sources):
            compressSources = sources
            showCompressSheet = true
        case .mixed(let archives, let files):
            if let archive = archives.first {
                Task { await open(archive) }
            }
            if !files.isEmpty {
                compressSources = files
                showCompressSheet = true
            }
        }
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose an archive to open"
        if panel.runModal() == .OK, let url = panel.url {
            Task { await open(url) }
        }
    }

    func presentCompressPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Choose files or folders to compress"
        if panel.runModal() == .OK {
            compressSources = panel.urls
            showCompressSheet = true
        }
    }

    func presentExtractSheet() {
        guard session != nil else { return }
        showExtractSheet = true
    }

    func open(_ url: URL, password: String? = nil) async {
        do {
            var pass = password
            if pass == nil, settings.useKeychain {
                pass = passwordStore.load(for: url)
            }
            let info = try await engine.inspect(url, password: pass)
            if info.isEncrypted && pass == nil {
                pendingOpen = url
                showPasswordSheet = true
                return
            }
            let entries = try await engine.list(url, password: pass)
            session = ArchiveSession(url: url, info: info, entries: entries, password: pass)
            selectedEntryIDs = []
            errorBanner = nil
        } catch ArchiveError.incorrectPassword {
            pendingOpen = url
            showPasswordSheet = true
            errorBanner = ArchiveError.incorrectPassword.userMessage
        } catch {
            errorBanner = error.localizedDescription
        }
    }

    func submitPassword() {
        let password = passwordDraft
        let url = pendingOpen ?? session?.url
        passwordDraft = ""
        showPasswordSheet = false
        pendingOpen = nil
        guard let url else { return }
        if rememberPassword && settings.useKeychain {
            try? passwordStore.save(password: password, for: url)
        }
        Task { await open(url, password: password) }
    }

    func extract(archive: URL? = nil, to destination: URL? = nil) {
        let source = archive ?? session?.url
        guard let source else { return }
        let dest: URL
        if let destination {
            dest = destination
        } else {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.prompt = "Extract"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            dest = url
        }
        let selected = selectedEntryIDs
        let password = session?.password
        let options = ExtractionOptions(
            selectedPaths: selected,
            extractAll: selected.isEmpty,
            preservePermissions: settings.preservePermissions,
            preserveTimestamps: settings.preserveMetadata,
            preserveSymlinks: settings.preserveSymlinks,
            overwrite: settings.overwritePolicy,
            password: password,
            safety: settings.safety
        )
        Task {
            let id = await engine.enqueueExtract(source, to: dest, options: options)
            refreshJobs()
            _ = id
        }
    }

    func extractHere() {
        guard let url = session?.url else { return }
        extract(archive: url, to: url.deletingLastPathComponent())
    }

    func extractToNewFolder() {
        guard let url = session?.url else { return }
        let folder = url.deletingPathExtension().lastPathComponent
        let dest = url.deletingLastPathComponent().appendingPathComponent(folder, isDirectory: true)
        extract(archive: url, to: dest)
    }

    func compress(urls: [URL]? = nil, format: ArchiveFormat? = nil) {
        if let urls { compressSources = urls }
        if let format { compressFormat = format }
        if compressSources.isEmpty { presentCompressPanel(); return }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = (compressSources.first?.deletingPathExtension().lastPathComponent ?? "Archive") + "." + compressFormat.defaultExtension
        panel.title = "Create Archive"
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        let password = compressPassword.isEmpty ? nil : compressPassword
        compressPassword = ""
        compressConfirm = ""
        let options = CompressionOptions(
            format: compressFormat,
            level: compressLevel,
            password: password,
            encryption: password == nil ? .none : (compressFormat == .sevenZip ? .sevenZipAES256 : .zipCrypto)
        )
        let sources = compressSources
        showCompressSheet = false
        Task {
            _ = await engine.enqueueCreate(from: sources, destination: dest, options: options)
            refreshJobs()
        }
    }

    /// Finder-style compress: write next to the selection with no save panel.
    func compressHere(urls: [URL], format: ArchiveFormat) {
        guard !urls.isEmpty else { return }
        let parent = urls[0].deletingLastPathComponent()
        let stem: String
        if urls.count == 1 {
            stem = urls[0].deletingPathExtension().lastPathComponent
        } else {
            stem = "Archive"
        }
        var dest = parent.appendingPathComponent("\(stem).\(format.defaultExtension)")
        dest = UniqueName.next(for: dest)
        let options = CompressionOptions(format: format, level: settings.defaultCompressionLevel)
        Task {
            _ = await engine.enqueueCreate(from: urls, destination: dest, options: options)
            refreshJobs()
            NSWorkspace.shared.activateFileViewerSelecting([dest])
        }
    }

    func testCurrent() {
        guard let url = session?.url else { return }
        test(archive: url)
    }

    func test(archive: URL) {
        Task {
            _ = await engine.enqueueTest(archive, password: session?.password)
            refreshJobs()
        }
    }

    func reload() async {
        guard let url = session?.url else { return }
        await open(url, password: session?.password)
    }

    func navigate(into entry: ArchiveEntry) {
        guard entry.isDirectory else {
            previewEntry = entry
            return
        }
        session?.currentPath = entry.path
    }

    func navigateUp() {
        guard let session else { return }
        let parent = (session.currentPath as NSString).deletingLastPathComponent
        self.session?.currentPath = parent == "." ? "" : parent
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

struct ArchiveSession: Equatable {
    var url: URL
    var info: ArchiveInfo
    var entries: [ArchiveEntry]
    var password: String?
    var currentPath: String = ""

    var visibleEntries: [ArchiveEntry] {
        entries.filter { entry in
            if currentPath.isEmpty {
                return !entry.path.contains("/") || entry.parentPath.isEmpty
            }
            return entry.parentPath == currentPath
        }
    }

    var folders: [ArchiveEntry] {
        entries.filter(\.isDirectory)
    }
}
