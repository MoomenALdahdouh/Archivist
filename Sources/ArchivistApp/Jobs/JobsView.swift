import SwiftUI
import ArchiveCore

struct JobsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.jobs.isEmpty {
                ContentUnavailableView(
                    "No jobs yet",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Extract, compress, and test operations appear here.")
                )
            } else {
                Table(model.jobs) {
                    TableColumn("Operation") { job in
                        Text(job.operation.displayName)
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
            }
        }
        .toolbar {
            Button("Cancel Selected Job") {
                if let job = model.jobs.first(where: { !$0.status.isFinished }) {
                    Task { await model.jobManager.cancel(job.id) }
                }
            }
            .disabled(model.jobs.allSatisfy(\.status.isFinished))
        }
        .onAppear { model.refreshJobs() }
        .padding()
    }
}
