import UIKit
import Foundation

// MARK: - Error

enum ImageStorageError: LocalizedError {
    case encodingFailed
    case writeFailed(String)
    case fileNotFound(String)
    case readFailed(String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:       return "이미지 인코딩에 실패했습니다."
        case .writeFailed(let f):   return "이미지 저장 실패: \(f)"
        case .fileNotFound(let f):  return "이미지를 찾을 수 없습니다: \(f)"
        case .readFailed(let f):    return "이미지 읽기 실패: \(f)"
        }
    }
}

// MARK: - Stored Image (value type)

/// 저장된 이미지의 파일명 참조 (절대경로가 아니라 파일명만 — 컨테이너 UUID 변경에 안전)
struct StoredImage: Sendable, Hashable, Codable {
    let filename: String           // "subject_<uuid>.heic"
    let thumbnailFilename: String  // "subject_<uuid>_thumb.heic"
}

// MARK: - Service

/// 이미지 저장/로드/삭제를 담당하는 actor
/// - 모든 디스크 IO는 actor 내부에서 수행 (메인 스레드 블로킹 방지)
/// - 파일명만 외부에 노출 (절대경로 사용 금지 → 앱 재설치/iCloud 복원 안전)
actor ImageStorageService {

    // MARK: - Shared

    /// 앱 전역 공용 인스턴스 (디렉토리는 단일하므로 인스턴스를 여러 개 만들 이유 없음)
    static let shared = ImageStorageService()

    // MARK: - Constants

    /// 썸네일 최대 변 길이 (pt 단위, 1x). 그리드/리스트용으로 충분.
    private let thumbnailMaxDimension: CGFloat = 512

    /// HEIC 압축 품질 (0.85 = 시각적 무손실에 가까움)
    private let heicQuality: CGFloat = 0.85

    // MARK: - Directories

    private let fullDirectory: URL
    private let thumbnailDirectory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let base = docs.appending(path: "SnapBudget/Images", directoryHint: .isDirectory)
        fullDirectory = base.appending(path: "full", directoryHint: .isDirectory)
        thumbnailDirectory = base.appending(path: "thumb", directoryHint: .isDirectory)

        try? FileManager.default.createDirectory(at: fullDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thumbnailDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Save

    /// 누끼 이미지를 받아 풀 + 썸네일을 동시에 저장
    func save(_ image: UIImage) throws -> StoredImage {
        let uuid = UUID().uuidString
        let fullName = "subject_\(uuid).heic"
        let thumbName = "subject_\(uuid)_thumb.heic"

        // 1) 풀 사이즈 HEIC
        guard let fullData = image.heicData(quality: heicQuality) else {
            throw ImageStorageError.encodingFailed
        }
        let fullURL = fullDirectory.appending(path: fullName)
        do {
            try fullData.write(to: fullURL, options: .atomic)
        } catch {
            throw ImageStorageError.writeFailed(fullName)
        }

        // 2) 썸네일 HEIC (실패 시 풀 이미지도 롤백)
        let thumbnail = image.resized(maxDimension: thumbnailMaxDimension)
        guard let thumbData = thumbnail.heicData(quality: heicQuality) else {
            try? FileManager.default.removeItem(at: fullURL)
            throw ImageStorageError.encodingFailed
        }
        let thumbURL = thumbnailDirectory.appending(path: thumbName)
        do {
            try thumbData.write(to: thumbURL, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: fullURL)
            throw ImageStorageError.writeFailed(thumbName)
        }

        return StoredImage(filename: fullName, thumbnailFilename: thumbName)
    }

    // MARK: - Load

    func loadFull(_ filename: String) throws -> UIImage {
        let url = fullDirectory.appending(path: filename)
        return try load(at: url, filename: filename)
    }

    func loadThumbnail(_ filename: String) throws -> UIImage {
        let url = thumbnailDirectory.appending(path: filename)
        return try load(at: url, filename: filename)
    }

    private func load(at url: URL, filename: String) throws -> UIImage {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImageStorageError.fileNotFound(filename)
        }
        guard let image = UIImage(contentsOfFile: url.path) else {
            throw ImageStorageError.readFailed(filename)
        }
        return image
    }

    // MARK: - Delete

    /// 풀 + 썸네일 동시 삭제 (각각 실패해도 다른 쪽은 시도)
    func delete(_ stored: StoredImage) {
        let fullURL = fullDirectory.appending(path: stored.filename)
        let thumbURL = thumbnailDirectory.appending(path: stored.thumbnailFilename)
        try? FileManager.default.removeItem(at: fullURL)
        try? FileManager.default.removeItem(at: thumbURL)
    }

    // MARK: - Cleanup Orphans

    /// DB에 참조되지 않는 고아 파일을 제거
    /// - Parameter referenced: DB에 살아있는 StoredImage 집합
    /// - Returns: 삭제된 파일 수
    @discardableResult
    func cleanupOrphans(referenced: Set<StoredImage>) -> Int {
        let referencedFulls = Set(referenced.map(\.filename))
        let referencedThumbs = Set(referenced.map(\.thumbnailFilename))

        var deleted = 0
        deleted += removeUnreferenced(in: fullDirectory, keeping: referencedFulls)
        deleted += removeUnreferenced(in: thumbnailDirectory, keeping: referencedThumbs)
        return deleted
    }

    private func removeUnreferenced(in directory: URL, keeping referenced: Set<String>) -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return 0 }

        var deleted = 0
        for url in files {
            let name = url.lastPathComponent
            if !referenced.contains(name) {
                if (try? FileManager.default.removeItem(at: url)) != nil {
                    deleted += 1
                }
            }
        }
        return deleted
    }
}
