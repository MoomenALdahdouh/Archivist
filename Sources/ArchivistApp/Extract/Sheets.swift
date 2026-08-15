import SwiftUI
import AppKit
import ArchiveCore

struct ExtractSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var overwrite = OverwritePolicy.ask
    @State private var newFolder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Extract Archive")
                .font(.title2.bold())
            if let url = model.session?.url {
                Text(url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Picker("Overwrite", selection: $overwrite) {
                ForEach(OverwritePolicy.allCases) { policy in
                    Text(policy.displayName).tag(policy)
                }
            }
            Toggle("Extract to a new folder", isOn: $newFolder)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Extract Here") {
                    model.settings.overwritePolicy = overwrite
                    if newFolder {
                        model.extractToNewFolder()
                    } else {
                        model.extractHere()
                    }
                    dismiss()
                }
                Button("Extract to…") {
                    model.settings.overwritePolicy = overwrite
                    model.extract()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear { overwrite = model.settings.overwritePolicy }
    }
}

struct CompressSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPassword = false

    private let creatable: [ArchiveFormat] = [
        .zip, .sevenZip, .tar, .tarGz, .tarBz2, .tarXz, .tarZstd, .gzip, .bzip2, .xz, .zstd, .lz4,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create Archive")
                .font(.title2.bold())
            Text(model.compressSources.map(\.lastPathComponent).joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Format", selection: $model.compressFormat) {
                ForEach(creatable) { format in
                    Text(format.displayName).tag(format)
                }
            }
            Picker("Compression", selection: $model.compressLevel) {
                ForEach(CompressionLevel.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
            SecureField("Password (optional)", text: $model.compressPassword)
            SecureField("Confirm password", text: $model.compressConfirm)
            if !model.compressPassword.isEmpty {
                ProgressView(value: PasswordStore.strength(of: model.compressPassword))
                    .tint(PasswordStore.strength(of: model.compressPassword) > 0.6 ? .green : .orange)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") { model.compress() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.compressPassword.isEmpty && model.compressPassword != model.compressConfirm)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}

struct PasswordSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var reveal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Password Required")
                .font(.title2.bold())
            Text("This archive is encrypted. Passwords are never logged.")
                .foregroundStyle(.secondary)
            HStack {
                if reveal {
                    TextField("Password", text: $model.passwordDraft)
                } else {
                    SecureField("Password", text: $model.passwordDraft)
                }
                Button(reveal ? "Hide" : "Show") { reveal.toggle() }
            }
            Toggle("Remember in Keychain", isOn: $model.rememberPassword)
                .disabled(!model.settings.useKeychain)
            HStack {
                Spacer()
                Button("Cancel") {
                    model.showPasswordSheet = false
                    dismiss()
                }
                Button("Unlock") {
                    model.submitPassword()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
