import Vision
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Error

enum ImageAnalysisError: LocalizedError {
    case subjectMaskingFailed
    case classificationFailed
    case imageProcessingFailed

    var errorDescription: String? {
        switch self {
        case .subjectMaskingFailed:  return "배경 제거에 실패했습니다."
        case .classificationFailed:  return "물건 인식에 실패했습니다."
        case .imageProcessingFailed: return "이미지 처리 중 오류가 발생했습니다."
        }
    }
}

// MARK: - Result

struct ImageAnalysisResult: Sendable {
    let subjectImage: UIImage      // 배경 제거된 누끼 이미지
    let recognizedName: String     // 인식된 물건명
    let confidence: Float          // 인식 신뢰도 (0.0 ~ 1.0)
    let suggestedCategory: ExpenseCategory
    let imageEmbedding: Data?      // VNFeaturePrintObservation 직렬화 (반복 구매 매칭용)
}

// MARK: - Service

/// Vision 프레임워크를 이용한 이미지 분석 서비스 (iOS 17+)
final class ImageAnalysisService: Sendable {

    // MARK: - Public Interface

    /// 배경 제거 + 물건 인식 + 임베딩 추출을 동시에 수행 (3개 작업 병렬)
    func analyze(_ image: UIImage) async throws -> ImageAnalysisResult {
        async let subjectImage = removeBackground(from: image)
        async let classification = classifyImage(image)
        async let embedding = extractFeaturePrint(image)  // 실패해도 nil 반환 → 매칭만 안 됨

        let (subject, (name, confidence, category), embeddingData) = try await (
            subjectImage,
            classification,
            embedding
        )

        return ImageAnalysisResult(
            subjectImage: subject,
            recognizedName: name,
            confidence: confidence,
            suggestedCategory: category,
            imageEmbedding: embeddingData
        )
    }

    // MARK: - Feature Print (Embedding)

    /// 이미지에서 768차원 특징 벡터 추출 (NSKeyedArchiver로 직렬화한 Data 반환)
    /// - 실패 시 throw하지 않고 nil 반환 (매칭은 옵셔널 기능이므로 분석 자체는 계속 진행)
    func extractFeaturePrint(_ image: UIImage) async -> Data? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNGenerateImageFeaturePrintRequest { request, error in
                guard
                    error == nil,
                    let observation = request.results?.first as? VNFeaturePrintObservation
                else {
                    continuation.resume(returning: nil)
                    return
                }

                // VNFeaturePrintObservation을 NSKeyedArchiver로 직렬화
                let data = try? NSKeyedArchiver.archivedData(
                    withRootObject: observation,
                    requiringSecureCoding: true
                )
                continuation.resume(returning: data)
            }
            request.imageCropAndScaleOption = .scaleFill

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Background Removal

