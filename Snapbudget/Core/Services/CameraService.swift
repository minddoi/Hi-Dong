import AVFoundation
import Combine
import UIKit

// MARK: - Error

enum CameraError: LocalizedError {
    case notAuthorized
    case sessionConfigurationFailed
    case captureError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:                return "카메라 권한이 없습니다. 설정에서 허용해주세요."
        case .sessionConfigurationFailed:   return "카메라 초기화에 실패했습니다."
        case .captureError(let msg):        return "촬영 오류: \(msg)"
        }
    }
}

// MARK: - Service

/// AVFoundation 기반 카메라 서비스
@MainActor
final class CameraService: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var error: CameraError?
    @Published var isAuthorized = false

    private let photoOutput = AVCapturePhotoOutput()
    private var continuation: CheckedContinuation<UIImage, Error>?

    // MARK: - Authorization

    func requestAuthorization() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
            error = .notAuthorized
        }
    }

    // MARK: - Session Setup

    func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            throw CameraError.sessionConfigurationFailed
        }

        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            throw CameraError.sessionConfigurationFailed
        }

        photoOutput.maxPhotoQualityPrioritization = .quality
        session.addOutput(photoOutput)
        session.commitConfiguration()
    }

    func startSession() {
        guard !session.isRunning else { return }
        Task.detached { [weak self] in
            self?.session.startRunning()
        }
    }

    func stopSession() {
        guard session.isRunning else { return }
        Task.detached { [weak self] in
            self?.session.stopRunning()
        }
    }

    // MARK: - Capture

    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { [weak self] cont in
            self?.continuation = cont
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .auto
            self?.photoOutput.capturePhoto(with: settings, delegate: self!)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    /// nonisolated: AVFoundation이 임의 스레드에서 호출
    /// continuation은 @MainActor에 격리되어 있으므로 Task { @MainActor }로 hop
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        // 결과를 미리 value 타입으로 추출 (actor hop 전에 처리)
        let result: Result<UIImage, Error>
        if let error {
            result = .failure(error)
        } else if let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) {
            result = .success(image)
        } else {
            result = .failure(CameraError.captureError("이미지 변환 실패"))
        }

        Task { @MainActor [weak self] in
            switch result {
            case .success(let image):
                self?.continuation?.resume(returning: image)
            case .failure(let error):
                self?.continuation?.resume(throwing: error)
            }
            self?.continuation = nil
        }
    }
}
