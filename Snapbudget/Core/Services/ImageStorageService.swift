import UIKit
import Foundation

// MARK: - Error

enum ImageStorageError: LocalizedError {
    case saveFailed
    case loadFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed:   return "이미지 저장에 실패했습니다."
        case .loadFailed:   return "이미지 불러오기에 실패했습니다."
        case .deleteFailed: return "이미지 삭제에 실패했습니다."
        }
    }
}

// MARK: - Service

/// 이미지를 앱 Document 디렉토리에 저장/로드/삭제하는 서비스
final class ImageStorageService: Sendable {
    private let baseDirectory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        baseDirectory = docs.appendingPathComponent("SnapBudget/Images", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
    }

    /// 이미지를 저장하고 파일 경로를 반환
    func save(_ image: UIImage, filename: String) throws -> String {
        guard let data = image.pngData() else {
            throw ImageStorageError.saveFailed
        }

        let url = baseDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            throw ImageStorageError.saveFailed
        }
    }

    /// 파일 경로로 이미지 로드
    func load(from path: String) throws -> UIImage {
        guard let image = UIImage(contentsOfFile: path) else {
            throw ImageStorageError.loadFailed
        }
        return image
    }

    /// 파일 경로의 이미지 삭제
    func delete(at path: String) throws {
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch {
            throw ImageStorageError.deleteFailed
        }
    }

    /// 중복 없는 파일명 생성
    func uniqueFilename(prefix: String = "item", ext: String = "png") -> String {
        "\(prefix)_\(UUID().uuidString).\(ext)"
    }
}
