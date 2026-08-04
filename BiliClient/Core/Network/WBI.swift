import Foundation
import CryptoKit

/// WBI 签名：B站 web 端很多接口要求带上 w_rid + wts 参数，
/// 否则会被风控返回 -403 / -412。
///
/// 算法：
/// 1. 从 nav 接口拿到 img_url / sub_url，取文件名（去扩展名）得到 img_key、sub_key。
/// 2. rawKey = img_key + sub_key（64 位），按固定的 mixinKeyEncTab 重排后取前 32 位 = mixin_key。
/// 3. 给参数加上 wts（当前秒级时间戳），按 key 升序排序。
/// 4. value 过滤掉 !'()* 字符后做 urlencode，拼成 query。
/// 5. w_rid = md5(query + mixin_key)。
enum WBI {
    /// nav 接口下发的重排表，固定值。
    private static let mixinKeyEncTab: [Int] = [
        46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
        27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
        37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
        22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52
    ]

    /// 由 img_key + sub_key 计算 mixin_key。
    static func mixinKey(imgKey: String, subKey: String) -> String {
        let raw = Array(imgKey + subKey)
        var result = ""
        for index in mixinKeyEncTab where index < raw.count {
            result.append(raw[index])
        }
        return String(result.prefix(32))
    }

    /// 从形如 ".../wbi/7cd084941338484aae1ad9425b84077c.png" 的 URL 中取出 key。
    static func extractKey(from url: String) -> String {
        guard let last = url.split(separator: "/").last else { return "" }
        return last.split(separator: ".").first.map(String.init) ?? ""
    }

    /// 给一组参数签名，返回带上 wts + w_rid 的新参数字典。
    static func sign(params: [String: String], mixinKey: String) -> [String: String] {
        var signed = params
        let wts = String(Int(Date().timeIntervalSince1970))
        signed["wts"] = wts

        // 排序 + 过滤特殊字符 + urlencode
        let query = signed.keys.sorted().map { key -> String in
            let filtered = signed[key]!.filter { !"!'()*".contains($0) }
            return "\(urlEncode(key))=\(urlEncode(filtered))"
        }.joined(separator: "&")

        let wRid = md5(query + mixinKey)
        signed["w_rid"] = wRid
        return signed
    }

    // MARK: - Helpers

    private static func urlEncode(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    private static func md5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
