import SwiftUI
import SwiftData

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: CaptureViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                cameraContent(vm)
            } else {
                Color.black.ignoresSafeArea()
                    .overlay { ProgressView().tint(.white) }
            }
        }
        .onAppear {
            if viewModel == nil {
                let repo = SwiftDataExpenseRepository(modelContext: modelContext)
                viewModel = CaptureViewModel(repository: repo)
            }
        }
    }

    @ViewBuilder
    private func cameraContent(_ vm: CaptureViewModel) -> some View {
        ZStack {
            // ① 카메라 프리뷰 (전체화면)
            CameraPreviewView(session: vm.captureSession)
                .ignoresSafeArea()

            // ② UI 오버레이
            VStack(spacing: 0) {
                closeButton
                Spacer()
                statusOverlay(vm.phase)
                shutterButton(vm)
                    .padding(.bottom, 48)
            }
            .padding(.top, 8)
        }
        .task { await vm.onAppear() }
        .onDisappear { vm.onDisappear() }
        .sheet(
            isPresented: Binding(
                get: { vm.showEntrySheet },
                set: { vm.showEntrySheet = $0 }
            ),
            onDismiss: { vm.retry() }
        ) {
            if let result = vm.analysisResult {
                ExpenseEntryView(
                    analysisResult: result,
                    pastHint: vm.pastPurchaseHint
                ) {
                    vm.showEntrySheet = false
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
    private func statusOverlay(_ phase: CapturePhase) -> some View {
        switch phase {
        case .analyzing:
            statusCapsule(text: "물건을 분석하는 중…", icon: nil)
        case .matching:
            statusCapsule(text: "비슷한 과거 구매 찾는 중…", icon: nil)
        case .failed(let msg):
            statusCapsule(
                text: msg,
                icon: "exclamationmark.triangle.fill",
                color: .red.opacity(0.75)
            )
            .onTapGesture { viewModel?.retry() }
        default:
            Color.clear.frame(height: 0)
        }
    }

    private func statusCapsule(
        text: String,
        icon: String?,
        color: Color? = nil
    ) -> some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
            } else {
                ProgressView().tint(.white)
            }
            Text(text)
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            color != nil
                ? AnyShapeStyle(color!)
                : AnyShapeStyle(.ultraThinMaterial),
            in: Capsule()
        )
        .padding(.bottom, 24)
    }

    private func shutterButton(_ vm: CaptureViewModel) -> some View {
        Button {
            Task { await vm.captureAndAnalyze() }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: 4)
                    .frame(width: 76, height: 76)
                Circle()
                    .fill(vm.isBusy ? Color.white.opacity(0.4) : .white)
                    .frame(width: 62, height: 62)
            }
        }
        .disabled(vm.isBusy)
        .accessibilityLabel("촬영")
    }
}
