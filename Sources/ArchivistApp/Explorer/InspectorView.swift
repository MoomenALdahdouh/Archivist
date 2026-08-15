import SwiftUI
import ArchiveCore

struct InspectorView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let info = model.session?.info {
                    Text("Archive")
                        .font(.headline)
                    labeled("Format", info.format.displayName)
                    labeled("Backend", info.backend.rawValue)
                    labeled("Entries", "\(info.entryCount)")
                    labeled("Uncompressed", ByteCountFormat.string(from: info.totalUncompressedSize))
                    labeled("Compressed", ByteCountFormat.string(from: info.compressedSize))
                    labeled("Encrypted", info.isEncrypted ? "Yes" : "No")
                    if info.volume.isMultipart {
                        labeled("Multipart", "Yes")
                    }
                    if !info.warnings.isEmpty {
                        Text(info.warnings.joined(separator: "\n"))
                            .foregroundStyle(.orange)
                    }
                }
                if let id = model.selectedEntryIDs.first,
                   let entry = model.session?.entries.first(where: { $0.id == id }) {
                    Divider()
                    Text("Selected")
                        .font(.headline)
                    labeled("Name", entry.name)
                    labeled("Path", entry.path)
                    labeled("Size", ByteCountFormat.string(from: entry.uncompressedSize))
                    labeled("Encrypted", entry.isEncrypted ? "Yes" : "No")
                    if let target = entry.symlinkTarget {
                        labeled("Symlink", target)
                    }
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }
    }
}
