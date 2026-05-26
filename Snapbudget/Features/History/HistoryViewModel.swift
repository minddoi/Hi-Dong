import Foundation
import Observation

@MainActor
@Observable
final class HistoryViewModel {
    private(set) var items: [ExpenseItem] = []
    private(set) var isLoading = false
    var error: Error?
    var searchQuery = ""

    private let repository: any ExpenseRepository
    private let storage: ImageStorageService

    init(
        repository: any ExpenseRepository,
        storage: ImageStorageService? = nil
    ) {
        self.repository = repository
        self.storage = storage ?? ImageStorageService()
    }

    // MARK: - Derived

    var filteredItems: [ExpenseItem] {
        guard !searchQuery.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    /// 날짜(yyyy년 M월 d일) 기준으로 그룹핑, 최신순
    var groupedByDate: [DayGroup] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"

        let dict = Dictionary(grouping: filteredItems) {
            formatter.string(from: $0.date)
        }

        // 날짜 문자열 내림차순: 실제 Date로 비교
        return dict
            .sorted { $0.value[0].date > $1.value[0].date }
            .map { DayGroup(dateLabel: $0.key, items: $0.value) }
    }

    // MARK: - Actions

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await repository.fetchAll()
        } catch {
            self.error = error
        }
    }

    func delete(_ item: ExpenseItem) async {
        // 이미지 파일 삭제 (실패해도 DB 삭제는 진행)
        if let path = item.imagePath { try? storage.delete(at: path) }
        if let path = item.originalImagePath { try? storage.delete(at: path) }

        do {
            try await repository.delete(item)
            items.removeAll { $0.id == item.id }
        } catch {
            self.error = error
        }
    }
}

// MARK: - Supporting Types

struct DayGroup: Identifiable {
    let dateLabel: String
    let items: [ExpenseItem]
    var id: String { dateLabel }
}
