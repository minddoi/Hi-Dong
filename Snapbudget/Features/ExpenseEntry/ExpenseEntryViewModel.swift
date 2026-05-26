import Foundation
import UIKit
import Observation

// MARK: - ViewModel

@MainActor
@Observable
final class ExpenseEntryViewModel {
    // 편집 가능한 필드
    var name: String
    var amountText: String = ""
    var category: ExpenseCategory
    var notes: String = ""

    // 상태
    var isSaving = false
    var saveError: Error?

    // 읽기 전용 (분석 결과)
    let subjectImage: UIImage
    let recognitionConfidence: Float

    private let repository: any ExpenseRepository
    private let storageService: ImageStorageService

    init(
        analysisResult: ImageAnalysisResult,
        repository: any ExpenseRepository,
        storageService: ImageStorageService? = nil
    ) {
        self.subjectImage = analysisResult.subjectImage
        self.name = analysisResult.recognizedName
        self.category = analysisResult.suggestedCategory
        self.recognitionConfidence = analysisResult.confidence
        self.repository = repository
        self.storageService = storageService ?? ImageStorageService()
    }

    // MARK: - Validation

    var parsedAmount: Decimal? {
        // 쉼표(,) 제거 후 Decimal 변환
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ""))
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (parsedAmount ?? 0) > 0
    }

    // MARK: - Action

    func save() async throws {
        guard let amount = parsedAmount, isValid else { return }

        isSaving = true
        defer { isSaving = false }

        // 누끼 이미지 파일로 저장
        let filename = storageService.uniqueFilename(prefix: "subject")
        let imagePath = try storageService.save(subjectImage, filename: filename)

        let item = ExpenseItem(
            name: name.trimmingCharacters(in: .whitespaces),
            amount: amount,
            category: category,
            date: .now,
            imagePath: imagePath,
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
        )

        try await repository.add(item)
    }
}
