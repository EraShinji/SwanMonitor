import SwiftUI
import SwiftData

struct ExperimentMetricsView: View {
    let projectPath: String
    let run: Experiment
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastRefresh: Date?
    @Query private var sessions: [SessionModel]
    @State private var keys: [String] = []
    @State private var curves: [String: MetricChartData] = [:]
    @State private var performance = false
    @State private var projectID = ""
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var expanded: String?

    private var visibleKeys: [String] {
        keys.filter { $0.hasPrefix("__swanlab__.") == performance }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                categoryButton(title: String(localized: "计算指标"), selected: !performance) { performance = false }
                categoryButton(title: String(localized: "性能占用"), selected: performance) { performance = true }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .animation(.easeInOut(duration: 0.2), value: performance)
            ScrollView {
                LazyVStack(spacing: 16) {
                    if loading { ProgressView() }
                    if let errorMessage {
                        Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
                        Button(String(localized: "重试")) { Task { await load() } }.disabled(loading)
                    }
                    ForEach(visibleKeys, id: \.self) { key in
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(key.replacingOccurrences(of: "__swanlab__.", with: ""))
                                    .font(.headline)
                                Spacer()
                                Button { expanded = key } label: {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .frame(width: 32, height: 32)
                                }
                                .accessibilityLabel(String(localized: "横屏查看 \(key)"))
                                .disabled(curves[key]?.isEmpty != false)
                            }
                            if let points = curves[key], !points.isEmpty {
                                MetricChartView(data: points).frame(height: 240)
                            } else {
                                Text(String(localized: "暂无数据")).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 120)
                            }
                        }
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    }
                    if !loading && visibleKeys.isEmpty && errorMessage == nil {
                        ContentUnavailableView(String(localized: "暂无指标"), systemImage: "chart.xyaxis.line")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .refreshable { await load() }
        }
        .background(Color(.systemGroupedBackground))
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(lastRefresh ?? .distantPast)
                if elapsed >= 300 { await load() }
                do {
                    let remaining = max(1, 300 - Date().timeIntervalSince(lastRefresh ?? Date()))
                    try await Task.sleep(for: .seconds(remaining))
                } catch { return }
            }
        }
        .fullScreenCover(isPresented: Binding(get: { expanded != nil }, set: { if !$0 { expanded = nil } })) {
            GeometryReader { geometry in
                let portrait = geometry.size.height > geometry.size.width
                VStack(spacing: 12) {
                    HStack {
                        Text(expanded ?? "").font(.headline)
                        Spacer()
                        Button(String(localized: "关闭")) { expanded = nil }.buttonStyle(.glass)
                    }
                    if let data = curves[expanded ?? ""] {
                        MetricChartView(data: data, interactive: true)
                    }
                }
                .padding(20)
                .frame(width: portrait ? geometry.size.height : geometry.size.width,
                       height: portrait ? geometry.size.width : geometry.size.height)
                .background(Color(.systemBackground))
                .rotationEffect(.degrees(portrait ? 90 : 0))
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }

    private func categoryButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background {
                    if selected {
                        Capsule().fill(Color.blue)
                    } else {
                        Capsule()
                            .fill(Color(.systemBackground))
                            .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: 1))
                    }
                }
        }
        .buttonStyle(.plain)
        .glassEffect()
    }

    private func reference() throws -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let id = run.cuid, let value = run.createdAt,
              let date = formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value) else {
            throw URLError(.cannotParseResponse)
        }
        var result: [String: Any] = ["projectId": projectID, "experimentId": id, "createdAt": Int(date.timeIntervalSince1970)]
        if let value = run.rootProId { result["rootProId"] = value }
        if let value = run.rootExpId { result["rootExpId"] = value }
        return result
    }

    private func load() async {
        guard !loading else { return }
        loading = true
        lastRefresh = Date()
        errorMessage = nil
        do {
            guard let endpoint = sessions.first?.hostUrl, let sid = KeychainService.read(.sessionSID) else { throw URLError(.userAuthenticationRequired) }
            let project: ProjectInfoListResponse.Project = try await projectRequest(endpoint: endpoint, path: projectPath, sid: sid)
            guard let id = project.cuid else { throw URLError(.cannotParseResponse) }
            projectID = id
            var all: [String] = []
            var cursor: String?
            repeat {
                var body: [String: Any] = ["experiments": [try reference()], "limit": 2000]
                if let cursor { body["cursor"] = cursor }
                let response: MetricKeys = try await metricsRequest(endpoint: endpoint, route: "scalar/keys", sid: sid, body: body)
                all.append(contentsOf: response.keys)
                if !response.hasMore { break }
                guard let next = response.nextCursor, next != cursor else { throw URLError(.cannotParseResponse) }
                cursor = next
                try Task.checkCancellation()
            } while true
            let newKeys = Array(Set(all)).sorted()
            var newCurves: [String: MetricChartData] = [:]
            // 分批请求，切换分类复用同一份缓存，避免每张卡片重复发起请求。
            for start in stride(from: 0, to: newKeys.count, by: 8) {
                try Task.checkCancellation()
                let batch = Array(newKeys[start..<min(start + 8, newKeys.count)])
                let columns = try batch.map { key in
                    var column = try reference()
                    column["key"] = key
                    column["experimentName"] = run.name
                    return column
                }
                let response = try await fullMetricSeries(endpoint: endpoint, sid: sid, projectID: projectID, columns: columns)
                let prepared = try await prepareMetricCharts(response)
                newCurves.merge(prepared) { _, new in new }
            }
            try Task.checkCancellation()
            keys = newKeys
            curves = newCurves
        } catch {
            if !Task.isCancelled { errorMessage = String(localized: "指标加载失败：\(error.localizedDescription)") }
        }
        loading = false
    }
}
