import Foundation

// MARK: - 合集与系列列表 (seasons_series_list)

struct SeasonsSeriesResponse: Decodable {
    let itemsLists: ItemsLists

    enum CodingKeys: String, CodingKey {
        case itemsLists = "items_lists"
    }
}

struct ItemsLists: Decodable {
    let seasonsList: [SeasonItem]
    let seriesList: [SeriesItem]

    enum CodingKeys: String, CodingKey {
        case seasonsList = "seasons_list"
        case seriesList = "series_list"
    }
}

/// 合集（season）：UP主 整理的正式课程合集。
struct SeasonItem: Decodable, Identifiable {
    let meta: SeasonMeta
    let archives: [ArchiveItem]

    var id: Int { meta.seasonID }
}

struct SeasonMeta: Decodable {
    let seasonID: Int
    let name: String
    let cover: String
    let total: Int
    let description: String?

    enum CodingKeys: String, CodingKey {
        case seasonID = "season_id"
        case name, cover, total, description
    }
}

/// 系列（series）：较松散的视频归类。
struct SeriesItem: Decodable, Identifiable {
    let meta: SeriesMeta
    let archives: [ArchiveItem]

    var id: Int { meta.seriesID }
}

struct SeriesMeta: Decodable {
    let seriesID: Int
    let name: String
    let cover: String
    let total: Int
    let description: String?

    enum CodingKeys: String, CodingKey {
        case seriesID = "series_id"
        case name, cover, total, description
    }
}

// MARK: - 合集/系列内的视频条目 (archives)

/// season/series 里的视频条目（字段比 space vlist 略不同，单独建模）。
struct ArchiveItem: Decodable, Identifiable {
    let aid: Int
    let bvid: String
    let title: String
    let pic: String
    let duration: Int      // 秒
    let pubdate: Int

    var id: String { bvid }

    /// 秒 → "mm:ss" / "h:mm:ss"
    var lengthText: String {
        let h = duration / 3600
        let m = (duration % 3600) / 60
        let s = duration % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

struct SeasonArchivesData: Decodable {
    let archives: [ArchiveItem]
    let page: SeasonPage
}

struct SeasonPage: Decodable {
    let pageNum: Int
    let pageSize: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case pageNum = "page_num"
        case pageSize = "page_size"
        case total
    }
}

struct SeriesArchivesData: Decodable {
    let archives: [ArchiveItem]
    let page: SeriesPage
}

struct SeriesPage: Decodable {
    let num: Int
    let size: Int
    let total: Int
}
