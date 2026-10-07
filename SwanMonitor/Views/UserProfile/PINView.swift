import SwiftUI

// 仅负责分步输入，PIN 存储、重试限制和生物识别仍由 AppLock 处理。
struct PINView: View {
    @Environment(AppLock.self) private var appLock
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    var unlocking = false
    var disablingPIN = false

    private enum Step { case current, new, confirm }
    @State private var step: Step = .current
    @State private var pin = ""
    @State private var newPIN = ""
    @State private var error = ""
    @State private var authenticating = false
    private let letters = ["", "", "ABC", "DEF", "GHI", "JKL", "MNO", "PQRS", "TUV", "WXYZ"]

    private var title: String {
        switch step {
        case .current: disablingPIN ? String(localized: "关闭 PIN 验证") : (unlocking ? String(localized: "输入 PIN") : String(localized: "验证当前 PIN"))
        case .new: String(localized: "设置新 PIN")
        case .confirm: String(localized: "确认新 PIN")
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        if !unlocking {
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.headline)
                                    .frame(width: 44, height: 44)
                                    .glassEffect(.regular.interactive(), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(localized: "取消设置 PIN"))
                        }
                        Spacer()
                    }
                    .frame(height: 44)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text(title).font(.title2.bold())
                        Text(disablingPIN ? String(localized: "输入当前 PIN，关闭后将同时停用生物识别和自动锁定。") : step == .confirm ? String(localized: "再次输入刚才设置的 6 位 PIN") : String(localized: "输入用于解锁 SwanMonitor 的 6 位数字 PIN"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 18) {
                        ForEach(0..<6) { index in
                            Circle()
                                .fill(index < pin.count ? Color.primary : Color.clear)
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.5), lineWidth: 1.5))
                                .frame(width: 13, height: 13)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("PIN")
                    .accessibilityValue("已输入 \(pin.count) 位，共 6 位")

                    Spacer(minLength: 0)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 3), spacing: 16) {
                        ForEach(1...12, id: \.self) { key in
                            if key == 10 {
                                Color.clear.frame(height: 72).accessibilityHidden(true)
                            } else if key == 12 {
                                Button {
                                    if !pin.isEmpty { pin.removeLast() }
                                } label: {
                                    Image(systemName: "delete.left")
                                        .font(.title2)
                                        .frame(maxWidth: .infinity, minHeight: 72)
                                        .contentShape(Capsule())
                                        .glassEffect(.regular.interactive(), in: Capsule())
                                }
                                .accessibilityLabel(String(localized: "删除上一位"))
                                .disabled(pin.isEmpty)
                            } else {
                                let digit = key == 11 ? 0 : key
                                Button {
                                    guard pin.count < 6 else { return }
                                    pin.append(String(digit))
                                    if pin.count == 6 { submit() }
                                } label: {
                                    VStack(spacing: 0) {
                                        Text(String(digit)).font(.system(size: 32, weight: .regular, design: .rounded))
                                        Text(letters[digit].isEmpty ? " " : letters[digit])
                                            .font(.system(size: 9, weight: .semibold))
                                            .tracking(2)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 72)
                                    .contentShape(Capsule())
                                    .glassEffect(.regular.interactive(), in: Capsule())
                                }
                                .accessibilityLabel(String(digit))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(authenticating)
                    .frame(maxWidth: 320)

                    if unlocking && appLock.biometrics {
                        Button(String(localized: "使用生物识别解锁")) {
                            authenticating = true
                            Task {
                                if await appLock.authenticateBiometrics() {
                                    appLock.isLocked = false
                                } else {
                                    error = String(localized: "生物识别未完成，请重试或输入 PIN。")
                                }
                                authenticating = false
                            }
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .disabled(authenticating)
                        .frame(minHeight: 44)
                    } else if step == .confirm {
                        Button(String(localized: "重新设置 PIN")) {
                            newPIN = ""
                            pin = ""
                            error = ""
                            step = .new
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .frame(minHeight: 44)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .background(Color(.systemBackground))
        }
        .onAppear { step = unlocking || appLock.hasPIN ? .current : .new }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                pin = ""
                newPIN = ""
                error = ""
                step = unlocking || appLock.hasPIN ? .current : .new
            }
        }
    }

    private func submit() {
        let enteredPIN = pin
        pin = ""
        error = ""
        switch step {
        case .current:
            guard appLock.verify(enteredPIN) else {
                error = String(localized: "PIN 不正确或尝试过于频繁。连续错误 5 次后请等待 60 秒。")
                return
            }
            if disablingPIN {
                guard appLock.clear() else {
                    error = String(localized: "无法删除 PIN，请重新输入以重试。")
                    return
                }
                dismiss()
            } else if unlocking {
                appLock.isLocked = false
            } else {
                step = .new
            }
        case .new:
            newPIN = enteredPIN
            step = .confirm
        case .confirm:
            guard enteredPIN == newPIN else {
                error = String(localized: "两次输入不一致，请再次确认或重新设置。")
                return
            }
            guard appLock.savePIN(enteredPIN) else {
                error = String(localized: "PIN 保存失败，请重新输入以重试。")
                return
            }
            newPIN = ""
            dismiss()
        }
    }
}

#Preview {
    PINView()
        .environment(AppLock())
}
