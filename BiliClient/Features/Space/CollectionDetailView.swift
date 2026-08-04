import SwiftUI

/// 合集/系列详情：列出全部视频。点任一视频，把整个合集作为播放列表带进播放器。
struct CollectionDetailView: View {
    enum Source {
        case season(SeasonMeta)
        case series(SeriesMeta)

        var title: String {
            switch self {
            case .season(let m): return m.name
            case .series(let m): return m.name
            }
        }
        var total: Int {
            switch self {
            case .season(let m): return m.total
            case .series(let m): return m.total
            }
        }
    }

    let up: FavoriteUp
    let source: Source

    @State private var archives: [ArchiveItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var page = 1
    @State private var hasMore = true

    var body: some View {
        List {
            Section {
                ForEach(Array(archives.enumerated()), id: \.element.id) { index, archive in
                    NavigationLink {
                        PlayerView(playlist: CoursePlaylist.from(
                            title: source.title,
                            archives: archives,
                            startBvid: archive.bvid
                        ))
                    } label: {
                        EpisodeRow(index: index + 1, archive: archive)
                    }
                    .onAppear {
                        if archive.id == archives.last?.id { Task { await loadMore() } }
                    }
                }
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            } header: {
                Text("共 \(source.total) 个视频")
            }
        }
        .listStyle(.plain)
        .navigationTitle(source.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if archives.isEmpty { await loadMore() }
        }
    }

    private func loadMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let (newItems, total): ([ArchiveItem], Int)
            switch source {
            case .season(let meta):
                let data = try await BiliService.fetchSeasonArchives(mid: up.mid, seasonID: meta.seasonID, page: page)
                (newItems, total) = (data.archives, data.page.total)
            case .series(let meta):
                let data = try await BiliService.fetchSeriesArchives(mid: up.mid, seriesID: meta.seriesID, page: page)
                (newItems, total) = (data.archives, data.page.total)
            }
            archives.append(contentsOf: newItems)
            hasMore = archives.count < total && !newItems.isEmpty
            page += 1
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
            hasMore = false
        }
    }
}

private struct EpisodeRow: View {
    let index: Int
    let archive: ArchiveItem

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32)

            RemoteImage(urlString: archive.pic) {
                Rectangle().fill(.secondary.opacity(0.15))
            }
            .frame(width: 120, height: 68)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottomTrailing) {
                Text(archive.lengthText)
                    .font(.caption2.bold())
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(.black.opacity(0.7))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(4)
            }

            Text(archive.title)
                .font(.subheadline)
                .lineLimit(2)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
