import SwiftUI

/// 搜索：需求只允许搜 UP主账号，不搜视频内容。
struct SearchView: View {
    @Environment(FavoritesStore.self) private var favorites
    @State private var keyword = ""
    @State private var results: [SearchUserItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
            ForEach(results) { item in
                SearchUserRow(item: item)
            }
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            }
        }
        .listStyle(.plain)
        .navigationTitle("搜索老师")
        .searchable(text: $keyword, prompt: "搜索 UP主 / 老师账号")
        .onSubmit(of: .search) {
            Task { await search() }
        }
        .overlay {
            if results.isEmpty && !isLoading && errorMessage == nil {
                ContentUnavailableView(
                    "搜索老师账号",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("只能搜索账号，收藏后专注看Ta的教学视频")
                )
            }
        }
    }

    private func search() async {
        let query = keyword.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            results = try await BiliService.searchUsers(keyword: query)
        } catch {
            errorMessage = "搜索失败：\(error.localizedDescription)"
            results = []
        }
    }
}

private struct SearchUserRow: View {
    @Environment(FavoritesStore.self) private var favorites
    let item: SearchUserItem

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(urlString: item.upic) {
                Circle().fill(.secondary.opacity(0.2))
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.uname).font(.headline)
                if let sign = item.usign, !sign.isEmpty {
                    Text(sign)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let fans = item.fans {
                    Text("\(fans) 粉丝")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button {
                favorites.toggle(from: item)
            } label: {
                Image(systemName: favorites.isFavorited(mid: item.mid) ? "star.fill" : "star")
                    .foregroundStyle(favorites.isFavorited(mid: item.mid) ? .yellow : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
