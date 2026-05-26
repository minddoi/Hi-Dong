import SwiftUI

extension View {
    /// 조건부 modifier 적용
    @ViewBuilder
    func applyIf<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// 에러 Alert을 간단하게 붙이는 modifier
    func errorAlert(
        error: Binding<Error?>,
        title: String = "오류"
    ) -> some View {
        alert(title, isPresented: Binding(
            get: { error.wrappedValue != nil },
            set: { if !$0 { error.wrappedValue = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(error.wrappedValue?.localizedDescription ?? "")
        }
    }
}
