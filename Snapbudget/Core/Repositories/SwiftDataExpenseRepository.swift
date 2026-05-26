import Foundation
import SwiftData

/// SwiftData 기반 Repository 구현체
/// - @MainActor: ModelContext는 Main Thread에서만 사용
@MainActor
final class SwiftDataExpenseRepository: ExpenseRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() async throws -> [ExpenseItem] {
        let descriptor = FetchDescriptor<ExpenseItem>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchByDateRange(from: Date, to: Date) async throws -> [ExpenseItem] {
        let predicate = #Predicate<ExpenseItem> { item in
            item.date >= from && item.date <= to
        }
        let descriptor = FetchDescriptor<ExpenseItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchByCategory(_ category: ExpenseCategory) async throws -> [ExpenseItem] {
        // SwiftData #Predicate는 Codable enum 직접 비교를 지원하지 않으므로 fetch 후 Swift 레벨 필터
        let all = try await fetchAll()
        return all.filter { $0.category == category }
    }

    func add(_ item: ExpenseItem) async throws {
        modelContext.insert(item)
        try modelContext.save()
    }

    func update(_ item: ExpenseItem) async throws {
        try modelContext.save()
    }

    func delete(_ item: ExpenseItem) async throws {
        modelContext.delete(item)
        try modelContext.save()
    }

    func totalAmount(from: Date, to: Date) async throws -> Decimal {
        let items = try await fetchByDateRange(from: from, to: to)
        return items.reduce(Decimal.zero) { $0 + $1.amount }
    }
}
