import Foundation

/// 视频分P信息：x/player/pagelist
struct VideoPage: Decodable, Identifiable {
    let cid: Int
    let page: Int
    let part: String       // 分P标题
    let duration: Int

    var id: Int { cid }
}

/// 播放地址（durl 格式）：x/player/wbi/playurl?fnval=1
/// fnval=1 表示请求整合 mp4（durl），非 DASH。
struct PlayURLData: Decodable {
    let quality: Int
    let acceptQuality: [Int]
    let acceptDescription: [String]
    let durl: [DurlItem]?

    enum CodingKeys: String, CodingKey {
        case quality
        case acceptQuality = "accept_quality"
        case acceptDescription = "accept_description"
        case durl
    }
}

struct DurlItem: Decodable {
    let order: Int
    let length: Int        // 毫秒
    let size: Int
    let url: String
    let backupURL: [String]?

    enum CodingKeys: String, CodingKey {
        case order, length, size, url
        case backupURL = "backup_url"
    }
}

/// 清晰度选项（用于播放器菜单）。
struct QualityOption: Identifiable, Equatable {
    let qn: Int
    let label: String
    var id: Int { qn }
}
