import Foundation

/// 지출 데이터 접근을 추상화하는 Repository 프로토콜
/// - 비즈니스 로직이 저장소 구현(SwiftData, Mock 등)에 의존하지 않도록 분리
protocol ExpenseRepository: Sendable {
    func fetchAll() async throws -> [ExpenseItem]
    func fetchByDateRange(from: Date, to: Date) async throws -> [ExpenseItem]
    func fetchByCategory(_ category: ExpenseCategory) async throws -> [ExpenseItem]
    func add(_ item: ExpenseItem) async throws
    func update(_ item: ExpenseItem) async throws
    func delete(_ item: ExpenseItem) async throws
    func totalAmount(from: Date, to: Date) async throws -> Decimal
}
