import Foundation
import Vision
import UIKit
import os

// MARK: - Match Result

/// 과거 구매와 매칭된 결과 (값 타입 — UI 계층으로 안전하게 전달)
struct PastPurchaseHint: Sendable, Identifiable {
    let id: UUID                   // 원본 ExpenseItem의 id
    let name: String
    let amount: Decimal
    let category: ExpenseCategory
    let thumbnailFilename: String?
    let purchaseDate: Date
    let distance: Float            // 0 = 동일, 클수록 다름
    let similarity: Float          // 0.0 ~ 1.0 (UI 표시용)

    /// "92% 일치" 식으로 보여줄 수 있는 퍼센티지
    var similarityPercent: Int {
        Int(similarity * 100)
    }
}

// MARK: - Matcher

/// 이미지 임베딩 거리 비교로 과거 구매를 찾는 매칭 서비스
@MainActor
final class PurchaseMatcher {

    // MARK: - Configuration

    /// 같은 물건으로 판단할 최대 거리 (Vision FeaturePrint 기준)
    /// - 보수적으로 18 설정 — 잘못된 매칭(false positive) 방지가 우선
    /// - 참고: 같은 물건/조명만 다름 ≈ 5~12, 같은 물건/각도 다름 ≈ 10~20, 다른 물건 ≈ 25+
    static let defaultThreshold: Float = 18.0

    private let threshold: Float
    private let logger = Logger(subsystem: "com.snapbudget", category: "PurchaseMatcher")

    init(threshold: Float = PurchaseMatcher.defaultThreshold) {
        self.threshold = threshold
    }

    // MARK: - Public

    /// 새 임베딩과 가장 유사한 과거 구매를 찾는다 (임계값 이내일 때만)
    /// - Returns: 매칭된 과거 구매 (없으면 nil)
    func findBestMatch(
        newEmbedding: Data,
        candidates: [ExpenseItem]
    ) -> PastPurchaseHint? {
        guard let newObservation = decode(newEmbedding) else {
            logger.warning("🔍 새 임베딩 디코딩 실패")
            return nil
        }

        logger.debug("🔍 매칭 시작 — 후보 \(candidates.count)개, 임계값=\(self.threshold)")

        var bestMatch: (item: ExpenseItem, distance: Float)?

        for item in candidates {
            guard
                let pastData = item.imageEmbedding,
                let pastObservation = decode(pastData)
            else { continue }

            var distance: Float = 0
            do {
                try newObservation.computeDistance(&distance, to: pastObservation)
            } catch {
                logger.warning("⚠️ 거리 계산 실패 (item: \(item.name)): \(error.localizedDescription)")
                continue
            }

            logger.debug("📏 '\(item.name)' → 거리 \(distance, format: .fixed(precision: 2))")

            // 더 가까운 매칭이면 갱신 (임계값 안에서)
            if distance <= threshold {
                if bestMatch == nil || distance < bestMatch!.distance {
                    bestMatch = (item, distance)
                }
            }
        }

        guard let match = bestMatch else {
            logger.info("❌ 매칭 없음 (모든 후보가 임계값 \(self.threshold) 초과)")
            return nil
        }

        logger.info("✅ 매칭 — '\(match.item.name)' 거리=\(match.distance, format: .fixed(precision: 2))")
        return makeHint(from: match.item, distance: match.distance)
    }

    // MARK: - Private

    private func decode(_ data: Data) -> VNFeaturePrintObservation? {
        try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: VNFeaturePrintObservation.self,
            from: data
        )
    }

    private func makeHint(from item: ExpenseItem, distance: Float) -> PastPurchaseHint {
        // 거리 → 유사도(0~1) 변환: distance 0 → 1.0, threshold → 0.5, 그 이상 → 0
        // 단순 선형 매핑 (UI 표시용)
        let normalized = max(0, 1.0 - (distance / (threshold * 2)))

        return PastPurchaseHint(
            id: item.id,
            name: item.name,
            amount: item.amount,
            category: item.category,
            thumbnailFilename: item.thumbnailFilename,
            purchaseDate: item.date,
            distance: distance,
            similarity: normalized
        )
    }
}
