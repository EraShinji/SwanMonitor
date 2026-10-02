//
//  BiologicaiSecuritySettingView.swift
//  SwanMonitor
//
//  Created by aleclanned on 10/2/26.
//

import SwiftUI

struct BiologicaiSecuritySettingView: View {
    @Environment(AppLock.self) private var appLock
    @State private var showPIN = false
    @State private var showDisablePIN = false
    @State private var securityError = ""
    @State private var authenticating = false
    var body: some View {
        Section {
            Button {
                showPIN = true
            } label: {
                Label(appLock.hasPIN ? String(localized: "重置 PIN") : String(localized: "创建 PIN"), systemImage: "lock")
            }
            Toggle(isOn: Binding(get: { appLock.biometrics && appLock.hasPIN }, set: { enabled in
                if !enabled {
                    appLock.biometrics = false
                    return
                }
                authenticating = true
                Task {
                    if await appLock.authenticateBiometrics(), appLock.hasPIN {
                        appLock.biometrics = true
                    } else {
                        securityError = String(localized: "无法启用生物识别，请确认设备已录入 Face ID 或 Touch ID，并完成验证。")
                    }
                    authenticating = false
                }
            })) {
                Label(String(localized: "生物识别解锁"), systemImage: "faceid").foregroundStyle(.tint)
            }
            .disabled(!appLock.hasPIN || authenticating)
            if appLock.hasPIN {
                Button(role: .destructive) {
                    showDisablePIN = true
                } label: {
                    Label(String(localized: "关闭 PIN 验证"), systemImage: "lock.open")
                }
                Picker(String(localized: "重新验证身份"), selection: Binding(get: { appLock.interval }, set: { appLock.interval = $0 })) {
                    Text(String(localized: "立即")).tag(0.0)
                    Text(String(localized: "1 分钟后")).tag(60.0)
                    Text(String(localized: "5 分钟后")).tag(300.0)
                    Text(String(localized: "15 分钟后")).tag(900.0)
                }
            }
        } header: {
            Text(String(localized: "安全"))
        } footer: {
            Text(appLock.hasPIN ? String(localized: "进入后台超过所选时间后需要解锁；重新启动应用始终需要验证。重置 PIN 需验证当前 PIN。") : String(localized: "创建 6 位数字 PIN 后，可启用生物识别解锁。"))
        }
        .sheet(isPresented: $showPIN) { PINView() }
        .sheet(isPresented: $showDisablePIN) { PINView(disablingPIN: true) }
        .alert(String(localized: "安全设置"), isPresented: Binding(
            get: { !securityError.isEmpty },
            set: { if !$0 { securityError = "" } }
        )) {
            Button(String(localized: "好")) { securityError = "" }
        } message: {
            Text(securityError)
        }

    }
}

#Preview {
    List { BiologicaiSecuritySettingView() }
        .environment(AppLock())
}
