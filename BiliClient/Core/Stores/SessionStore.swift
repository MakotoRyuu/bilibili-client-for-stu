import Foundation
import Observation

/// 登录会话状态。需求：登录仅用于拿高清 + 显示自己的头像昵称。
@Observable
final class SessionStore {
    var currentUser: CurrentUser?
    var isLoading = false

    var isLoggedIn: Bool { currentUser != nil }

    /// 启动时或登录后刷新用户资料。
    @MainActor
    func refresh() async {
        guard CookieStore.shared.isLoggedIn else {
            currentUser = nil
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            currentUser = try await BiliService.fetchCurrentUser()
        } catch {
            currentUser = nil
        }
    }

    @MainActor
    func logout() {
        CookieStore.shared.clear()
        currentUser = nil
    }
}
