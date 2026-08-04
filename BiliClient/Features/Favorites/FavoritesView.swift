import SwiftUI

/// 我的老师：本地收藏的 UP主 列表，是 app 的主页。
struct FavoritesView: View {
    @Environment(FavoritesStore.self) private var favorites

    var body: some View {
        Group {
            if favorites.items.isEmpty {
                ContentUnavailableView(
                    "还没有收藏老师",
                    systemImage: "star",
                    description: Text("到「搜索」里找到老师账号并收藏，专注看Ta的教学视频")
                )
            } else {
                List {
                    ForEach(favorites.items) { up in
                        NavigationLink {
                            SpaceVideoListView(up: up)
                        } label: {
                            FavoriteUpRow(up: up)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            favorites.remove(mid: favorites.items[index].mid)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("我的老师")
    }
}

private struct FavoriteUpRow: View {
    let up: FavoriteUp

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(urlString: up.avatarURL) {
                Circle().fill(.secondary.opacity(0.2))
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(up.name).font(.headline)
                if !up.sign.isEmpty {
                    Text(up.sign)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
