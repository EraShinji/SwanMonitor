//
//  ExperimentOverviewView.swift
//  SwanMonitor
//
//  Created by aleclanned on 10/2/26.
//

import SwiftUI

struct ExperimentOverviewView: View {
    let run: Experiment
    private var parameters: [String] {
        (run.profile?.config ?? [:]).keys.sorted {
            let lhs = run.profile?.config?[$0]?.sort ?? 0
            let rhs = run.profile?.config?[$1]?.sort ?? 0
            return lhs == rhs ? $0 < $1 : lhs < rhs
        }
    }

    var body: some View {
        List {
            Section(String(localized: "实验信息")) {
                LabeledContent(String(localized: "名称"), value: run.name)
                LabeledContent("ID", value: run.slug)
                LabeledContent(String(localized: "状态")) {
                    TrainingStatusView(status: TrainingStatus(run.state))
                }
                if let value = run.description { Text(value) }
                if let value = run.createdAt { LabeledContent(String(localized: "创建时间"), value: dateText(value)) }
                if let value = run.finishedAt { LabeledContent(String(localized: "结束时间"), value: dateText(value)) }
            }
            Section(String(localized: "配置参数")) {
                if parameters.isEmpty { Text(String(localized: "暂无配置参数")).foregroundStyle(.secondary) }
                ForEach(parameters, id: \.self) { key in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(key).font(.subheadline).foregroundStyle(.secondary)
                        Text(run.profile?.config?[key]?.value.text ?? "—").textSelection(.enabled)
                    }
                }
            }
            if let requirements = run.profile?.requirements, !requirements.isEmpty {
                Section(String(localized: "环境依赖")) {
                    Text(requirements).font(.caption.monospaced()).textSelection(.enabled)
                }
            }
        }
    }

    private func dateText(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
        return date?.formatted(date: .abbreviated, time: .standard) ?? value
    }

}
