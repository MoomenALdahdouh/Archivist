import SwiftUI
import AppKit
import PDFKit
import ArchiveCore

struct PreviewView: View {
    @EnvironmentObject private var model: AppModel
    let entry: ArchiveEntry
    @State private var text: String?
    @State private var image: NSImage?
    @State private var message = "Preparing a safe preview…"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.name).font(.headline)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else if let text {
                ScrollView {
                    Text(text)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(message)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Extract…") { model.presentExtractSheet() }
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 360)
        .task { await load() }
    }

    private func load() async {
        guard let session = model.session else { return }
        do {
            let tempRoot = try await TempDirectoryManager.shared.makeJobDirectory(id: UUID())
            let options = ExtractionOptions(
                selectedPaths: [entry.path],
                extractAll: false,
                overwrite: .alwaysReplace,
                password: session.password
            )
            try await model.engine.extract(session.url, to: tempRoot, options: options)
            let file = try ExtractionGuard().resolvedURL(entryPath: entry.path, destination: tempRoot)
            let ext = file.pathExtension.lowercased()
            if ["txt", "md", "json", "xml", "csv", "swift", "c", "h", "py", "js", "html"].contains(ext) {
                let data = try Data(contentsOf: file, options: [.mappedIfSafe])
                let prefix = data.prefix(512 * 1024)
                text = String(data: prefix, encoding: .utf8) ?? String(data: prefix, encoding: .isoLatin1)
            } else if ["png", "jpg", "jpeg", "gif", "webp", "tif", "tiff"].contains(ext) {
                image = NSImage(contentsOf: file)
            } else if ext == "pdf" {
                message = "PDF preview uses the extracted file. Open it with Preview after extracting."
            } else {
                message = "No in-app preview for this type. Extract it to open with another app. Binaries are never executed."
            }
        } catch {
            message = error.localizedDescription
        }
    }
}
