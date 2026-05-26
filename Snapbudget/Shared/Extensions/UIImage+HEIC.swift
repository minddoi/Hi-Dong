import UIKit
import AVFoundation
import ImageIO

extension UIImage {
    /// HEIC 데이터로 인코딩 (알파 채널 보존)
    /// - Parameter quality: 0.0 ~ 1.0 (기본 0.85 — 시각적 무손실에 가깝고 PNG 대비 ~85% 작음)
    func heicData(quality: CGFloat = 0.85) -> Data? {
        guard let cgImage else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            AVFileType.heic as CFString,
            1,
            nil
        ) else { return nil }

        let options: NSDictionary = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, cgImage, options)

        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// 비율 유지하며 최대 변(긴 쪽)을 maxDimension(pt 단위)에 맞춰 축소
    /// - 알파 채널 보존 (누끼 이미지 투명도 유지)
    func resized(maxDimension: CGFloat) -> UIImage {
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        guard scale < 1.0 else { return self }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1            // 디스크 픽셀 크기 = newSize 그대로
        format.opaque = false       // ⭐️ 알파 보존
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
