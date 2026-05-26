import SwiftUI
import AVFoundation

/// AVCaptureSession을 SwiftUI에서 렌더링하는 UIViewRepresentable 래퍼
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> _PreviewUIView {
        let view = _PreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: _PreviewUIView, context: Context) {}
}

// MARK: - UIView

final class _PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    private var previewLayer: AVCaptureVideoPreviewLayer {
        // swiftlint:disable:next force_cast
        layer as! AVCaptureVideoPreviewLayer
    }

    var session: AVCaptureSession? {
        get { previewLayer.session }
        set {
            previewLayer.session = newValue
            previewLayer.videoGravity = .resizeAspectFill
        }
    }
}
