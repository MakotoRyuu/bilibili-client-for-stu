import SwiftUI

/// 教师主页：合集与系列（横向卡片）+ 全部视频（网格）。
struct SpaceVideoListView: View {
    let up: FavoriteUp

    @State private var seasons: [SeasonItem] = []
    @State private var series: [SeriesItem] = []
    @State private var videos: [SpaceVideo] = []
    @State private var isLoadingCollections = false
    @State private var isLoadingVideos = false
    @State private var errorMessage: String?
    @State private var page = 1
    @State private var hasMore = true
    @State private var sortOrder: VideoSortOrder = .pubdate

    private let columns = [GridItem(.adaptive(minimum: 260), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !seasons.isEmpty || !series.isEmpty {
                    collectionsSection
                }

                allVideosSection
            }
            .padding()

            if isLoadingVideos {
                ProgressView().padding()
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).padding()
            }
        }
        .navigationTitle(up.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadCollections()
            if videos.isEmpty { await loadMoreVideos() }
        }
    }

    // MARK: - 合集与系列

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("合集与系列", systemImage: "square.stack.3d.up")
                .font(.title3.bold())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(seasons) { season in
                        NavigationLink {
                            CollectionDetailView(up: up, source: .season(season.meta))
                        } label: {
                            CollectionCard(
                                cover: season.meta.cover,
                                name: season.meta.name,
                                total: season.meta.total,
                                badge: "合集"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(series) { s in
                        NavigationLink {
                            CollectionDetailView(up: up, source: .series(s.meta))
                        } label: {
                            CollectionCard(
                                cover: s.meta.cover,
                                name: s.meta.name,
                                total: s.meta.total,
                                badge: "系列"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - 全部视频

    private var allVideosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("全部视频", systemImage: "play.square.stack")
                    .font(.title3.bold())

                Spacer()

                Picker("排序", selection: $sortOrder) {
                    ForEach(VideoSortOrder.allCases) { order in
                        Label(order.title, systemImage: order.systemImage).tag(order)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .onChange(of: sortOrder) {
                    Task { await reloadVideos() }
                }
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(videos) { video in
                    NavigationLink {
                        PlayerView(playlist: .single(bvid: video.bvid, title: video.title))
                    } label: {
                        VideoCard(pic: video.pic, title: video.title, length: video.length)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if video.id == videos.last?.id { Task { await loadMoreVideos() } }
                    }
                }
            }
        }
    }

    // MARK: - 加载

    private func loadCollections() async {
        guard seasons.isEmpty, series.isEmpty, !isLoadingCollections else { return }
        isLoadingCollections = true
        defer { isLoadingCollections = false }
        do {
            let lists = try await BiliService.fetchSeasonsAndSeries(mid: up.mid)
            seasons = lists.seasonsList
            series = lists.seriesList
        } catch {
            // 合集拉取失败不阻塞全部视频，静默即可。
        }
    }

    /// 切换排序：清空重新从第一页加载。
    private func reloadVideos() async {
        videos = []
        page = 1
        hasMore = true
        await loadMoreVideos()
    }

    private func loadMoreVideos() async {
        guard hasMore, !isLoadingVideos else { return }
        isLoadingVideos = true
        errorMessage = nil
        defer { isLoadingVideos = false }
        do {
            let data = try await BiliService.fetchSpaceVideos(mid: up.mid, page: page, order: sortOrder)
            videos.append(contentsOf: data.list.vlist)
            hasMore = videos.count < data.page.count && !data.list.vlist.isEmpty
            page += 1
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
            hasMore = false
        }
    }
}

// MARK: - 卡片组件

private struct CollectionCard: View {
    let cover: String
    let name: String
    let total: Int
    let badge: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RemoteImage(urlString: cover) {
                Rectangle().fill(.secondary.opacity(0.15))
            }
            .frame(width: 220, height: 124)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topLeading) {
                Text(badge)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.blue.opacity(0.85))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(6)
            }
            .overlay(alignment: .bottomTrailing) {
                Text("\(total) 个视频")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.black.opacity(0.7))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(6)
            }

            Text(name)
                .font(.subheadline)
                .lineLimit(2)
                .frame(width: 220, alignment: .leading)
        }
    }
}

/// 通用视频卡片（供全部视频 + 合集详情复用）。
struct VideoCard: View {
    let pic: String
    let title: String
    let length: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RemoteImage(urlString: pic) {
                Rectangle().fill(.secondary.opacity(0.15))
            }
            .frame(height: 146)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .bottomTrailing) {
                Text(length)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.black.opacity(0.7))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(6)
            }

            Text(title)
                .font(.subheadline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
