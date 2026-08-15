import SwiftUI
import ArchiveCore

struct JobsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Table(model.jobs) {
            TableColumn("Operation") { job in
                Text(job.operation.rawValue)
            }
            TableColumn("Archive") { job in
                Text(job.sourceName)
            }
            TableColumn("Status") { job in
                Text(job.status.displayName)
            }
            TableColumn("Progress") { job in
                VStack(alignment: .leading) {
                    if job.progress.isIndeterminate && !job.status.isFinished {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        ProgressView(value: job.progress.fraction ?? (job.status == .completed ? 1 : 0))
                    }
                    Text("\(job.progress.percentText)  \(job.progress.bytesText)  \(job.progress.speedText)  \(job.progress.etaText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            TableColumn("Error") { job in
                Text(job.errorMessage ?? "")
                    .foregroundStyle(.red)
            }
        }
        .toolbar {
            Button("Cancel Selected Job") {
                if let job = model.jobs.first(where: { !$0.status.isFinished }) {
                    Task { await model.jobManager.cancel(job.id) }
                }
            }
        }
        .onAppear { model.refreshJobs() }
        .padding()
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            Form {
                Toggle("Open archives automatically", isOn: $model.settings.openArchivesAutomatically)
                Toggle("Confirm destructive operations", isOn: $model.settings.confirmDestructiveOperations)
                Toggle("Verify after create", isOn: $model.settings.verifyAfterCreate)
            }
            .tabItem { Label("General", systemImage: "gear") }

            Form {
                Picker("Overwrite policy", selection: $model.settings.overwritePolicy) {
                    ForEach(OverwritePolicy.allCases) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
                Toggle("Preserve metadata", isOn: $model.settings.preserveMetadata)
                Toggle("Preserve permissions", isOn: $model.settings.preservePermissions)
                Toggle("Preserve symlinks", isOn: $model.settings.preserveSymlinks)
            }
            .tabItem { Label("Extraction", systemImage: "tray.and.arrow.down") }

            Form {
                Picker("Default format", selection: $model.settings.defaultFormat) {
                    Text("ZIP").tag(ArchiveFormat.zip)
                    Text("RAR").tag(ArchiveFormat.rar5)
                    Text("7Z").tag(ArchiveFormat.sevenZip)
                    Text("TAR.GZ").tag(ArchiveFormat.tarGz)
                }
                Picker("Default level", selection: $model.settings.defaultCompressionLevel) {
                    ForEach(CompressionLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
            }
            .tabItem { Label("Compression", systemImage: "archivebox") }

            Form {
                Toggle("Use Keychain", isOn: $model.settings.useKeychain)
                Toggle("Remember passwords (only if Keychain enabled)", isOn: $model.settings.rememberPasswords)
                    .disabled(!model.settings.useKeychain)
                Button("Clear stored passwords") {
                    PasswordStore().deleteAll()
                }
            }
            .tabItem { Label("Passwords", systemImage: "key") }

            Form {
                Toggle("Finder: Extract Here", isOn: $model.settings.finderExtractHere)
                Toggle("Finder: Compress to RAR", isOn: $model.settings.finderCompressRAR)
                Toggle("Finder: Compress to ZIP", isOn: $model.settings.finderCompressZIP)
                Toggle("Finder: Compress to 7Z", isOn: $model.settings.finderCompress7Z)
                Text("File associations are declared in Info.plist. Use System Settings → Desktop & Dock → Default apps, or `duti`, to change handlers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tabItem { Label("Finder", systemImage: "folder") }

            Form {
                Picker("Appearance", selection: $model.settings.appearance) {
                    ForEach(AppSettings.AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }
            .tabItem { Label("Appearance", systemImage: "circle.lefthalf.filled") }

            Form {
                Toggle("Logging", isOn: $model.settings.loggingEnabled)
                LabeledContent("libarchive") {
                    Text("linked")
                }
                LabeledContent("7-Zip helper") {
                    Text(DefaultBackends.sevenZipAvailable() ? "available" : "missing")
                }
                LabeledContent("UnRAR helper") {
                    Text(DefaultBackends.unrarAvailable() ? "available" : "missing")
                }
                LabeledContent("RAR create helper") {
                    Text(DefaultBackends.rarCreateAvailable() ? "available" : "missing")
                }
                Button("Export diagnostics") { exportDiagnostics() }
                Button("Clean leftover temporary files") {
                    Task { try? await TempDirectoryManager.shared.cleanupInterrupted() }
                }
            }
            .tabItem { Label("Advanced", systemImage: "wrench") }
        }
        .padding(20)
        .frame(width: 520, height: 380)
        .onDisappear {
            Task {
                let snapshot = model.settings
                try? await SettingsStore.shared.update(snapshot)
            }
        }
    }

    private func exportDiagnostics() {
        let report = """
        Archivist diagnostics
        7-Zip: \(DefaultBackends.sevenZipAvailable())
        UnRAR: \(DefaultBackends.unrarAvailable())
        RAR create: \(DefaultBackends.rarCreateAvailable())
        Jobs: \(model.jobs.count)
        """
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "archivist-diagnostics.txt"
        if panel.runModal() == .OK, let url = panel.url {
            try? report.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

import AppKit
import ArchiveBackends
