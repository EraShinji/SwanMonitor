import SwiftUI
import SwiftData

struct BrowseView: View {
    @Query private var sessions: [SessionModel]
    @Query private var users: [UserModel]
    @State private var projects: [ProjectInfoListResponse.Project] = []
    @State private var total = 0
    @State private var statuses: [String: TrainingStatus] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastLoaded: Date?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.secondary)
                        Button(String(localized: "重试")) { Task { await loadProjects() } }
                            .disabled(isLoading)
                    }
                }
                if isLoading && projects.isEmpty {
                    ProgressView(String(localized: "正在加载项目…"))
                        .frame(maxWidth: .infinity)
                } else if projects.isEmpty && errorMessage == nil {
                    ContentUnavailableView(String(localized: "暂无项目"), systemImage: "folder", description: Text(String(localized: "当前账户尚无项目，下拉可重新加载。")))
                }
                Section("Projects"){
                    ForEach(projects) { project in
                        NavigationLink {
                            ProjectDetailView(project: project)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(project.name).font(.headline)
                                    Spacer()
                                    
                                }
                                Text(project.path).font(.caption).foregroundStyle(.secondary)
                                HStack(spacing: 10){
                                    
                                    if let count = project._count?.experiments {
                                        Text("\(count) 个实验")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    TrainingStatusView(status: statuses[project.path] ?? ((project._count?.runningExps ?? 0) > 0 ? .running : .unknown))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                if total > projects.count {
                    Text("已显示 \(projects.count) / \(total) 个项目")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Browse")
            .refreshable { await loadProjects() }
            .task {
                if Date().timeIntervalSince(lastLoaded ?? .distantPast) >= 30 {
                    await loadProjects()
                }
            }
        }
    }

    private func loadProjects() async {
        guard !isLoading else { return }
        guard let endpoint = sessions.first?.hostUrl,
              let url = URL(string: endpoint), ["http", "https"].contains(url.scheme), url.host != nil,
              let username = users.first?.userName, !username.isEmpty,
              let sid = KeychainService.read(.sessionSID) else {
            errorMessage = String(localized: "登录信息不完整，请重新登录。")
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await getProjects(endpoint: endpoint, sid: sid, username: username)
            projects = response.list
            total = response.total
            lastLoaded = Date()
            errorMessage = nil
            statuses = [:]
            for project in projects {
                if Task.isCancelled { break }
                if let runs = try? await getAllExperiments(endpoint: endpoint, path: project.path, sid: sid) {
                    statuses[project.path] = .aggregate(runs.map { TrainingStatus($0.state) })
                }
            }
        } catch {
            errorMessage = String(localized: "项目加载失败：\(error.localizedDescription)")
        }
    }
}

#Preview {
    BrowseView()
        .modelContainer(for: [SessionModel.self, UserModel.self], inMemory: true)
}
