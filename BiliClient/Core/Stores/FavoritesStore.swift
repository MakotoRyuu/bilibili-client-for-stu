import Foundation
import Observation

/// 本地收藏的 UP主（老师）。需求：只收藏用户，专注在关注的教师上。
/// 纯本地持久化到 UserDefaults，不依赖 B站云端收藏。
@Observable
final class FavoritesStore {
    private(set) var items: [FavoriteUp] = []
    private let key = "bili.favorites.ups.v1"

    init() {
        load()
    }

    func isFavorited(mid: Int) -> Bool {
        items.contains { $0.mid == mid }
    }

    func add(_ up: FavoriteUp) {
        guard !isFavorited(mid: up.mid) else { return }
        items.insert(up, at: 0)
        save()
    }

    func add(from item: SearchUserItem) {
        let avatar = item.upic.hasPrefix("http") ? item.upic : "https:\(item.upic)"
        add(FavoriteUp(
            mid: item.mid,
            name: item.uname,
            avatarURL: avatar,
            sign: item.usign ?? "",
            addedAt: Date()
        ))
    }

    func remove(mid: Int) {
        items.removeAll { $0.mid == mid }
        save()
    }

    func toggle(from item: SearchUserItem) {
        if isFavorited(mid: item.mid) {
            remove(mid: item.mid)
        } else {
            add(from: item)
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([FavoriteUp].self, from: data) else {
            return
        }
        items = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
