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
        storageService: ImageStorageService = .shared
    ) {
        self.subjectImage = analysisResult.subjectImage
        self.name = analysisResult.recognizedName
        self.category = analysisResult.suggestedCategory
        self.recognitionConfidence = analysisResult.confidence
        self.repository = repository
        self.storageService = storageService
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

        // ① 누끼 이미지 저장 (풀 + 썸네일 동시 생성)
        let stored = try await storageService.save(subjectImage)

        // ② DB에 메타데이터 저장
        let item = ExpenseItem(
            name: name.trimmingCharacters(in: .whitespaces),
            amount: amount,
            category: category,
            date: .now,
            imageFilename: stored.filename,
            thumbnailFilename: stored.thumbnailFilename,
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
        )

        do {
            try await repository.add(item)
        } catch {
            // DB 저장 실패 시 디스크 파일 롤백 (고아 파일 방지)
            await storageService.delete(stored)
            throw error
        }
    }
}
