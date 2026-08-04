import Foundation

/// 面向业务的接口封装，屏蔽 APIClient 的细节。
enum BiliService {
    private static let api = APIClient.shared

    // MARK: - 登录

    /// 拉取登录用户资料（未登录返回 nil）。
    static func fetchCurrentUser() async throws -> CurrentUser? {
        let nav: NavResponse = try await api.getRaw(
            "https://api.bilibili.com/x/web-interface/nav",
            as: NavResponse.self
        )
        guard nav.data.isLogin,
              let mid = nav.data.mid,
              let name = nav.data.uname else {
            return nil
        }
        return CurrentUser(id: mid, name: name, avatarURL: nav.data.face ?? "")
    }

    // MARK: - 搜索 UP主（只搜账号，不搜视频）

    static func searchUsers(keyword: String) async throws -> [SearchUserItem] {
        let data: SearchUserResult = try await api.get(
            "https://api.bilibili.com/x/web-interface/wbi/search/type",
            query: [
                "search_type": "bili_user",
                "keyword": keyword,
                "page": "1"
            ],
            signed: true,
            as: SearchUserResult.self
        )
        return data.result ?? []
    }

    // MARK: - UP主投稿

    static func fetchSpaceVideos(mid: Int, page: Int = 1, pageSize: Int = 30, order: VideoSortOrder = .pubdate) async throws -> SpaceSearchData {
        // 按播放量排序会触发风控 -352，需要访客 cookie(buvid3) + web 风控参数。
        await api.ensureVisitorCookies()
        return try await api.get(
            "https://api.bilibili.com/x/space/wbi/arc/search",
            query: [
                "mid": String(mid),
                "pn": String(page),
                "ps": String(pageSize),
                "order": order.apiValue,
                "platform": "web",
                "web_location": "1550101",
                "dm_img_list": "[]",
                "dm_img_str": "V2ViR0wgMS4w",
                "dm_cover_img_str": "",
                "dm_img_inter": "{\"ds\":[],\"wh\":[0,0,0],\"of\":[0,0,0]}"
            ],
            signed: true,
            as: SpaceSearchData.self
        )
    }

    // MARK: - 合集与系列

    /// 取 UP主 的合集(season)与系列(series)列表。
    static func fetchSeasonsAndSeries(mid: Int, page: Int = 1, pageSize: Int = 20) async throws -> ItemsLists {
        let resp: SeasonsSeriesResponse = try await api.get(
            "https://api.bilibili.com/x/polymer/web-space/seasons_series_list",
            query: [
                "mid": String(mid),
                "page_num": String(page),
                "page_size": String(pageSize)
            ],
            as: SeasonsSeriesResponse.self
        )
        return resp.itemsLists
    }

    /// 取某合集的全部视频。分页字段：page_num / page_size。
    static func fetchSeasonArchives(mid: Int, seasonID: Int, page: Int = 1, pageSize: Int = 30) async throws -> SeasonArchivesData {
        try await api.get(
            "https://api.bilibili.com/x/polymer/web-space/seasons_archives_list",
            query: [
                "mid": String(mid),
                "season_id": String(seasonID),
                "page_num": String(page),
                "page_size": String(pageSize)
            ],
            as: SeasonArchivesData.self
        )
    }

    /// 取某系列的全部视频。分页字段：pn / ps。
    static func fetchSeriesArchives(mid: Int, seriesID: Int, page: Int = 1, pageSize: Int = 30) async throws -> SeriesArchivesData {
        try await api.get(
            "https://api.bilibili.com/x/series/archives",
            query: [
                "mid": String(mid),
                "series_id": String(seriesID),
                "pn": String(page),
                "ps": String(pageSize)
            ],
            as: SeriesArchivesData.self
        )
    }

    // MARK: - 播放

    /// 取视频分P列表（拿 cid）。
    static func fetchPages(bvid: String) async throws -> [VideoPage] {
        try await api.get(
            "https://api.bilibili.com/x/player/pagelist",
            query: ["bvid": bvid],
            as: [VideoPage].self
        )
    }

    /// 取 durl 播放地址。qn 为清晰度（16=360P,32=480P,64=720P,80=1080P）。
    static func fetchPlayURL(bvid: String, cid: Int, qn: Int) async throws -> PlayURLData {
        try await api.get(
            "https://api.bilibili.com/x/player/wbi/playurl",
            query: [
                "bvid": bvid,
                "cid": String(cid),
                "qn": String(qn),
                "fnval": "1",   // durl(mp4)
                "fnver": "0",
                "fourk": "1",
                "platform": "html5"
            ],
            signed: true,
            as: PlayURLData.self
        )
    }
}

/// 全部视频的排序方式（对应 space arc/search 的 order 参数）。
enum VideoSortOrder: String, CaseIterable, Identifiable {
    case pubdate   // 最新发布
    case click     // 最多播放

    var id: String { rawValue }

    var apiValue: String { rawValue }

    var title: String {
        switch self {
        case .pubdate: return "最新发布"
        case .click: return "最多播放"
        }
    }

    var systemImage: String {
        switch self {
        case .pubdate: return "calendar"
        case .click: return "play.circle"
        }
    }
}

/// 清晰度码表。
enum Quality {
    static let options: [QualityOption] = [
        QualityOption(qn: 80, label: "1080P"),
        QualityOption(qn: 64, label: "720P"),
        QualityOption(qn: 32, label: "480P"),
        QualityOption(qn: 16, label: "360P")
    ]

    static func label(for qn: Int) -> String {
        options.first { $0.qn == qn }?.label ?? "\(qn)"
    }
}
