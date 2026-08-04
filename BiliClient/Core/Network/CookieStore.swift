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

    /// 用一批 "name=value" 写入 cookie（来自登录响应的 Set-Cookie 或 URL 参数）。
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

    private func persist() {
        let dict = Dictionary(uniqueKeysWithValues: cookies.map { ($0.name, $0.value) })
        UserDefaults.standard.set(dict, forKey: defaultsKey)
    }

    private func restore() {
        guard let dict = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String] else {
            return
        }
        setCookies(dict)
    }
}
