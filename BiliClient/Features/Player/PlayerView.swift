import SwiftUI
import AVKit

/// 播放页：沉浸全屏 + 自绘控制层。
/// 只保留：退出、播放/暂停、进度条、倍速、清晰度、课程列表。
/// 无全屏 / 画中画 / 投屏按钮。
struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: PlayerViewModel
    @State private var showPlaylist = false
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    init(playlist: CoursePlaylist) {
        _vm = State(initialValue: PlayerViewModel(playlist: playlist))
    }

    private var hasPlaylist: Bool { vm.hasMultipleEpisodes || vm.hasMultipleParts }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            NativePlayerView(player: vm.player)
                .ignoresSafeArea()

            // 点击切换控制层显隐
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { toggleControls() }

            if controlsVisible {
                controlLayer
                    .transition(.opacity)
            }

            if vm.isLoading {
                ProgressView().controlSize(.large).tint(.white)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden()
        .task {
            await vm.loadInitial()
            scheduleHide()
        }
        .onDisappear {
            hideTask?.cancel()
            vm.stop()
        }
        .sheet(isPresented: $showPlaylist) {
            PlaylistDrawer(vm: vm, isPresented: $showPlaylist)
                .presentationDetents([.medium, .large])
                .presentationBackground(.regularMaterial)
        }
    }

    // MARK: - 控制层

    private var controlLayer: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            centerControls
            Spacer()
            bottomBar
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.5), .clear, .clear, .black.opacity(0.6)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        )
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.35), in: Circle())
            }

            Text(vm.currentEpisode.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.leading, 4)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var centerControls: some View {
        HStack(spacing: 48) {
            if vm.hasMultipleEpisodes {
                controlButton("backward.end.fill", disabled: !vm.canGoPrev) {
                    Task { await vm.goPrev() }
                }
            }
            Button {
                vm.togglePlayPause()
                scheduleHide()
            } label: {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            if vm.hasMultipleEpisodes {
                controlButton("forward.end.fill", disabled: !vm.canGoNext) {
                    Task { await vm.goNext() }
                }
            }
        }
    }

    private func controlButton(_ icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(disabled ? .white.opacity(0.3) : .white)
        }
        .disabled(disabled)
    }

    // MARK: - 底部：进度 + 功能按钮

    private var bottomBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text(timeString(vm.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white)

                Slider(
                    value: Binding(
                        get: { vm.currentTime },
                        set: { vm.seek(to: $0) }
                    ),
                    in: 0...max(vm.duration, 1)
                )
                .tint(.pink)

                Text(timeString(vm.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white)
            }

            HStack(spacing: 20) {
                speedMenu
                qualityMenu
                Spacer()
                if hasPlaylist {
                    Button {
                        showPlaylist = true
                    } label: {
                        Label("选集", systemImage: "list.bullet")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private var speedMenu: some View {
        Menu {
            ForEach(vm.speedOptions, id: \.self) { speed in
                Button {
                    vm.setSpeed(speed)
                } label: {
                    Label(speedLabel(speed), systemImage: vm.currentSpeed == speed ? "checkmark" : "")
                }
            }
        } label: {
            Text(vm.currentSpeed == 1.0 ? "倍速" : speedLabel(vm.currentSpeed))
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var qualityMenu: some View {
        if !vm.availableQualities.isEmpty {
            Menu {
                ForEach(vm.availableQualities) { option in
                    Button {
                        Task { await vm.changeQuality(to: option.qn) }
                    } label: {
                        Label(option.label, systemImage: vm.currentQuality == option.qn ? "checkmark" : "")
                    }
                }
            } label: {
                Text(Quality.label(for: vm.currentQuality))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - 控制显隐

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible.toggle()
        }
        if controlsVisible { scheduleHide() }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) { controlsVisible = false }
                }
            }
        }
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let s = Int(seconds)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    private func speedLabel(_ speed: Float) -> String {
        String(format: "%.2g×", speed)
    }
}

/// 课程抽屉：剧集目录（多独立视频）或分P列表（单视频多P）。
private struct PlaylistDrawer: View {
    @Bindable var vm: PlayerViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                if vm.hasMultipleEpisodes {
                    Section("课程目录 · \(vm.episodeCount) 节") {
                        ForEach(Array(vm.playlist.episodes.enumerated()), id: \.element.id) { index, ep in
                            row(index: index, title: ep.title, selected: index == vm.currentEpisodeIndex) {
                                Task {
                                    await vm.loadEpisode(index: index)
                                    isPresented = false
                                }
                            }
                        }
                    }
                } else if vm.hasMultipleParts {
                    Section("分P · \(vm.pages.count)") {
                        ForEach(Array(vm.pages.enumerated()), id: \.element.id) { index, part in
                            row(index: index, title: part.part, selected: index == vm.currentPageIndex) {
                                Task {
                                    await vm.selectPart(index)
                                    isPresented = false
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(vm.playlist.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { isPresented = false }
                }
            }
        }
    }

    private func row(index: Int, title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                if selected {
                    Image(systemName: "play.fill")
                        .font(.caption).foregroundStyle(Color.accentColor).frame(width: 24)
                } else {
                    Text("\(index + 1)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary).frame(width: 24)
                }
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(selected ? Color.accentColor : .primary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}
