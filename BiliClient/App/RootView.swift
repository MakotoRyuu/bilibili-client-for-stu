import SwiftUI

/// 根视图：经典侧滑抽屉 UI。
/// 汉堡按钮 / 左缘侧滑 打开抽屉，选择分区后自动收起。
struct RootView: View {
    @State private var session = SessionStore()
    @State private var favorites = FavoritesStore()
    @State private var theme = ThemeStore()
    @State private var selection: SidebarItem = .favorites
    @State private var drawerOpen = false
    @State private var showLogin = false
    @State private var warningDismissed = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        SideDrawer(isOpen: $drawerOpen) {
            DrawerMenu(selection: $selection, isOpen: $drawerOpen)
        } content: {
            NavigationStack {
                VStack(spacing: 0) {
                    sessionBanner
                    detail
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            drawerOpen.toggle()
                        } label: {
                            Image(systemName: "line.3.horizontal")
                        }
                    }
                }
            }
        }
        .environment(session)
        .environment(favorites)
        .environment(theme)
        .preferredColorScheme(theme.appearance.colorScheme)
        .animation(.easeInOut(duration: 0.2), value: theme.appearance)
        .task { await session.refresh() }
        .onChange(of: scenePhase) { _, phase in
            // 回到前台时重新校验会话，及时发现服务端已失效的情况。
            if phase == .active {
                Task { await session.refresh() }
            }
        }
        .onChange(of: session.state) { _, newState in
            if newState == .loggedIn { warningDismissed = false }
        }
        .sheet(isPresented: $showLogin) {
            QRLoginView()
        }
    }

    /// 登录过期 / 即将过期的顶部横幅。
    @ViewBuilder
    private var sessionBanner: some View {
        if session.state == .expired {
            banner(
                text: "登录已过期，点此重新登录",
                systemImage: "exclamationmark.triangle.fill",
                tint: .red
            ) {
                showLogin = true
            }
        } else if let days = session.expiryWarningDays, !warningDismissed {
            banner(
                text: days <= 0 ? "登录即将过期，建议重新登录"
                                : "登录将在 \(days) 天后过期，建议重新登录",
                systemImage: "clock.badge.exclamationmark",
                tint: .orange,
                onClose: { warningDismissed = true }
            ) {
                showLogin = true
            }
        }
    }

    private func banner(
        text: String,
        systemImage: String,
        tint: Color,
        onClose: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: systemImage)
                    Text(text).font(.subheadline.weight(.medium))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(tint)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .favorites: FavoritesView()
        case .search: SearchView()
        case .profile: ProfileView()
        }
    }
}

/// 抽屉内的菜单内容。
private struct DrawerMenu: View {
    @Environment(SessionStore.self) private var session
    @Environment(ThemeStore.self) private var theme
    @Binding var selection: SidebarItem
    @Binding var isOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 24)

            ForEach(SidebarItem.allCases) { item in
                Button {
                    selection = item
                    isOpen = false
                } label: {
                    Label(item.title, systemImage: item.systemImage)
                        .font(.body.weight(selection == item ? .semibold : .regular))
                        .foregroundStyle(selection == item ? Color.accentColor : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(
                            selection == item
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
            }

            Spacer()

            appearanceToggle
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
        }
    }

    /// 底部外观切换：点击在 浅色 / 深色 / 跟随系统 间循环。
    private var appearanceToggle: some View {
        Button {
            theme.cycle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: theme.appearance.systemImage)
                    .frame(width: 24)
                Text("外观")
                Spacer()
                Text(theme.appearance.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let user = session.currentUser {
                RemoteImage(urlString: user.avatarURL) {
                    Circle().fill(.secondary.opacity(0.2))
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name).font(.headline)
                    Text("专注学习模式").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "graduationcap.fill")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                Text("专注 B站").font(.title3.bold())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case favorites
    case search
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .favorites: return "我的老师"
        case .search: return "搜索"
        case .profile: return "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .favorites: return "star.fill"
        case .search: return "magnifyingglass"
        case .profile: return "person.crop.circle"
        }
    }
}
