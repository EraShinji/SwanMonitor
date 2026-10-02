import SwiftUI
import SwiftData

struct ExperimentLogsView: View {
    let projectPath: String
    let run: Experiment
    @Query private var sessions: [SessionModel]
    @Environment(\.scenePhase) private var scenePhase
    @State private var projectID: String?
    @State private var lines: [LogTextLine] = []
    @State private var seen: Set<Int> = []
    @State private var nextEpoch = 0
    @State private var parser = LogANSIParser()
    @State private var loading = false
    @State private var hasMore = false
    @State private var loaded = false
    @State private var errorMessage: String?
    @State private var requestID = UUID()
    @State private var failures = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if loading { ProgressView().controlSize(.small) }
                Button { Task { await load() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel(String(localized: "刷新日志"))
                .disabled(loading)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            if let errorMessage {
                HStack {
                    Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
                    Button(String(localized: "重试")) { Task { await load() } }.disabled(loading)
                }
                .padding(.horizontal).padding(.bottom, 8)
            }
            if loaded && lines.isEmpty && errorMessage == nil {
                ContentUnavailableView(String(localized: "暂无日志"), systemImage: "text.alignleft",
                    description: Text(String(localized: "暂无日志，运行中的实验会自动更新。")))
            } else {
                ExperimentLogContent(lines: lines)
                    .refreshable { await load() }
            }
            if hasMore {
                Button(String(localized: "加载更多日志")) { Task { await load() } }
                    .disabled(loading).padding(12)
            }
        }
        .background(Color(.systemGroupedBackground))
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await load()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(min(60, 10 * pow(2, Double(min(failures, 3)))))) }
                catch { return }
                guard TrainingStatus(run.state) == .running else { return }
                if !hasMore { await load() }
            }
        }
    }

    private func load() async {
        guard !loading else { return }
        let token = UUID()
        requestID = token
        loading = true
        defer { if requestID == token { loading = false } }
        do {
            guard let endpoint = sessions.first?.hostUrl, let sid = KeychainService.read(.sessionSID) else {
                throw URLError(.userAuthenticationRequired)
            }
            let id: String
            if let projectID { id = projectID }
            else {
                let project: ProjectInfoListResponse.Project = try await projectRequest(endpoint: endpoint, path: projectPath, sid: sid)
                guard let value = project.cuid else { throw URLError(.cannotParseResponse) }
                id = value
            }
            try Task.checkCancellation()
            guard requestID == token else { return }
            let response = try await getExperimentLogs(endpoint: endpoint, sid: sid, projectID: id,
                                                       run: run, epoch: nextEpoch, level: "INFO")
            try Task.checkCancellation()
            guard requestID == token else { return }
            var known = seen
            let newEntries = response.logs.filter { known.insert($0.epoch).inserted }
            let prepared = try await prepareLogLines(newEntries, parser: parser)
            try Task.checkCancellation()
            guard requestID == token else { return }
            if response.logs.count >= 1000 && newEntries.isEmpty { throw URLError(.cannotParseResponse) }
            lines.append(contentsOf: prepared.lines)
            parser = prepared.parser
            seen = known
            if let last = prepared.lines.last { nextEpoch = last.epoch + 1 }
            projectID = id
            hasMore = !newEntries.isEmpty && (response.logs.count >= 1000 || response.count > known.count)
            loaded = true
            errorMessage = nil
            failures = 0
        } catch {
            if !Task.isCancelled && requestID == token {
                failures += 1
                errorMessage = String(localized: "日志加载失败：\(error.localizedDescription)")
            }
        }
    }
}
