import SwiftUI
import SwiftData

enum ExperimentPresentLevel: String, CaseIterable, Identifiable {
    case metrics = "Metrics"
    case overview = "Overview"
    case logs = "Logs"

    var id: Self { self }
}

struct ExperimentDetailView: View {
    let projectPath: String
    let initial: Experiment
    @Query private var sessions: [SessionModel]
    @State private var selectedLevel: ExperimentPresentLevel = .overview
    @State private var detail: Experiment?
    @State private var loading = false
    @State private var errorMessage: String?
    private var run: Experiment { detail ?? initial }

    var body: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "实验信息分类"), selection: $selectedLevel) {
                ForEach(ExperimentPresentLevel.allCases) { level in
                    Text(LocalizedStringKey(level.rawValue)).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if loading {
                ProgressView(String(localized: "更新实验信息…"))
                    .padding(.bottom, 8)
            }
            if let errorMessage {
                VStack(spacing: 8) {
                    Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
                    Button(String(localized: "重试")) { Task { await load() } }
                        .disabled(loading)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            switch selectedLevel {
            case .overview:
                ExperimentOverviewView(run: run)
                    .refreshable { await load() }
            case .metrics:
                ExperimentMetricsView(projectPath: projectPath, run: run)
            case .logs:
                ExperimentLogsView(projectPath: projectPath, run: run)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(run.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { if detail == nil { await load() } }
    }

    private func load() async {
        guard !loading else { return }
        guard let endpoint = sessions.first?.hostUrl, let sid = KeychainService.read(.sessionSID) else {
            errorMessage = String(localized: "登录信息缺失，请重新登录。")
            return
        }
        loading = true
        defer { loading = false }
        do {
            let response: Experiment = try await projectRequest(endpoint: endpoint, path: projectPath + "/runs/" + initial.slug, sid: sid)
            try Task.checkCancellation()
            detail = response
            errorMessage = nil
        } catch {
            if !Task.isCancelled { errorMessage = String(localized: "实验加载失败：\(error.localizedDescription)") }
        }
    }
}
