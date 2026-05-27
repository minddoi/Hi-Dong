import AVFoundation
import UIKit
import Observation

// MARK: - State

enum CapturePhase: Equatable {
    case idle
    case capturing
    case analyzing
    case matching         // ⭐️ NEW — 과거 구매 매칭 중
    case done
    case failed(String)

    static func == (lhs: CapturePhase, rhs: CapturePhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.capturing, .capturing),
             (.analyzing, .analyzing), (.matching, .matching), (.done, .done):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class CaptureViewModel {
    private(set) var phase: CapturePhase = .idle
    var showEntrySheet = false
    var analysisResult: ImageAnalysisResult?
    var pastPurchaseHint: PastPurchaseHint?   // ⭐️ NEW — 매칭된 과거 구매 (있을 때만)

    private let cameraService: CameraService
    private let analysisService: ImageAnalysisService
    private let matcher: PurchaseMatcher
    private let repository: (any ExpenseRepository)?

    var captureSession: AVCaptureSession { cameraService.session }
    var isBusy: Bool {
        phase == .capturing || phase == .analyzing || phase == .matching
    }

    /// 프로덕션용 — repository는 외부에서 주입 (모델 컨텍스트 필요)
    init(repository: (any ExpenseRepository)? = nil) {
        self.cameraService = CameraService()
        self.analysisService = ImageAnalysisService()
        self.matcher = PurchaseMatcher()
        self.repository = repository
    }

    /// 테스트/DI용
    init(
        cameraService: CameraService,
        analysisService: ImageAnalysisService,
        matcher: PurchaseMatcher,
        repository: (any ExpenseRepository)? = nil
    ) {
        self.cameraService = cameraService
        self.analysisService = analysisService
        self.matcher = matcher
        self.repository = repository
    }

    // MARK: - Lifecycle

    func onAppear() async {
        await cameraService.requestAuthorization()
        guard cameraService.isAuthorized else {
            phase = .failed("카메라 권한이 필요합니다.")
            return
        }
        do {
            try cameraService.configureSession()
            cameraService.startSession()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func onDisappear() {
        cameraService.stopSession()
    }

    // MARK: - Actions

    func captureAndAnalyze() async {
        guard !isBusy else { return }

        phase = .capturing
        do {
            let image = try await cameraService.capturePhoto()

            phase = .analyzing
            let result = try await analysisService.analyze(image)
            analysisResult = result

            // 과거 구매 매칭 시도 (실패해도 흐름은 계속)
            phase = .matching
            pastPurchaseHint = await findMatch(for: result)

            phase = .done
            showEntrySheet = true
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func retry() {
        phase = .idle
        analysisResult = nil
        pastPurchaseHint = nil
    }

    // MARK: - Private

    private func findMatch(for result: ImageAnalysisResult) async -> PastPurchaseHint? {
        guard
            let embedding = result.imageEmbedding,
            let repository
        else { return nil }

        // 임베딩이 있는 과거 항목만 비교 대상
        guard let candidates = try? await repository.fetchAll() else { return nil }
        let withEmbedding = candidates.filter { $0.imageEmbedding != nil }
        guard !withEmbedding.isEmpty else { return nil }

        return matcher.findBestMatch(newEmbedding: embedding, candidates: withEmbedding)
    }
}
