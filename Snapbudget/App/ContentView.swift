import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()

    /// 카메라 탭 클릭 시 복귀할 이전 탭 기억
    @State private var previousTab: AppState.Tab = .dashboard

    var body: some View {
        TabView(selection: tabBinding) {
            HistoryView()
                .tabItem { Label("내역", systemImage: "clock.fill") }
                .tag(AppState.Tab.history)

            // 가운데 카메라 탭 — 실제 콘텐츠는 비어있고, 선택 시 카메라 모달 트리거
            Color.clear
                .tabItem { Label("촬영", systemImage: "camera.fill") }
                .tag(AppState.Tab.capture)

            DashboardView()
                .tabItem { Label("요약", systemImage: "chart.pie.fill") }
                .tag(AppState.Tab.dashboard)
        }
        .fullScreenCover(isPresented: $appState.showCapture) {
            CaptureView()
        }
        .environment(appState)
    }

    // MARK: - Tab Selection Logic

    /// 카메라 탭은 실제로 선택되지 않고 모달만 띄움 → 직전 탭으로 즉시 복귀
    private var tabBinding: Binding<AppState.Tab> {
        Binding(
            get: { appState.selectedTab },
            set: { newTab in
                if newTab == .capture {
                    // 카메라 탭 탭 → 모달만 띄우고 selectedTab은 변경하지 않음
                    appState.showCapture = true
                } else {
                    appState.selectedTab = newTab
                    previousTab = newTab
                }
            }
        )
    }
}
