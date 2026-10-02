import SwiftUI
import SwiftData

private struct HomeExperiment: Identifiable {
    let project: ProjectInfoListResponse.Project
    let run: Experiment
    let submitted: Date?
    let finished: Date?
    var id: String { project.path + "/" + run.slug }
}

struct HomeView: View {
    @Query private var sessions: [SessionModel]
    @Query private var users: [UserModel]
    @Environment(\.scenePhase) private var scenePhase
    @State private var experiments: [HomeExperiment] = []
    @State private var loading = false
    @State private var lastLoaded: Date?
    @State private var errorMessage: String?
    @State private var selectedDay: Date?

    private let calendar = Calendar.current
    private var recent: [HomeExperiment] { Array(experiments.prefix(10)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
                            Button(String(localized: "重试")) { Task { await load() } }.disabled(loading)
                        }
                    }
                    if loading { ProgressView(String(localized: "正在更新实验…")).frame(maxWidth: .infinity) }
                    if lastLoaded != nil {
                        TimelineView(.periodic(from: .now, by: 60)) { context in
                            dashboard(at: context.date)
                        }
                        recentSection
                    } else if !loading && errorMessage == nil {
                        ContentUnavailableView(String(localized: "暂无实验数据"), systemImage: "chart.bar")
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "首页"))
            .refreshable { await load() }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                if Date().timeIntervalSince(lastLoaded ?? .distantPast) >= 30 { await load() }
            }
        }
    }

    private func dashboard(at now: Date) -> some View {
        VStack(spacing: 24) {
            HStack(spacing: 12) {
                statistic(String(localized: "正在进行"), count: experiments.filter { TrainingStatus($0.run.state) == .running }.count,
                          symbol: "waveform.path", color: .blue)
                statistic(String(localized: "今日已完成"), count: experiments.filter {
                    TrainingStatus($0.run.state) == .finished && $0.finished.map { calendar.isDate($0, inSameDayAs: now) } == true
                }.count, symbol: "checkmark.seal.fill", color: .green)
            }
            heatmap(at: now)
        }
    }

    private func statistic(_ title: String, count: Int, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 46, height: 46)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
            Text(count, format: .number).font(.system(size: 36, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }

    private func heatmap(at now: Date) -> some View {
        let month = calendar.dateInterval(of: .month, for: now)!
        let days = calendar.range(of: .day, in: .month, for: now)!
        let offset = (calendar.component(.weekday, from: month.start) + 5) % 7
        let counts = Dictionary(grouping: experiments.compactMap(\.submitted).filter {
            $0 >= month.start && $0 < month.end
        }, by: { calendar.startOfDay(for: $0) }).mapValues(\.count)
        let total = counts.values.reduce(0, +)
        let maximum = counts.values.max() ?? 0
        let selection = selectedDay.flatMap { month.contains($0) ? $0 : nil } ?? calendar.startOfDay(for: now)
        let count = counts[selection, default: 0]
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "实验热力图")).font(.headline)
                Spacer()
                Text(now, format: .dateTime.year().month()).font(.caption).foregroundStyle(.secondary)
            }
            Text("本月提交 \(total) 个实验").font(.subheadline).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 7), spacing: 7) {
                ForEach(Array(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].enumerated()), id: \.offset) { _, day in
                    Text(LocalizedStringKey(day)).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(0..<((offset + days.count + 6) / 7 * 7), id: \.self) { index in
                    if index >= offset && index < offset + days.count {
                        let date = calendar.date(byAdding: .day, value: index - offset, to: month.start)!
                        let value = counts[date, default: 0]
                        Button { selectedDay = date } label: {
                            Text(index - offset + 1, format: .number)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.primary)
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(heatColor(value, maximum: maximum), in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(date == selection ? Color.green : .clear, lineWidth: 2))
                                .opacity(date > now ? 0.35 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(date > now)
                        .accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted))，\(value) 个实验")
                        .accessibilityAddTraits(date == selection ? .isSelected : [])
                    } else {
                        Color.clear.frame(height: 34).accessibilityHidden(true)
                    }
                }
            }
            HStack(spacing: 5) {
                Text(String(localized: "少"))
                ForEach(0..<5) { level in
                    RoundedRectangle(cornerRadius: 3).fill(heatColor(level, maximum: 4)).frame(width: 14, height: 14)
                }
                Text(String(localized: "多"))
                Spacer()
                Text(String(localized: "每日提交数量"))
            }
            .font(.caption2).foregroundStyle(.secondary)
            Text("\(selection.formatted(.dateTime.month().day())) · \(count) 个 · 占本月 \(total == 0 ? 0 : Double(count) / Double(total) * 100, specifier: "%.1f")%")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }

    private func heatColor(_ count: Int, maximum: Int) -> Color {
        guard count > 0, maximum > 0 else { return Color(.tertiarySystemFill) }
        return .green.opacity(0.2 + 0.65 * Double(count) / Double(maximum))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "最近提交")).font(.title3.bold())
                Spacer()
                Text("最近 \(recent.count) 条").font(.caption).foregroundStyle(.secondary)
            }
            if recent.isEmpty {
                ContentUnavailableView(String(localized: "暂无实验"), systemImage: "flask", description: Text(String(localized: "提交实验后，即可在这里查看训练动态。")))
            }
            ForEach(recent) { item in
                NavigationLink {
                    ExperimentDetailView(projectPath: item.project.path, initial: item.run)
                } label: {
                    experimentCard(item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func experimentCard(_ item: HomeExperiment) -> some View {
        let status = TrainingStatus(item.run.state)
        let color: Color = status == .finished ? .green : status == .running ? .blue : status == .stopped ? .red : .gray
        let symbol = status == .finished ? "checkmark" : status == .running ? "waveform.path" : status == .stopped ? "xmark" : "questionmark"
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.headline).foregroundStyle(color)
                    .frame(width: 38, height: 38).background(color.opacity(0.12), in: Circle())
                Text(item.run.name).font(.headline).foregroundStyle(.primary).lineLimit(2)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            Text(item.project.name + " · " + item.project.path)
                .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            HStack {
                Text(status.title).font(.caption.weight(.medium)).foregroundStyle(color)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(color.opacity(0.08), in: Capsule())
                Spacer()
                if let date = item.submitted {
                    Text(date, style: .relative).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(String(localized: "提交时间未知")).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }

    private func load() async {
        guard !loading else { return }
        guard let endpoint = sessions.first?.hostUrl, let username = users.first?.userName,
              !username.isEmpty, let sid = KeychainService.read(.sessionSID) else {
            errorMessage = String(localized: "登录信息不完整，请重新登录。")
            return
        }
        loading = true
        defer { loading = false }
        do {
            var projects: [ProjectInfoListResponse.Project] = []
            var page = 1
            while true {
                try Task.checkCancellation()
                let response = try await getProjects(endpoint: endpoint, sid: sid, username: username, page: page)
                let known = Set(projects.map(\.path))
                let next = response.list.filter { !known.contains($0.path) }
                projects.append(contentsOf: next)
                if projects.count >= response.total { break }
                guard !next.isEmpty else { throw URLError(.cannotParseResponse) }
                page += 1
            }
            var result: [HomeExperiment] = []
            for project in projects {
                try Task.checkCancellation()
                let runs = try await getAllExperiments(endpoint: endpoint, path: project.path, sid: sid)
                result.append(contentsOf: runs.map {
                    HomeExperiment(project: project, run: $0, submitted: parseDate($0.createdAt), finished: parseDate($0.finishedAt))
                })
            }
            try Task.checkCancellation()
            experiments = result.sorted {
                let lhs = $0.submitted ?? .distantPast
                let rhs = $1.submitted ?? .distantPast
                return lhs == rhs ? $0.id < $1.id : lhs > rhs
            }
            lastLoaded = Date()
            errorMessage = nil
        } catch {
            if !Task.isCancelled {
                errorMessage = lastLoaded == nil ? String(localized: "首页加载失败：\(error.localizedDescription)") : String(localized: "更新失败，当前显示上次成功加载的数据：\(error.localizedDescription)")
            }
        }
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [SessionModel.self, UserModel.self], inMemory: true)
}
