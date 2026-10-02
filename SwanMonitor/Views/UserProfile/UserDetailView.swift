//
//  UserDetailView.swift
//  SwanMonitor
//
//  Created by aleclanned on 10/1/26.
//

import SwiftUI
import NukeUI
import SwiftData

struct UserDetailView: View {
    @Query private var users: [UserModel]
    @Query private var sessions: [SessionModel]
    private var user: UserModel? { users.first }
    private var avatarURL: URL? {
        guard let value = user?.avatarUrl else { return nil }
        return resolvedAvatarURL(value, endpoint: sessions.first?.hostUrl ?? "")
    }
    var body: some View {
        HStack(spacing: 16) {
            LazyImage(url: avatarURL) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    ZStack {
                        Color(.tertiarySystemFill)
                        if avatarURL != nil && state.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "person.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 5) {
                Text(user?.name ?? user?.userName ?? String(localized: "未登录"))
                    .font(.title3.bold())
                if let institution = user?.institution, !institution.isEmpty {
                    Text(institution)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    UserDetailView()
        .modelContainer(for: [UserModel.self, SessionModel.self], inMemory: true)
}
