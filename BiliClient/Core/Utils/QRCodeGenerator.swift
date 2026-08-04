import UIKit
import CoreImage.CIFilterBuiltins

/// 用 CoreImage 把字符串生成二维码图片。
enum QRCodeGenerator {
    /// - Parameter minSize: 期望的最小边长（pt）。实际会向上取整数倍缩放，
    ///   保证每个二维码模块都是整数像素，避免边界发虚导致手机扫错 qrcode_key（表现为「签名错误」）。
    static func image(from string: String, minSize: CGFloat = 240) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        // 高纠错等级：即使部分模块被采样误差影响也能纠正。
        filter.correctionLevel = "H"
        guard let output = filter.outputImage else { return nil }

        // 整数倍缩放：模块边界严格对齐像素，扫描更稳。
        let base = output.extent.width // 每个模块 1px 的原始尺寸
        let scale = max(1, ceil(minSize / base))
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        // 用最近邻缩放显示时保持锐利（View 层也设了 .interpolation(.none)）。
        return UIImage(cgImage: cg)
    }
}
