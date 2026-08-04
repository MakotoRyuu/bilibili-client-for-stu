import Foundation

/// x/web-interface/nav 响应。既用于取登录用户信息，也用于取 WBI key。
struct NavResponse: Decodable {
    let code: Int
    let data: NavData
}

struct NavData: Decodable {
    let isLogin: Bool
    let mid: Int?
    let uname: String?
    let face: String?
    let wbiImg: WbiImg

    enum CodingKeys: String, CodingKey {
        case isLogin
        case mid
        case uname
        case face
        case wbiImg = "wbi_img"
    }
}

struct WbiImg: Decodable {
    let imgURL: String
    let subURL: String

    enum CodingKeys: String, CodingKey {
        case imgURL = "img_url"
        case subURL = "sub_url"
    }
}

/// 登录用户的精简资料（需求：只显示头像 + 昵称）。
struct CurrentUser: Identifiable, Equatable {
    let id: Int
    let name: String
    let avatarURL: String
}
