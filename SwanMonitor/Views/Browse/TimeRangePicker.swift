import SwiftUI

enum ProjectTimeRange: String, CaseIterable, Identifiable {
    case latest, week, month, year, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .latest: String(localized: "最新")
        case .week: String(localized: "近7天")
        case .month: String(localized: "本月")
        case .year: String(localized: "年度")
        case .all: String(localized: "全部")
        }
    }
}

struct TimeRangePicker: View {
    @Binding var selection: ProjectTimeRange
    @Namespace private var capsule

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(ProjectTimeRange.allCases) { range in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selection = range
                        }
                    } label: {
                        Text(range.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selection == range ? Color.primary : Color.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background {
                                if selection == range {
                                    Color.clear
                                        .glassEffect(.regular.interactive(), in: .capsule)
                                        .matchedGeometryEffect(id: "selection", in: capsule)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .glassEffect(.regular, in: .capsule)
        }
    }
}

#Preview {
    TimeRangePicker(selection: .constant(.latest))
        .padding()
}
