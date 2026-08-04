import SwiftUI

/// 根视图：经典侧滑抽屉 UI。
/// 汉堡按钮 / 左缘侧滑 打开抽屉，选择分区后自动收起。
struct RootView: View {
    @State private var session = SessionStore()
    @State private var favorites = FavoritesStore()
    @State private var selection: SidebarItem = .favorites
    @State private var drawerOpen = false

    var body: some View {
        SideDrawer(isOpen: $drawerOpen) {
            DrawerMenu(selection: $selection, isOpen: $drawerOpen)
        } content: {
            NavigationStack {
                detail
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
        .task { await session.refresh() }
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
        }
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
