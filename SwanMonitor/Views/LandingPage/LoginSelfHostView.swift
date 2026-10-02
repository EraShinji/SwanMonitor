//
//  LoginAPIView.swift
//  SwanMonitor
//
//  Created by aleclanned on 9/30/26.
//

import SwiftUI
import SwiftData

struct LoginSelfHostView: View {
    @State var api = ""
    @State var serverUrl:String = "https://swanlab.cn/"
    @State var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack{
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 10) {
                VStack(spacing: 0) {
                    
                    VStack{
                        formRow(title: String(localized: "自部署服务器 URL")) {
                            TextField("https://vault.example.com", text: $serverUrl)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                        }
                        Divider().padding(.leading, 16)
                        formRow(title:"API"){
                            SecureField("Input Your API Token Here", text: $api)
                        }
                        Divider().padding(.leading,16)
                    }
                    Button{
                        Task {
                            isLoading = true
                            errorMessage = nil
                            let base = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard let url = URL(string: base), let scheme = url.scheme,
                                  ["http", "https"].contains(scheme), url.host != nil else {
                                errorMessage = String(localized: "请输入完整的 http:// 或 https:// 服务器地址")
                                isLoading = false
                                return
                            }
                            if let result = await login(endpoint: base, api: api){
                                // 扩展资料获取失败也保留登录接口返回的用户名和头像。
                                let info = await getUserInfo(endpoint: base, sid: result.sid, username: result.userInfo.username)
                                do {
                                    let existing = try modelContext.fetch(FetchDescriptor<SessionModel>())
                                    let oldUsers = try modelContext.fetch(FetchDescriptor<UserModel>())
                                    guard KeychainService.save(result.sid, for: .sessionSID) else {
                                        errorMessage = String(localized: "无法保存登录凭据，请重试")
                                        isLoading = false
                                        return
                                    }
                                    existing.forEach { modelContext.delete($0) }
                                    oldUsers.forEach { modelContext.delete($0) }
                                    let dateFormatter = ISO8601DateFormatter()
                                    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                                    let expiration = dateFormatter.date(from: result.expiredAt)
                                        ?? ISO8601DateFormatter().date(from: result.expiredAt)
                                    modelContext.insert(UserModel(
                                        userName: result.userInfo.username,
                                        name: result.userInfo.name,
                                        avatarUrl: resolvedAvatarURL(result.userInfo.avatar, endpoint: base)?.absoluteString
                                            ?? resolvedAvatarURL(info?.avatarUrl, endpoint: base)?.absoluteString,
                                        institution: info?.institution,
                                        email: info?.email
                                    ))
                                    modelContext.insert(SessionModel(
                                        isAuthenticated: true,
                                        hostUrl: base,
                                        expiredTime: expiration
                                    ))
                                    try modelContext.save()
                                } catch {
                                    modelContext.rollback()
                                    KeychainService.delete(.sessionSID)
                                    errorMessage = String(localized: "无法保存用户信息，请重试")
                                }
                            }else {
                                errorMessage = String(localized: "登录失败，请检查 API Key")
                            }
                            
                            isLoading = false
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: 30)
                        } else {
                            Text("Log in")
                                .frame(maxWidth: .infinity, maxHeight: 30)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(api.isEmpty || isLoading)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                
            }
        }
        .alert("Login Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    @ViewBuilder
        func formRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                content()
                    .font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
}

#Preview {
    LoginSelfHostView()
        .modelContainer(for: [UserModel.self, SessionModel.self], inMemory: true)
}
