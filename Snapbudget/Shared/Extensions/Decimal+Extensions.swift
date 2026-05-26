import Foundation

extension Decimal {
    /// 원화 포맷 문자열 반환 (예: "₩1,500")
    var wonFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KRW"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: self as NSDecimalNumber) ?? "₩0"
    }
}
