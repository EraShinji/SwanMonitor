import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    let project: ProjectInfoListResponse.Project
    @Query private var sessions: [SessionModel]
    @State private var detail: ProjectInfoListResponse.Project?
    @State private var runs: [Experiment] = []
    @State private var total = 0
    @State private var loading = false
    @State private var loaded = false
    @State private var errorMessage: String?
    private var info: ProjectInfoListResponse.Project { detail ?? project }

    var body: some View {
        List {
            Section(String(localized: "项目信息")) {
                LabeledContent(String(localized: "训练状态")) {
                    TrainingStatusView(status: loaded ? .aggregate(runs.map { TrainingStatus($0.state) }) : .unknown)
                }
                LabeledContent(String(localized: "名称"), value: info.name)
                if let value = info.visibility { LabeledContent(String(localized: "可见性"), value: value) }
                if let archived = info.archived { LabeledContent(String(localized: "已归档"), value: archived ? String(localized: "是") : String(localized: "否")) }
                if let description = info.description, !description.isEmpty { Text(description) }
            }
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.secondary)
                    Button(String(localized: "重试")) { Task { await load() } }.disabled(loading)
                }
            }
            Section("Experiments · \(total)") {
                if loading { ProgressView(String(localized: "加载中…")) }
                if loaded && runs.isEmpty { Text(String(localized: "此项目暂无实验。")).foregroundStyle(.secondary) }
                ForEach(runs) { run in
                    NavigationLink {
                        ExperimentDetailView(projectPath: project.path, initial: run)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(run.name).font(.headline)
                            HStack(spacing: 10){
                                TrainingStatusView(status: TrainingStatus(run.state))
                                Text(run.slug).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(info.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { if !loaded { await load() } }
        .refreshable { await load() }
    }

    private func load() async {
        guard !loading else { return }
        guard let endpoint = sessions.first?.hostUrl, let sid = KeychainService.read(.sessionSID) else {
            errorMessage = String(localized: "登录信息缺失，请重新登录。")
            return
        }
        loading = true
        defer { loading = false }
        // 项目信息与实验列表独立处理，某一接口失败不遮蔽另一个接口的内容。
        var errors: [String] = []
        do {
            detail = try await projectRequest(endpoint: endpoint, path: project.path, sid: sid)
        } catch { errors.append(String(localized: "项目信息：\(error.localizedDescription)")) }
        do {
            runs = try await getAllExperiments(endpoint: endpoint, path: project.path, sid: sid)
            total = runs.count
            loaded = true
        } catch { errors.append(String(localized: "实验列表：\(error.localizedDescription)")) }
        errorMessage = errors.isEmpty ? nil : errors.joined(separator: "\n")
    }
}
