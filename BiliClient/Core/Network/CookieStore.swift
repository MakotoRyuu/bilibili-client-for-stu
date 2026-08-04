import Foundation

/// 管理 B站登录 Cookie 的持久化。
/// 登录成功后拿到的 SESSDATA / bili_jct / DedeUserID 等写入这里，
/// 由 URLSession 的 HTTPCookieStorage 使用，并镜像一份到 UserDefaults 以便重启恢复。
final class CookieStore {
    static let shared = CookieStore()

    private let defaultsKey = "bili.cookies.v1"
    private let domain = ".bilibili.com"

    private init() {
        restore()
    }

    /// 当前所有 bilibili.com 下的 cookie。
    var cookies: [HTTPCookie] {
        HTTPCookieStorage.shared.cookies?.filter {
            $0.domain.contains("bilibili.com")
        } ?? []
    }

    /// 拼成请求头用的 Cookie 字符串。
    var cookieHeader: String {
        cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    /// 取某个具体 cookie 值，例如 bili_jct（CSRF token）。
    func value(for name: String) -> String? {
        cookies.first { $0.name == name }?.value
    }

    var isLoggedIn: Bool {
        value(for: "SESSDATA")?.isEmpty == false
    }

    /// SESSDATA 的真实过期时间（来自 B站 Set-Cookie，通常约 1 个月）。无则 nil。
    var sessionExpiry: Date? {
        cookies.first { $0.name == "SESSDATA" }?.expiresDate
    }

    /// 本地已能判定会话过期：存在 SESSDATA 但已过其真实过期时间。
    /// 用于无需联网即可提前判断（如冷启动）。
    var isSessionExpiredLocally: Bool {
        guard isLoggedIn, let expiry = sessionExpiry else { return false }
        return expiry <= Date()
    }

    /// 距离会话过期还剩多少天（向下取整）。已过期为 0，无过期信息为 nil。
    var daysUntilExpiry: Int? {
        guard let expiry = sessionExpiry else { return nil }
        let seconds = expiry.timeIntervalSinceNow
        if seconds <= 0 { return 0 }
        return Int(seconds / 86_400)
    }

    /// 用一批 "name=value" 写入 cookie（来自登录响应的 Set-Cookie 或 URL 参数）。
    /// 这类 cookie 由我们手工构造，没有服务端下发的过期时间，给一个较长的兜底（访客标识用）。
    func setCookies(_ pairs: [String: String]) {
        for (name, value) in pairs {
            let props: [HTTPCookiePropertyKey: Any] = [
                .domain: domain,
                .path: "/",
                .name: name,
                .value: value,
                .expires: Date().addingTimeInterval(60 * 60 * 24 * 180)
            ]
            if let cookie = HTTPCookie(properties: props) {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
        persist()
    }

    /// 直接接收 HTTPURLResponse 里的 Set-Cookie（URLSession 已自动存入 storage，这里只做持久化落盘）。
    func persistFromStorage() {
        persist()
    }

    func clear() {
        for cookie in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    // MARK: - Persistence

    /// 落盘时保留服务端下发的真实过期时间，重启后按原过期时间恢复，
    /// 从而能真实判断 SESSDATA 何时过期，而不是每次都伪造 180 天。
    private struct StoredCookie: Codable {
        let name: String
        let value: String
        let expires: Date?
    }

    private func persist() {
        let stored = cookies.map {
            StoredCookie(name: $0.name, value: $0.value, expires: $0.expiresDate)
        }
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func restore() {
        // 新格式：带真实过期时间。
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let stored = try? JSONDecoder().decode([StoredCookie].self, from: data) {
            for item in stored {
                // 恢复时若已过期则跳过，避免把死 cookie 塞回去。
                if let expires = item.expires, expires <= Date() { continue }
                var props: [HTTPCookiePropertyKey: Any] = [
                    .domain: domain,
                    .path: "/",
                    .name: item.name,
                    .value: item.value
                ]
                props[.expires] = item.expires ?? Date().addingTimeInterval(60 * 60 * 24 * 180)
                if let cookie = HTTPCookie(properties: props) {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
            }
            return
        }

        // 旧格式（仅 name→value）兼容：迁移一次，过期时间未知只能给兜底。
        if let dict = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String] {
            setCookies(dict)
        }
    }
}
