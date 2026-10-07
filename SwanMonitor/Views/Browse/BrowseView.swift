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
    @State private var searchText = ""
    @State private var timeRange: ProjectTimeRange = .latest
    @State private var statusFilter: TrainingStatus?
    @State private var visibilityFilter: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterControls
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
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
                    } else if visibleProjects.isEmpty {
                        ContentUnavailableView(String(localized: "没有符合条件的项目"), systemImage: "line.3.horizontal.decrease.circle", description: Text(String(localized: "请调整筛选条件或搜索关键词后重试。")))
                    }
                    Section("Projects"){
                        ForEach(visibleProjects) { project in
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
                                        TrainingStatusView(status: status(of: project))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    if total > visibleProjects.count {
                        Text("已显示 \(visibleProjects.count) / \(total) 个项目")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .refreshable { await loadProjects() }
            }
            .navigationTitle("Browse")
            .task {
                if Date().timeIntervalSince(lastLoaded ?? .distantPast) >= 30 {
                    await loadProjects()
                }
            }
        }
    }

    private var filterControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                StatusFilterMenu(selection: $statusFilter)

                Circle().fill(Color.secondary.opacity(0.5)).frame(width: 3, height: 3)

                Menu {
                    Button { visibilityFilter = nil } label: {
                        if visibilityFilter == nil {
                            Label(String(localized: "全部可见性"), systemImage: "checkmark")
                        } else {
                            Text(String(localized: "全部可见性"))
                        }
                    }
                    Divider()
                    ForEach(visibilityOptions, id: \.self) { option in
                        Button { visibilityFilter = option } label: {
                            if visibilityFilter == option {
                                Label(option, systemImage: "checkmark")
                            } else {
                                Text(option)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "globe")
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .foregroundStyle(visibilityFilter == nil ? Color.secondary : Color.accentColor)
                }
                .accessibilityLabel(String(localized: "按可见性筛选"))

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(String(localized: "搜索项目"), text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color(.tertiarySystemFill)))
            }

            TimeRangePicker(selection: $timeRange)
        }
    }

    private var visibilityOptions: [String] {
        Array(Set(projects.compactMap(\.visibility))).sorted()
    }

    private func status(of project: ProjectInfoListResponse.Project) -> TrainingStatus {
        statuses[project.path] ?? ((project._count?.runningExps ?? 0) > 0 ? .running : .unknown)
    }

    private var visibleProjects: [ProjectInfoListResponse.Project] {
        let calendar = Calendar.current
        let now = Date()
        var result = projects
        switch timeRange {
        case .latest:
            result = result.sorted { (createdDate(of: $0) ?? .distantPast) > (createdDate(of: $1) ?? .distantPast) }
        case .week:
            if let cutoff = calendar.date(byAdding: .day, value: -7, to: now) {
                result = result.filter { (createdDate(of: $0) ?? .distantPast) >= cutoff }
            }
        case .month:
            result = result.filter { project in
                guard let date = createdDate(of: project) else { return false }
                return calendar.isDate(date, equalTo: now, toGranularity: .month)
            }
        case .year:
            result = result.filter { project in
                guard let date = createdDate(of: project) else { return false }
                return calendar.isDate(date, equalTo: now, toGranularity: .year)
            }
        case .all:
            break
        }
        if let statusFilter {
            result = result.filter { status(of: $0) == statusFilter }
        }
        if let visibilityFilter {
            result = result.filter { $0.visibility == visibilityFilter }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                || $0.path.localizedCaseInsensitiveContains(query)
                || ($0.description?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }
        return result
    }

    private func createdDate(of project: ProjectInfoListResponse.Project) -> Date? {
        guard let raw = project.createdAt else { return nil }
        if let date = Self.iso8601Fractional.date(from: raw) { return date }
        return Self.iso8601.date(from: raw)
    }

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

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
