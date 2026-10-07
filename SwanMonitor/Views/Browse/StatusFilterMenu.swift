import SwiftUI

struct StatusFilterMenu: View {
    @Binding var selection: TrainingStatus?

    var body: some View {
        Menu {
            Button { selection = nil } label: {
                if selection == nil {
                    Label(String(localized: "全部状态"), systemImage: "checkmark")
                } else {
                    Text(String(localized: "全部状态"))
                }
            }
            Divider()
            ForEach([TrainingStatus.running, .finished, .stopped, .unknown], id: \.self) { status in
                Button { selection = status } label: {
                    if selection == status {
                        Label(status.title, systemImage: "checkmark")
                    } else {
                        Text(status.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "square.stack.3d.up")
                Image(systemName: "chevron.down").font(.caption2)
            }
            .foregroundStyle(selection == nil ? Color.secondary : Color.accentColor)
        }
        .accessibilityLabel(String(localized: "按状态筛选"))
    }
}

#Preview {
    StatusFilterMenu(selection: .constant(nil))
}
