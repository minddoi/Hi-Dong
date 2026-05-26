import AVFoundation
import UIKit
import Observation

// MARK: - State

enum CapturePhase: Equatable {
    case idle
    case capturing
    case analyzing
    case done
    case failed(String)

    static func == (lhs: CapturePhase, rhs: CapturePhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.capturing, .capturing),
             (.analyzing, .analyzing), (.done, .done):
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

    private let cameraService: CameraService
    private let analysisService: ImageAnalysisService

    var captureSession: AVCaptureSession { cameraService.session }
    var isBusy: Bool { phase == .capturing || phase == .analyzing }

    /// 프로덕션용 — 서비스를 init 본문에서 생성 (default 파라미터에서 @MainActor 타입 생성 불가)
    init() {
        self.cameraService = CameraService()
        self.analysisService = ImageAnalysisService()
    }

    /// 테스트/DI용
    init(cameraService: CameraService, analysisService: ImageAnalysisService) {
        self.cameraService = cameraService
        self.analysisService = analysisService
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
            phase = .done
            showEntrySheet = true
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func retry() {
        phase = .idle
        analysisResult = nil
    }
}
