import SwiftUI

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CaptureViewModel()

    var body: some View {
        ZStack {
            // ① 카메라 프리뷰 (전체화면)
            CameraPreviewView(session: viewModel.captureSession)
                .ignoresSafeArea()

            // ② UI 오버레이
            VStack(spacing: 0) {
                closeButton
                Spacer()
                statusOverlay
                shutterButton
                    .padding(.bottom, 48)
            }
            .padding(.top, 8)
        }
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .sheet(isPresented: $viewModel.showEntrySheet, onDismiss: {
            viewModel.retry()
        }) {
            if let result = viewModel.analysisResult {
                ExpenseEntryView(analysisResult: result) {
                    viewModel.showEntrySheet = false
                    dismiss()
                }
            }
        }
    }

    // MARK: - Sub-views

    private var closeButton: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("닫기")
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch viewModel.phase {
        case .analyzing:
            HStack(spacing: 10) {
                ProgressView().tint(.white)
                Text("물건을 분석하는 중…")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 24)

        case .failed(let msg):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(msg)
                    .font(.subheadline)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.red.opacity(0.75), in: Capsule())
            .padding(.bottom, 24)
            .onTapGesture { viewModel.retry() }

        default:
            Color.clear.frame(height: 0)
        }
    }

    private var shutterButton: some View {
        Button {
            Task { await viewModel.captureAndAnalyze() }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: 4)
                    .frame(width: 76, height: 76)
                Circle()
                    .fill(viewModel.isBusy ? Color.white.opacity(0.4) : .white)
                    .frame(width: 62, height: 62)
            }
        }
        .disabled(viewModel.isBusy)
        .accessibilityLabel("촬영")
    }
}
