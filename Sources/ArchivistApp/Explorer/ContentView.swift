import SwiftUI
import UniformTypeIdentifiers
import AppKit
import ArchiveCore

extension AppSettings.AppearanceMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if model.session == nil {
                NavigationSplitView {
                    SidebarView()
                        .frame(minWidth: 180)
                } detail: {
                    EmptyStateView()
                }
            } else {
                NavigationSplitView {
                    SidebarView()
                        .frame(minWidth: 180)
                } content: {
                    ArchiveExplorerView()
                } detail: {
                    if model.showInspector {
                        InspectorView()
                            .frame(minWidth: 240)
                    }
                }
            }
        }
        .navigationTitle(model.session?.url.lastPathComponent ?? "Archivist")
        .toolbar { toolbar }
        .searchable(text: $model.search.text, prompt: "Search archive")
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
        .alert("Error", isPresented: Binding(
            get: { model.errorBanner != nil },
            set: { if !$0 { model.errorBanner = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorBanner = nil }
        } message: {
            Text(model.errorBanner ?? "")
        }
        .sheet(isPresented: $model.showExtractSheet) { ExtractSheet() }
        .sheet(isPresented: $model.showCompressSheet) { CompressSheet() }
        .sheet(isPresented: $model.showPasswordSheet) { PasswordSheet() }
        .sheet(item: $model.previewEntry) { entry in
            PreviewView(entry: entry)
        }
        .frame(minWidth: 900, minHeight: 560)
        .preferredColorScheme(model.settings.appearance.colorScheme)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Open", systemImage: "folder") { model.presentOpenPanel() }
            Button("Extract", systemImage: "tray.and.arrow.down") { model.presentExtractSheet() }
                .disabled(model.session == nil)
            Button("Compress", systemImage: "archivebox") { model.presentCompressPanel() }
            Button("Test", systemImage: "checkmark.seal") { model.testCurrent() }
                .disabled(model.session == nil)
            Button("Jobs", systemImage: "list.bullet.rectangle") { openWindow(id: "jobs") }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    DispatchQueue.main.async {
                        model.handleDroppedURLs([url])
                    }
                }
            }
        }
        return true
    }
}

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section("Archive") {
                if let session = model.session {
                    Label(session.url.lastPathComponent, systemImage: "doc.zipper")
                    Button("Up") { model.navigateUp() }
                        .disabled(session.currentPath.isEmpty)
                } else {
                    Text("No archive open")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Folders") {
                if let session = model.session {
                    ForEach(session.folders) { folder in
                        Button {
                            model.navigate(into: folder)
                        } label: {
                            Label(folder.path, systemImage: "folder")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Section("Recent") {
                if model.history.isEmpty {
                    Text("Nothing yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.history.prefix(12)) { record in
                        Button {
                            let url = URL(fileURLWithPath: record.archive)
                            guard FileManager.default.fileExists(atPath: url.path) else { return }
                            Task { await model.open(url) }
                        } label: {
                            Label(URL(fileURLWithPath: record.archive).lastPathComponent, systemImage: "clock")
                        }
                        .buttonStyle(.plain)
                        .help(record.archive)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

struct EmptyStateView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
            Text("Archivist")
                .font(.largeTitle.bold())
            Text("Drop an archive here to browse it, or drop files and folders to compress them.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
            HStack(spacing: 12) {
                Button("Open Archive") { model.presentOpenPanel() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Compress…") { model.presentCompressPanel() }
            }
            .padding(.top, 4)
            Text("ZIP, RAR, 7Z, TAR, and more")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
