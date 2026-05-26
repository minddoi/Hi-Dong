import SwiftUI
import SwiftData

@main
struct SnapBudgetApp: App {

    /// 단일 ModelContainer (앱 전역에서 공유)
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: ExpenseItem.self)
        } catch {
            fatalError("ModelContainer 초기화 실패: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { await cleanupOrphanImages() }
        }
        .modelContainer(modelContainer)
    }

    // MARK: - Orphan Cleanup

    /// 앱 시작 시 DB에 참조되지 않는 이미지 파일을 정리
    /// (저장 도중 크래시·취소 등으로 디스크에만 남은 파일 제거)
    @MainActor
    private func cleanupOrphanImages() async {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<ExpenseItem>()

        guard let items = try? context.fetch(descriptor) else { return }
        let referenced = Set(items.compactMap(\.storedImage))

        await ImageStorageService.shared.cleanupOrphans(referenced: referenced)
    }
}
