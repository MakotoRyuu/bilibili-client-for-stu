import SwiftUI

/// B站图片 CDN 需要带 Referer 才不会 403，AsyncImage 无法设请求头，
/// 这里用自定义 URLSession 加载。
struct RemoteImage<Placeholder: View>: View {
    let urlString: String
    var contentMode: ContentMode = .fill
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: urlString) { await load() }
    }

    private func load() async {
        guard uiImage == nil,
              let url = URL(string: urlString.hasPrefix("http") ? urlString : "https:\(urlString)")
        else { return }
        var request = URLRequest(url: url)
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        if let (data, _) = try? await URLSession.shared.data(for: request),
           let image = UIImage(data: data) {
            uiImage = image
        }
    }
}
