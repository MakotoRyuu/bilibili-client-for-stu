import UIKit
import Observation

/// 扫码登录流程：申请二维码 → 轮询状态 → 成功后 URLSession 自动落 Cookie。
@Observable
final class QRLoginViewModel {
    var qrImage: UIImage?
    var status: QRLoginStatus = .waitingScan
    var errorMessage: String?

    private var qrcodeKey: String?
    private var pollTask: Task<Void, Never>?

    var statusText: String {
        switch status {
        case .waitingScan: return "请用手机 B站 App 扫码登录"
        case .scannedConfirm: return "已扫码，请在手机上确认"
        case .success: return "登录成功"
        case .expired: return "二维码已失效，请刷新"
        }
    }

    /// 申请二维码并开始轮询。
    @MainActor
    func start() async {
        errorMessage = nil
        status = .waitingScan
        do {
            let resp: QRGenerateResponse = try await APIClient.shared.getRaw(
                "https://passport.bilibili.com/x/passport-login/web/qrcode/generate",
                as: QRGenerateResponse.self
            )
            qrcodeKey = resp.data.qrcodeKey
            qrImage = QRCodeGenerator.image(from: resp.data.url, minSize: 240)
            beginPolling()
        } catch {
            errorMessage = "获取二维码失败：\(error.localizedDescription)"
        }
    }

    /// 刷新二维码。
    @MainActor
    func refresh() async {
        pollTask?.cancel()
        await start()
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func beginPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { return }
                await self.pollOnce()
                let current = await self.status
                if current == .success || current == .expired {
                    return
                }
            }
        }
    }

    @MainActor
    private func pollOnce() async {
        guard let key = qrcodeKey else { return }
        do {
            let resp: QRPollResponse = try await APIClient.shared.getRaw(
                "https://passport.bilibili.com/x/passport-login/web/qrcode/poll",
                query: ["qrcode_key": key],
                as: QRPollResponse.self
            )
            switch resp.data.code {
            case 0:
                // 登录成功：URLSession 已自动存下 Set-Cookie，落盘持久化。
                CookieStore.shared.persistFromStorage()
                status = .success
            case 86090:
                status = .scannedConfirm
            case 86101:
                status = .waitingScan
            case 86038:
                status = .expired
            default:
                break
            }
        } catch {
            // 轮询期偶发网络错误忽略，继续下一轮。
        }
    }
}
