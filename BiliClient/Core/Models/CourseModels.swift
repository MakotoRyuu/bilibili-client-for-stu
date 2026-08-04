import Foundation

/// 一节课 = 一个视频（bvid）。课程 = 有序的一组 CourseEpisode。
/// 两种课程形态统一到这里：
///  1. 多个独立视频（合集/系列）→ 多个 CourseEpisode，每个通常 1 个分P。
///  2. 一个视频多分P → 1 个 CourseEpisode，播放时展开成多个分P（cid）。
struct CourseEpisode: Identifiable, Equatable {
    let bvid: String
    let title: String

    var id: String { bvid }
}

/// 播放器接收的课程上下文。
struct CoursePlaylist: Equatable {
    let title: String                 // 课程名（合集/系列名，或单个视频标题）
    let episodes: [CourseEpisode]
    let startIndex: Int               // 初始播放第几集

    init(title: String, episodes: [CourseEpisode], startIndex: Int = 0) {
        self.title = title
        self.episodes = episodes
        self.startIndex = max(0, min(startIndex, episodes.count - 1))
    }

    /// 单个视频（可能内部有多分P）快捷构造。
    static func single(bvid: String, title: String) -> CoursePlaylist {
        CoursePlaylist(title: title, episodes: [CourseEpisode(bvid: bvid, title: title)])
    }

    /// 由合集/系列的 archives 构造。
    static func from(title: String, archives: [ArchiveItem], startBvid: String) -> CoursePlaylist {
        let eps = archives.map { CourseEpisode(bvid: $0.bvid, title: $0.title) }
        let idx = eps.firstIndex { $0.bvid == startBvid } ?? 0
        return CoursePlaylist(title: title, episodes: eps, startIndex: idx)
    }
}
