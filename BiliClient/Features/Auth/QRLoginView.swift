import SwiftUI

/// 扫码登录页（以 sheet 形式弹出）。登录成功后回调关闭并刷新会话。
struct QRLoginView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var vm = QRLoginViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Text("登录 B站")
                .font(.title2.bold())

            Group {
                if let image = vm.qrImage {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 240, height: 240)
                        .overlay {
                            if vm.status == .expired {
                                expiredOverlay
                            }
                        }
                } else {
                    ProgressView()
                        .frame(width: 240, height: 240)
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(vm.statusText)
                .foregroundStyle(vm.status == .scannedConfirm ? .orange : .secondary)

            if let error = vm.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button("刷新二维码") {
                Task { await vm.refresh() }
            }
            .buttonStyle(.bordered)

            Text("登录仅用于获取高清画质，不会读取其他内容。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: 400)
        .task { await vm.start() }
        .onDisappear { vm.stop() }
        .onChange(of: vm.status) { _, newValue in
            if newValue == .success {
                Task {
                    await session.refresh()
                    dismiss()
                }
            }
        }
    }

    private var expiredOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
            Button("点击刷新") {
                Task { await vm.refresh() }
            }
            .buttonStyle(.borderedProminent)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
