import SwiftUI
import UIKit

// MARK: - Memory Cache (앱 전역 공유)

/// 썸네일 메모리 캐시 — NSCache는 메모리 압박 시 자동 정리
enum ThumbnailCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 200          // 최대 200개
        c.totalCostLimit = 50 * 1024 * 1024  // 약 50MB
        return c
    }()

    static func get(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    static func set(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // 대략 RGBA 바이트
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

// MARK: - SubjectImageView

/// 누끼 썸네일을 비동기로 표시하는 공용 컴포넌트
/// - 메모리 캐시 → 디스크 순으로 조회
/// - 실패 시 카테고리 이모지 폴백
struct SubjectImageView: View {
    let item: ExpenseItem

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            } else {
                Text(item.category.emoji)
                    .font(.largeTitle)
            }
        }
        .task(id: item.thumbnailFilename) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let filename = item.thumbnailFilename else { return }

        // 1) 메모리 캐시 hit
        if let cached = ThumbnailCache.get(filename) {
            thumbnail = cached
            return
        }

        // 2) 디스크에서 로드 (전역 공용 storage)
        guard let image = try? await ImageStorageService.shared.loadThumbnail(filename) else { return }
        ThumbnailCache.set(image, for: filename)
        thumbnail = image
    }
}
