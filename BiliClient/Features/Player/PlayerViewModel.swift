import AVKit
import Observation

/// 播放器逻辑。统一处理两种课程形态：
///  - 课程 = 多个独立视频（合集/系列）→ playlist.episodes 有多集，集间用「上/下一集」切换。
///  - 课程 = 一个视频多分P → 单集，加载后 pages 有多个分P，用分P选择切换。
/// 需求：只有倍速与清晰度，无弹幕、无评论。
@Observable
final class PlayerViewModel {
    let playlist: CoursePlaylist

    var player = AVPlayer()
    var isLoading = false
    var errorMessage: String?

    // 当前集
    var currentEpisodeIndex: Int
    var currentEpisode: CourseEpisode { playlist.episodes[currentEpisodeIndex] }
    var episodeCount: Int { playlist.episodes.count }
    var hasMultipleEpisodes: Bool { episodeCount > 1 }

    // 当前集的分P
    var pages: [VideoPage] = []
    var currentPageIndex: Int = 0
    var hasMultipleParts: Bool { pages.count > 1 }

    // 画质与倍速（自绘控制层，不用系统内置控件）
    var currentQuality: Int = 64
    var availableQualities: [QualityOption] = []
    var currentSpeed: Float = 1.0
    let speedOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    // 播放进度状态
    var isPlaying = false
    var currentTime: Double = 0
    var duration: Double = 0

    var canGoPrev: Bool { currentEpisodeIndex > 0 }
    var canGoNext: Bool { currentEpisodeIndex < episodeCount - 1 }

    private var didSetupEndObserver = false
    private var timeObserver: Any?

    init(playlist: CoursePlaylist) {
        self.playlist = playlist
        self.currentEpisodeIndex = playlist.startIndex
    }

    // MARK: - 播放控制

    @MainActor
    func togglePlayPause() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            player.rate = currentSpeed
            isPlaying = true
        }
    }

    @MainActor
    func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        currentTime = seconds
    }

    @MainActor
    func setSpeed(_ speed: Float) {
        currentSpeed = speed
        if isPlaying { player.rate = speed }
    }

    // MARK: - 加载

    @MainActor
    func loadInitial() async {
        configureAudioSession()
        setupEndObserver()
        setupTimeObserver()
        await loadEpisode(index: currentEpisodeIndex)
    }

    /// 配置音频会话为 .playback，使视频在真机静音拨片开启时也能出声。
    /// 默认的 .soloAmbient 会跟随静音开关，导致无声。
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // 配置失败不影响画面播放，仅记录。
            print("AVAudioSession 配置失败：\(error.localizedDescription)")
        }
    }

    /// 切换到指定集（多独立视频课程）。
    @MainActor
    func loadEpisode(index: Int) async {
        guard playlist.episodes.indices.contains(index) else { return }
        currentEpisodeIndex = index
        currentPageIndex = 0
        pages = []
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            pages = try await BiliService.fetchPages(bvid: currentEpisode.bvid)
            guard !pages.isEmpty else {
                errorMessage = "找不到视频分P"
                return
            }
            try await loadStream(qn: currentQuality)
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    /// 切换分P（单视频多分P课程）。
    @MainActor
    func selectPart(_ index: Int) async {
        guard pages.indices.contains(index), index != currentPageIndex else { return }
        currentPageIndex = index
        do {
            try await loadStream(qn: currentQuality)
        } catch {
            errorMessage = "切换分P失败：\(error.localizedDescription)"
        }
    }

    @MainActor
    func goPrev() async {
        guard canGoPrev else { return }
        await loadEpisode(index: currentEpisodeIndex - 1)
    }

    @MainActor
    func goNext() async {
        guard canGoNext else { return }
        await loadEpisode(index: currentEpisodeIndex + 1)
    }

    @MainActor
    func changeQuality(to qn: Int) async {
        guard qn != currentQuality else { return }
        currentQuality = qn
        let resume = player.currentTime()
        do {
            try await loadStream(qn: qn, resumeTo: resume)
        } catch {
            errorMessage = "切换清晰度失败：\(error.localizedDescription)"
        }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        NotificationCenter.default.removeObserver(self)
        // 退出播放页时释放音频会话，交还给系统。
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - 内部

    @MainActor
    private func loadStream(qn: Int, resumeTo time: CMTime? = nil) async throws {
        guard pages.indices.contains(currentPageIndex) else { return }
        let cid = pages[currentPageIndex].cid
        let data = try await BiliService.fetchPlayURL(bvid: currentEpisode.bvid, cid: cid, qn: qn)

        availableQualities = data.acceptQuality.compactMap { code in
            Quality.options.first { $0.qn == code }
        }
        currentQuality = data.quality

        guard let urlString = data.durl?.first?.url,
              let url = URL(string: urlString) else {
            throw APIError.biz(code: -1, message: "无可用播放地址")
        }

        let headers = [
            "Referer": "https://www.bilibili.com",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        ]
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)
        if let time { await player.seek(to: time) }
        player.play()
        player.rate = currentSpeed
        isPlaying = true

        // 更新总时长
        if let seconds = try? await item.asset.load(.duration).seconds, seconds.isFinite {
            duration = seconds
        }
    }

    /// 周期性刷新当前播放时间。
    @MainActor
    private func setupTimeObserver() {
        guard timeObserver == nil else { return }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            if let dur = self.player.currentItem?.duration.seconds, dur.isFinite, dur > 0 {
                self.duration = dur
            }
            self.isPlaying = self.player.timeControlStatus == .playing
        }
    }

    /// 播放结束后自动进入下一分P，或下一集。
    @MainActor
    private func setupEndObserver() {
        guard !didSetupEndObserver else { return }
        didSetupEndObserver = true
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.currentPageIndex < self.pages.count - 1 {
                    await self.selectPart(self.currentPageIndex + 1)
                } else if self.canGoNext {
                    await self.goNext()
                }
            }
        }
    }
}
