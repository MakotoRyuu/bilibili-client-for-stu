import Foundation

enum APIError: Error, LocalizedError {
    case badURL
    case http(Int)
    case biz(code: Int, message: String)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .badURL: return "URL 无效"
        case .http(let code): return "HTTP 错误 \(code)"
        case .biz(let code, let message): return "接口错误 \(code): \(message)"
        case .decoding: return "数据解析失败"
        case .transport(let err): return err.localizedDescription
        }
    }
}

/// B站 web 接口的通用响应包装。
struct BiliResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
}

/// 统一网络客户端：注入 Referer/UA/Cookie，处理 WBI 签名与业务错误码。
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let cookies = CookieStore.shared

    // 缓存 WBI 的 mixin_key（每天更新一次即可）。
    private var cachedMixinKey: String?
    private var mixinKeyDate: Date?

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    // MARK: - 通用请求

    /// 发起 GET，解码为 BiliResponse<T> 并校验 code == 0。
    func get<T: Decodable>(
        _ path: String,
        query: [String: String] = [:],
        signed: Bool = false,
        as type: T.Type = T.self
    ) async throws -> T {
        var finalQuery = query
        if signed {
            let key = try await mixinKey()
            finalQuery = WBI.sign(params: query, mixinKey: key)
        }

        guard var components = URLComponents(string: path) else { throw APIError.badURL }
        if !finalQuery.isEmpty {
            components.queryItems = finalQuery.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw APIError.badURL }

        let request = makeRequest(url: url)
        let wrapped: BiliResponse<T> = try await send(request)
        guard wrapped.code == 0, let data = wrapped.data else {
            throw APIError.biz(code: wrapped.code, message: wrapped.message)
        }
        return data
    }

    /// 确保存在访客标识 cookie（buvid3）。部分接口（如按播放量排序）缺它会被风控 -352。
    /// 幂等：已有 buvid3 直接返回。
    func ensureVisitorCookies() async {
        if cookies.value(for: "buvid3") != nil { return }
        struct SpiResponse: Decodable {
            struct Data: Decodable { let b_3: String?; let b_4: String? }
            let data: Data?
        }
        if let resp = try? await getRaw(
            "https://api.bilibili.com/x/frontend/finger/spi",
            as: SpiResponse.self
        ), let b3 = resp.data?.b_3 {
            var pairs = ["buvid3": b3]
            if let b4 = resp.data?.b_4 { pairs["buvid4"] = b4 }
            cookies.setCookies(pairs)
        }
    }

    /// 发起原始 GET，直接解码任意 Decodable（用于结构不带标准包装的接口，如二维码登录轮询）。
    func getRaw<T: Decodable>(_ path: String, query: [String: String] = [:], as type: T.Type = T.self) async throws -> T {
        guard var components = URLComponents(string: path) else { throw APIError.badURL }
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw APIError.badURL }
        return try await send(makeRequest(url: url))
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw APIError.http(http.statusCode)
        }
        cookies.persistFromStorage()
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Origin")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        let header = cookies.cookieHeader
        if !header.isEmpty {
            request.setValue(header, forHTTPHeaderField: "Cookie")
        }
        return request
    }

    // MARK: - WBI mixin key

    private func mixinKey() async throws -> String {
        if let key = cachedMixinKey, let date = mixinKeyDate,
           Calendar.current.isDateInToday(date) {
            return key
        }
        let nav: NavResponse = try await getRaw(
            "https://api.bilibili.com/x/web-interface/nav",
            as: NavResponse.self
        )
        let img = WBI.extractKey(from: nav.data.wbiImg.imgURL)
        let sub = WBI.extractKey(from: nav.data.wbiImg.subURL)
        let key = WBI.mixinKey(imgKey: img, subKey: sub)
        cachedMixinKey = key
        mixinKeyDate = Date()
        return key
    }
}
