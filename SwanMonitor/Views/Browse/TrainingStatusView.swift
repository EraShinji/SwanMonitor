import SwiftUI

nonisolated enum TrainingStatus: Equatable {
    case running, finished, stopped, unknown

    init(_ state: String) {
        switch state.uppercased() {
        case "RUNNING": self = .running
        case "FINISHED": self = .finished
        case "STOPPED", "ABORTED", "INTERRUPTED", "CRASHED", "FAILED", "CANCELLED", "CANCELED": self = .stopped
        default: self = .unknown
        }
    }

    static func aggregate(_ states: [TrainingStatus]) -> TrainingStatus {
        if states.contains(.running) { return .running }
        if states.contains(.stopped) { return .stopped }
        if !states.isEmpty && states.allSatisfy({ $0 == .finished }) { return .finished }
        return .unknown
    }

    var title: String {
        switch self {
        case .running: String(localized: "运行中")
        case .finished: String(localized: "训练完成")
        case .stopped: String(localized: "运行中止")
        case .unknown: String(localized: "暂无状态")
        }
    }
}

struct TrainingStatusView: View {
    let status: TrainingStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var color: Color {
        switch status {
        case .running: .red
        case .finished: .green
        case .stopped: .yellow
        case .unknown: .gray
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            TimelineView(.animation(minimumInterval: 0.1, paused: status != .running || reduceMotion || scenePhase != .active)) { context in
                let pulse = (sin(context.date.timeIntervalSinceReferenceDate * .pi * 2 / 1.4) + 1) / 2
                ZStack {
                    Circle().fill(color.opacity(0.25))
                    Circle().fill(color).frame(width: 8, height: 8)
                }
                .frame(width: 16, height: 16)
                .opacity(status == .running && !reduceMotion ? 0.4 + pulse * 0.6 : 1)
            }
            Text(status.title).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.title)
    }
}
