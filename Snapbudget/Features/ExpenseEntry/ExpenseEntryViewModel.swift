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
    private let imageEmbedding: Data?

    // 매칭된 과거 구매 (있을 때만) — UI 배너 + 자동 채움 트리거
    let pastHint: PastPurchaseHint?

    private let repository: any ExpenseRepository
    private let storageService: ImageStorageService

    init(
        analysisResult: ImageAnalysisResult,
        pastHint: PastPurchaseHint? = nil,
        repository: any ExpenseRepository,
        storageService: ImageStorageService = .shared
    ) {
        self.subjectImage = analysisResult.subjectImage
        self.recognitionConfidence = analysisResult.confidence
        self.imageEmbedding = analysisResult.imageEmbedding
        self.pastHint = pastHint
        self.repository = repository
        self.storageService = storageService

        // ⭐️ 과거 구매 매칭이 있으면 모든 필드를 그대로 자동 채움
        //    없으면 AI 인식 결과(generic)를 채움
        if let hint = pastHint {
            self.name = hint.name
            self.amountText = Self.formatAmount(hint.amount)
            self.category = hint.category
        } else {
            self.name = analysisResult.recognizedName
            self.category = analysisResult.suggestedCategory
            // amount는 비워둠 (사용자가 입력)
        }
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

    /// 매칭된 과거 구매가 있고, 사용자가 필드를 안 건드렸다면 → 1탭 저장 모드
    var isOneTapSaveMode: Bool {
        pastHint != nil && isValid
    }

    // MARK: - Action

    func save() async throws {
        guard let amount = parsedAmount, isValid else { return }

        isSaving = true
        defer { isSaving = false }

        // ① 누끼 이미지 저장 (풀 + 썸네일 동시 생성)
        let stored = try await storageService.save(subjectImage)

        // ② DB에 메타데이터 + 임베딩 저장 (다음 매칭에 사용)
        let item = ExpenseItem(
            name: name.trimmingCharacters(in: .whitespaces),
            amount: amount,
            category: category,
            date: .now,
            imageFilename: stored.filename,
            thumbnailFilename: stored.thumbnailFilename,
            imageEmbedding: imageEmbedding,
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

    // MARK: - Helpers

    private static func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? ""
    }
}
