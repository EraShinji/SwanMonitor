import SwiftUI

/// A reusable log surface. Each item represents one source line; soft wrapping
/// does not introduce extra line numbers or modify the original text.
struct ExperimentLogContent: View {
    let lines: [LogTextLine]
    @ScaledMetric(relativeTo: .footnote) private var digitWidth = 10.0

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(lines) { line in
                    HStack(alignment: .top, spacing: 12) {
                        Text(line.number, format: .number.grouping(.never))
                            .foregroundStyle(.secondary)
                            .frame(width: gutterWidth, alignment: .trailing)
                            .accessibilityHidden(true)
                        Text(attributedText(line))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .font(.system(.footnote, design: .monospaced))
                    .lineSpacing(3)
                    .id(line.number)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func attributedText(_ line: LogTextLine) -> AttributedString {
        var result = AttributedString()
        for span in line.spans {
            var text = AttributedString(span.text)
            if let rgb = span.color {
                text.foregroundColor = Color(red: Double((rgb >> 16) & 255) / 255,
                                             green: Double((rgb >> 8) & 255) / 255,
                                             blue: Double(rgb & 255) / 255)
            }
            if span.bold { text.font = .system(.footnote, design: .monospaced).bold() }
            result += text
        }
        return result.characters.isEmpty ? AttributedString(" ") : result
    }

    private var gutterWidth: CGFloat {
        CGFloat(max(3, String(lines.last?.number ?? 1).count)) * digitWidth
    }
}
