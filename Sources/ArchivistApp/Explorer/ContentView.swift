import SwiftUI
import UniformTypeIdentifiers
import ArchiveCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .frame(minWidth: 180)
        } content: {
            if model.session == nil {
                EmptyStateView()
            } else {
                ArchiveExplorerView()
            }
        } detail: {
            if model.showInspector {
                InspectorView()
                    .frame(minWidth: 240)
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
                ForEach(model.history.prefix(12)) { record in
                    Text(record.archive)
                        .lineLimit(1)
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
            Image(systemName: "archivebox")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Archivist")
                .font(.largeTitle.bold())
            Text("Drop files or folders here to compress\nor drop an archive here to extract")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            HStack {
                Button("Open Archive") { model.presentOpenPanel() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Compress…") { model.presentCompressPanel() }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
