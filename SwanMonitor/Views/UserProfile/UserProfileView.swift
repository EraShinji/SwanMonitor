//
//  UserProfileView.swift
//  SwanMonitor
//
//  Created by aleclanned on 10/1/26.
//

import SwiftData
import SwiftUI

struct UserProfileView: View {
    @Environment(AppLock.self) private var appLock
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [SessionModel]
    @State private var showLogout = false
    @State private var securityError = ""
    @Query private var users: [UserModel]
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
    private let accentColor = Color(red: 0.73, green: 0.20, blue: 0.18)



    var body: some View {
        NavigationStack {
            List {
                Section {
                    UserDetailView()
                }
                .listRowSeparator(.hidden)

                BiologicaiSecuritySettingView()

                Section(String(localized: "关于")) {
                    NavigationLink {
                        SoftwareInformationView()
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        HStack {
                            Label(String(localized: "版本信息"), systemImage: "info.circle")
                                .foregroundStyle(accentColor)
                            Spacer()
                            Text(version)
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        OpenSourceLicenseView()
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        Label(String(localized: "开源许可"), systemImage: "doc.text")
                            .foregroundStyle(accentColor)
                    }
                }
                Section {
                    Button(role: .destructive) {
                        showLogout = true
                    } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.defaultMinListRowHeight, 56)
            // 首页不显示导航栏；详情页显式显示，避免返回时大标题改变顶部留白。
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)

        }
        .tint(accentColor)
        .confirmationDialog(String(localized: "注销登录？"), isPresented: $showLogout, titleVisibility: .visible) {
            Button(String(localized: "注销登录"), role: .destructive) {
                for session in sessions { modelContext.delete(session) }
                for user in users { modelContext.delete(user) }
                do {
                    try modelContext.save()
                    KeychainService.delete(.sessionSID)
                    appLock.clear()
                } catch {
                    modelContext.rollback()
                    securityError = String(localized: "注销失败，请重试。")
                }
            }
        } message: {
            Text(String(localized: "清除本机登录信息、PIN 和解锁设置，返回登录页面。"))
        }
        .alert(String(localized: "提示"), isPresented: Binding(get: { !securityError.isEmpty }, set: { if !$0 { securityError = "" } })) {
            Button(String(localized: "好")) { securityError = "" }
        } message: {
            Text(securityError)
        }
    }
}

#Preview {
    UserProfileView()
        .environment(AppLock())
        .modelContainer(for: [UserModel.self, SessionModel.self], inMemory: true)
}
