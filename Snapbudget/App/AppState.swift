import Foundation
import Observation

/// 앱 전역 상태 — Environment를 통해 주입
@Observable
final class AppState {
    var selectedTab: Tab = .dashboard
    var showCapture = false

    /// 탭바 순서: 내역(좌) ─ 촬영(중앙) ─ 요약(우)
    /// `capture` 탭은 실제 화면이 없고, 탭 선택 시 카메라 모달을 띄우는 트리거 역할
    enum Tab: Int, CaseIterable, Hashable {
        case history   = 0
        case capture   = 1
        case dashboard = 2
    }
}
