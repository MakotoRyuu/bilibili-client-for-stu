import SwiftUI
import AVKit

/// 纯视频渲染层：关闭系统内置控件，从而不显示全屏 / 画中画 / 投屏按钮。
/// 所有控制（播放、进度、倍速、清晰度、退出）由 PlayerView 自绘。
struct NativePlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = false          // 关掉系统控件（含全屏/投屏）
        vc.allowsPictureInPicturePlayback = false // 关画中画
        vc.videoGravity = .resizeAspect
        vc.updatesNowPlayingInfoCenter = false
        player.allowsExternalPlayback = false      // 关 AirPlay 投屏
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}
}
