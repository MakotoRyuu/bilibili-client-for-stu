import SwiftUI

/// 我的：需求只要求显示头像 + 昵称 + 登录/登出。
struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @State private var showLogin = false

    var body: some View {
        VStack(spacing: 24) {
            if let user = session.currentUser {
                RemoteImage(urlString: user.avatarURL) {
                    Circle().fill(.secondary.opacity(0.2))
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())

                Text(user.name)
                    .font(.title.bold())

                Button("退出登录", role: .destructive) {
                    session.logout()
                }
                .buttonStyle(.bordered)
            } else {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)

                Text("未登录")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text("登录后可观看高清画质")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)

                Button("扫码登录") {
                    showLogin = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("我的")
        .sheet(isPresented: $showLogin) {
            QRLoginView()
        }
    }
}
