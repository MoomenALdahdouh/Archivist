import AppKit
import SwiftUI
import ArchiveCore
import ArchiveBackends

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

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
                Text("Finder’s “Compress with Archivist” always creates ZIP. Use the RAR or 7Z Quick Actions when you want those formats.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tabItem { Label("Compression", systemImage: "archivebox") }

            Form {
                Toggle("Use Keychain", isOn: $model.settings.useKeychain)
                Toggle("Remember passwords (only if Keychain is enabled)", isOn: $model.settings.rememberPasswords)
                    .disabled(!model.settings.useKeychain)
                Button("Clear stored passwords") {
                    PasswordStore().deleteAll()
                }
            }
            .tabItem { Label("Passwords", systemImage: "key") }

            Form {
                Text("After Archivist is in Applications, open it once. Then right-click files in Finder and look under Quick Actions or Services:")
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Extract with Archivist")
                    Text("• Compress with Archivist (ZIP)")
                    Text("• Compress to RAR with Archivist")
                    Text("• Compress to 7Z with Archivist")
                }
                Text("If an item is missing, open System Settings → Keyboard → Keyboard Shortcuts → Services and enable the Archivist actions under Files and Folders.")
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
                    Text("bundled")
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

            Form {
                if let icon = NSApp.applicationIconImage {
                    HStack {
                        Spacer()
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 64, height: 64)
                        Spacer()
                    }
                }
                LabeledContent("Version", value: version)
                LabeledContent("License", value: "MIT")
                Text("A native macOS archive manager. RAR create and extract use official RARLAB helpers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let url = URL(string: "https://github.com/MoomenALdahdouh/Archivist") {
                    Link("Source on GitHub", destination: url)
                }
                if let url = URL(string: "https://ko-fi.com/moomenaldahdouh") {
                    Link("Buy me a coffee", destination: url)
                }
            }
            .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(20)
        .frame(width: 540, height: 400)
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
        Version: \(version)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
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
