import SwiftUI
import ArchiveCore

struct ArchiveExplorerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var sortOrder = [KeyPathComparator(\ArchiveEntry.path)]

    var body: some View {
        Table(sortedEntries, selection: $model.selectedEntryIDs, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.path) { entry in
                Label(entry.name, systemImage: entry.isDirectory ? "folder" : "doc")
                    .onTapGesture(count: 2) {
                        if entry.isDirectory {
                            model.navigate(into: entry)
                        } else {
                            model.previewEntry = entry
                        }
                    }
            }
            TableColumn("Type") { entry in
                Text(entry.isDirectory ? "Folder" : (entry.path as NSString).pathExtension.uppercased())
            }
            .width(60)
            TableColumn("Size") { entry in
                Text(entry.isDirectory ? "—" : ByteCountFormat.string(from: entry.uncompressedSize))
            }
            .width(90)
            TableColumn("Compressed") { entry in
                if let compressed = entry.compressedSize {
                    Text(ByteCountFormat.string(from: compressed))
                } else {
                    Text("—")
                }
            }
            .width(90)
            TableColumn("Modified") { entry in
                if let modified = entry.modified {
                    Text(modified, style: .date)
                } else {
                    Text("—")
                }
            }
            .width(120)
            TableColumn("Encrypted") { entry in
                Text(entry.isEncrypted ? "Yes" : "")
            }
            .width(80)
        }
        .contextMenu(forSelectionType: String.self) { ids in
            Button("Extract Selected") { model.presentExtractSheet() }
            Button("Preview") {
                if let id = ids.first, let entry = model.session?.entries.first(where: { $0.id == id }) {
                    model.previewEntry = entry
                }
            }
        }
        .onChange(of: sortOrder) { _, _ in }
        .overlay(alignment: .bottom) {
            statusBar
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private var sortedEntries: [ArchiveEntry] {
        model.filteredEntries.sorted(using: sortOrder)
    }

    private var statusBar: some View {
        HStack {
            if let info = model.session?.info {
                Text("\(info.entryCount) items")
                Text("•")
                Text(ByteCountFormat.string(from: info.compressedSize))
                if let ratio = info.compressionRatio {
                    Text("•")
                    Text(String(format: "Ratio %.0f%%", ratio * 100))
                }
            }
            Spacer()
            if let job = model.jobs.first(where: { !$0.status.isFinished }) {
                ProgressView(value: job.progress.fraction)
                    .frame(width: 140)
                Text(job.progress.percentText)
                Text(job.progress.speedText)
                Text(job.progress.etaText)
            }
        }
        .font(.caption)
        .padding(8)
        .background(.bar)
    }
}