    /// VNGenerateForegroundInstanceMaskRequest로 배경 제거 (iOS 17+)
    func removeBackground(from image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw ImageAnalysisError.imageProcessingFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateForegroundInstanceMaskRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result = request.results?.first as? VNInstanceMaskObservation else {
                    continuation.resume(throwing: ImageAnalysisError.subjectMaskingFailed)
                    return
                }

                do {
                    let masked = try self.applyInstanceMask(result, to: cgImage)
                    continuation.resume(returning: masked)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Classification

    func classifyImage(_ image: UIImage) async throws -> (name: String, confidence: Float, category: ExpenseCategory) {
        guard let cgImage = image.cgImage else {
            throw ImageAnalysisError.imageProcessingFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard
                    let observations = request.results as? [VNClassificationObservation],
                    let top = observations.first(where: { $0.confidence > 0.2 })
                else {
                    // 인식 실패해도 기본값으로 진행 (사용자가 이름 수정 가능)
                    continuation.resume(returning: ("물건", 0.0, .other))
                    return
                }

                let name = self.localizedName(for: top.identifier)
                let category = self.inferCategory(from: top.identifier, all: observations)
                continuation.resume(returning: (name, top.confidence, category))
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Private Helpers

    private func applyInstanceMask(
        _ observation: VNInstanceMaskObservation,
        to cgImage: CGImage
    ) throws -> UIImage {
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // ⭐️ 여러 객체가 감지돼도 가장 큰(가장 중심적인) 1개만 선택
        guard let primaryInstance = selectPrimaryInstance(in: observation) else {
            throw ImageAnalysisError.subjectMaskingFailed
        }
        let selected = IndexSet(integer: primaryInstance)

        guard let maskBuffer = try? observation.generateScaledMaskForImage(
            forInstances: selected,
            from: handler
        ) else {
            throw ImageAnalysisError.subjectMaskingFailed
        }

        let ciMask = CIImage(cvPixelBuffer: maskBuffer)
        let ciOriginal = CIImage(cgImage: cgImage)

        let filter = CIFilter.blendWithMask()
        filter.inputImage = ciOriginal
        filter.maskImage = ciMask
        filter.backgroundImage = CIImage.empty()

        guard
            let outputCI = filter.outputImage,
            let outputCG = CIContext().createCGImage(outputCI, from: outputCI.extent)
        else {
            throw ImageAnalysisError.imageProcessingFailed
        }

        return UIImage(cgImage: outputCG)
    }

    /// 인스턴스 마스크에서 면적 + 중심도 점수가 가장 높은 인스턴스 인덱스를 반환
    /// 점수 = (면적 비율) × (1 - 중심으로부터의 거리 가중치)
    /// → 단순 "가장 큰 객체"보다 "사용자가 의도한 주피사체"를 더 잘 고름
    private func selectPrimaryInstance(in observation: VNInstanceMaskObservation) -> Int? {
        let pixelBuffer = observation.instanceMask

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        // 인스턴스별: 픽셀 수 + 중심 좌표 누적 (centroid 계산용)
        struct Stat { var count: Int = 0; var sumX: Int = 0; var sumY: Int = 0 }
        var stats: [Int: Stat] = [:]

        for y in 0..<height {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                let id = Int(row[x])
                guard id > 0 else { continue } // 0은 배경
                stats[id, default: Stat()].count += 1
                stats[id, default: Stat()].sumX += x
                stats[id, default: Stat()].sumY += y
            }
        }
        guard !stats.isEmpty else { return nil }

        let totalPixels = width * height
        let cx = Double(width) / 2
        let cy = Double(height) / 2
        let maxDistance = sqrt(cx * cx + cy * cy)

        // 점수 = 면적비(60%) + 중심 근접도(40%)
        let scored = stats.mapValues { stat -> Double in
            let areaRatio = Double(stat.count) / Double(totalPixels)
            let centroidX = Double(stat.sumX) / Double(stat.count)
            let centroidY = Double(stat.sumY) / Double(stat.count)
            let dx = centroidX - cx
            let dy = centroidY - cy
            let distance = sqrt(dx * dx + dy * dy)
            let centrality = 1.0 - (distance / maxDistance)
            return areaRatio * 0.6 + centrality * 0.4
        }

        return scored.max(by: { $0.value < $1.value })?.key
    }

    private func localizedName(for identifier: String) -> String {
        let mapping: [String: String] = [
            "cup": "컵",
            "bottle": "음료/병",
            "bag": "가방",
            "shoe": "신발",
            "shirt": "셔츠",
            "dress": "원피스",
            "jacket": "자켓",
            "book": "책",
            "phone": "스마트폰",
            "laptop": "노트북",
            "headphone": "헤드폰",
            "food": "음식",
            "fruit": "과일",
            "vegetable": "채소",
            "cosmetic": "화장품",
            "medicine": "약",
        ]

        let lower = identifier.lowercased()
        for (key, value) in mapping where lower.contains(key) {
            return value
        }

        // 매핑 없으면 영어 identifier 그대로 (사용자가 수정 가능)
        return identifier.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func inferCategory(
        from identifier: String,
        all observations: [VNClassificationObservation]
    ) -> ExpenseCategory {
        let lower = identifier.lowercased()

        let rules: [(keywords: [String], category: ExpenseCategory)] = [
            (["food", "fruit", "vegetable", "meat", "drink", "coffee", "meal", "bread"], .food),
            (["shirt", "dress", "shoe", "bag", "clothing", "fashion", "jacket", "hat"], .shopping),
            (["phone", "laptop", "computer", "camera", "tablet", "headphone", "earphone"], .electronics),
            (["medicine", "pill", "vitamin", "supplement"], .health),
            (["cosmetic", "makeup", "lipstick", "perfume", "skincare"], .beauty),
            (["book", "game", "toy", "album"], .entertainment),
            (["cleaning", "detergent", "kitchen", "furniture", "household"], .household),
            (["bus", "taxi", "car", "train"], .transport),
        ]

        for rule in rules where rule.keywords.contains(where: { lower.contains($0) }) {
            return rule.category
        }
        return .other
    }
}
