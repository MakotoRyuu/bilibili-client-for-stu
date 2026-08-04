import Foundation

/// 搜索 UP主：x/web-interface/wbi/search/type?search_type=bili_user
struct SearchUserResult: Decodable {
    let result: [SearchUserItem]?
}

struct SearchUserItem: Decodable, Identifiable {
    let mid: Int
    let uname: String
    let upic: String        // 头像（可能缺 http 前缀）
    let fans: Int?
    let usign: String?      // 签名
    let videos: Int?

    var id: Int { mid }
}

/// 本地收藏的 UP主（老师）。持久化到本地，与 B站账号无关。
struct FavoriteUp: Codable, Identifiable, Equatable {
    let mid: Int
    var name: String
    var avatarURL: String
    var sign: String
    var addedAt: Date

    var id: Int { mid }
}

/// UP主投稿列表：x/space/wbi/arc/search
struct SpaceSearchData: Decodable {
    let list: SpaceList
    let page: SpacePage
}

struct SpaceList: Decodable {
    let vlist: [SpaceVideo]
}

struct SpacePage: Decodable {
    let count: Int
    let pn: Int
    let ps: Int
}

struct SpaceVideo: Decodable, Identifiable {
    let bvid: String
    let aid: Int
    let title: String
    let pic: String
    let length: String     // "12:34"
    let created: Int       // 发布时间戳
    let play: Int          // 播放量（Int 或有时字符串，用自定义解码兜底）

    var id: String { bvid }

    enum CodingKeys: String, CodingKey {
        case bvid, aid, title, pic, length, created, play
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bvid = try c.decode(String.self, forKey: .bvid)
        aid = try c.decode(Int.self, forKey: .aid)
        title = try c.decode(String.self, forKey: .title)
        pic = try c.decode(String.self, forKey: .pic)
        length = try c.decode(String.self, forKey: .length)
        created = try c.decode(Int.self, forKey: .created)
        if let n = try? c.decode(Int.self, forKey: .play) {
            play = n
        } else if let s = try? c.decode(String.self, forKey: .play), let n = Int(s) {
            play = n
        } else {
            play = 0
        }
    }
}
