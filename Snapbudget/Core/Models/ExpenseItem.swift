import Foundation
import SwiftData

@Model
final class ExpenseItem {
    var id: UUID
    var name: String
    var amount: Decimal
    var category: ExpenseCategory
    var date: Date
    var imagePath: String?        // 누끼(배경 제거) 이미지 파일 경로
    var originalImagePath: String? // 원본 이미지 파일 경로
    var notes: String?

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        category: ExpenseCategory = .other,
        date: Date = .now,
        imagePath: String? = nil,
        originalImagePath: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.category = category
        self.date = date
        self.imagePath = imagePath
        self.originalImagePath = originalImagePath
        self.notes = notes
    }
}
