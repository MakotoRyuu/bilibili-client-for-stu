import Foundation

/// 申请二维码：x/passport-login/web/qrcode/generate
struct QRGenerateResponse: Decodable {
    let code: Int
    let data: QRGenerateData
}

struct QRGenerateData: Decodable {
    let url: String        // 二维码内容（供手机扫）
    let qrcodeKey: String  // 轮询用的 key

    enum CodingKeys: String, CodingKey {
        case url
        case qrcodeKey = "qrcode_key"
    }
}

/// 轮询扫码状态：x/passport-login/web/qrcode/poll
/// data.code: 0=成功登录, 86101=未扫码, 86090=已扫码待确认, 86038=二维码失效
struct QRPollResponse: Decodable {
    let code: Int
    let data: QRPollData
}

struct QRPollData: Decodable {
    let url: String
    let refreshToken: String?
    let timestamp: Int?
    let code: Int
    let message: String

    enum CodingKeys: String, CodingKey {
        case url
        case refreshToken = "refresh_token"
        case timestamp
        case code
        case message
    }
}

enum QRLoginStatus: Equatable {
    case waitingScan     // 等待扫码
    case scannedConfirm  // 已扫码，等手机确认
    case success         // 登录成功
    case expired         // 二维码失效
}
