import Foundation
import SwiftData

@Model
final class ExpenseItem {
    var id: UUID
    var name: String
    var amount: Decimal
    var category: ExpenseCategory
    var date: Date

    /// 풀 사이즈 누끼 이미지 파일명 (절대경로 X — 컨테이너 UUID 변경에 안전)
    /// e.g. "subject_<uuid>.heic"
    var imageFilename: String?

    /// 썸네일 파일명. 리스트/그리드용 ~512px 캐시
    /// e.g. "subject_<uuid>_thumb.heic"
    var thumbnailFilename: String?

    var notes: String?

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        category: ExpenseCategory = .other,
        date: Date = .now,
        imageFilename: String? = nil,
        thumbnailFilename: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.category = category
        self.date = date
        self.imageFilename = imageFilename
        self.thumbnailFilename = thumbnailFilename
        self.notes = notes
    }

    // MARK: - Convenience

    /// StoredImage 값 객체로 묶어서 반환 (둘 다 있을 때만)
    var storedImage: StoredImage? {
        guard let imageFilename, let thumbnailFilename else { return nil }
        return StoredImage(filename: imageFilename, thumbnailFilename: thumbnailFilename)
    }
}
