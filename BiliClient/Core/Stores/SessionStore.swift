import Foundation
import Observation

/// 登录会话状态。需求：登录仅用于拿高清 + 显示自己的头像昵称。
enum SessionState: Equatable {
    case loggedOut   // 未登录
    case loggedIn    // 已登录且有效
    case expired     // 曾登录，但 Cookie 已失效（需重新登录）
}

@Observable
final class SessionStore {
    var currentUser: CurrentUser?
    var isLoading = false
    private(set) var state: SessionState = .loggedOut

    /// 距离过期不足该天数时，给出即将过期提醒。
    private let warnThresholdDays = 3
    /// 会话即将过期的剩余天数（nil = 不提醒）。
    private(set) var expiryWarningDays: Int?

    private var invalidationObserver: NSObjectProtocol?

    var isLoggedIn: Bool { currentUser != nil }

    init() {
        // 监听接口层广播的会话失效事件（如遇 -101）。
        invalidationObserver = NotificationCenter.default.addObserver(
            forName: .biliSessionInvalidated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.markExpired()
        }
    }

    deinit {
        if let observer = invalidationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// 启动时 / 登录后 / 回到前台时刷新用户资料并判定会话状态。
    @MainActor
    func refresh() async {
        // 无 SESSDATA：直接视为未登录。
        guard CookieStore.shared.isLoggedIn else {
            currentUser = nil
            state = .loggedOut
            expiryWarningDays = nil
            return
        }
        // 本地已能判定过期：不必联网。
        if CookieStore.shared.isSessionExpiredLocally {
            markExpired()
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            if let user = try await BiliService.fetchCurrentUser() {
                currentUser = user
                state = .loggedIn
                updateExpiryWarning()
            } else {
                // 有 SESSDATA 但服务端说未登录 → 已失效。
                markExpired()
            }
        } catch let APIError.biz(code, _) where code == -101 || code == -2 {
            markExpired()
        } catch {
            // 网络等其他错误：不改判会话状态，保留上次结果，避免误报过期。
        }
    }

    /// 计算即将过期提醒。
    private func updateExpiryWarning() {
        if let days = CookieStore.shared.daysUntilExpiry, days <= warnThresholdDays {
            expiryWarningDays = days
        } else {
            expiryWarningDays = nil
        }
    }

    @MainActor
    func markExpired() {
        // 仅当此前确有登录信息时才提示「过期」，否则按未登录处理。
        currentUser = nil
        expiryWarningDays = nil
        state = CookieStore.shared.isLoggedIn ? .expired : .loggedOut
    }

    @MainActor
    func logout() {
        CookieStore.shared.clear()
        currentUser = nil
        expiryWarningDays = nil
        state = .loggedOut
    }
}
