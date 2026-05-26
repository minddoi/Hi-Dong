import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    private(set) var items: [ExpenseItem] = []
    private(set) var isLoading = false
    var error: Error?

    private let repository: any ExpenseRepository

    init(repository: any ExpenseRepository) {
        self.repository = repository
    }

    // MARK: - Derived Data

    var totalThisMonth: Decimal {
        let (from, to) = currentMonthRange()
        return thisMonthItems(from: from, to: to).reduce(.zero) { $0 + $1.amount }
    }

    /// 카테고리별 금액 (0원 제외, 내림차순)
    var categoryBreakdown: [CategoryShare] {
        let (from, to) = currentMonthRange()
        let monthly = thisMonthItems(from: from, to: to)
        let total = monthly.reduce(Decimal.zero) { $0 + $1.amount }
        guard total > 0 else { return [] }

        return ExpenseCategory.allCases.compactMap { cat in
            let amount = monthly.filter { $0.category == cat }.reduce(.zero) { $0 + $1.amount }
            guard amount > 0 else { return nil }
            let ratio = (NSDecimalNumber(decimal: amount / total).doubleValue)
            return CategoryShare(category: cat, amount: amount, ratio: ratio)
        }
        .sorted { $0.amount > $1.amount }
    }

    /// 최근 구매 (누끼 그리드용, 최대 12개)
    var recentItems: [ExpenseItem] {
        Array(items.prefix(12))
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await repository.fetchAll()
        } catch {
            self.error = error
        }
    }

    // MARK: - Helpers

    private func thisMonthItems(from: Date, to: Date) -> [ExpenseItem] {
        items.filter { $0.date >= from && $0.date <= to }
    }

    private func currentMonthRange() -> (from: Date, to: Date) {
        let cal = Calendar.current
        let now = Date.now
        let comps = cal.dateComponents([.year, .month], from: now)
        let from = cal.date(from: comps) ?? now
        let to = cal.date(byAdding: DateComponents(month: 1, second: -1), to: from) ?? now
        return (from, to)
    }
}

// MARK: - Supporting Types

struct CategoryShare: Identifiable {
    let category: ExpenseCategory
    let amount: Decimal
    let ratio: Double   // 0.0 ~ 1.0

    var id: String { category.id }
}
