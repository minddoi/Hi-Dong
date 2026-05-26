import Foundation

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case food = "food"
    case shopping = "shopping"
    case transport = "transport"
    case entertainment = "entertainment"
    case health = "health"
    case beauty = "beauty"
    case electronics = "electronics"
    case household = "household"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food:          return "식품/음식"
        case .shopping:      return "쇼핑"
        case .transport:     return "교통"
        case .entertainment: return "여가/오락"
        case .health:        return "건강"
        case .beauty:        return "미용"
        case .electronics:   return "전자기기"
        case .household:     return "생활용품"
        case .other:         return "기타"
        }
    }

    var emoji: String {
        switch self {
        case .food:          return "🍽️"
        case .shopping:      return "🛍️"
        case .transport:     return "🚇"
        case .entertainment: return "🎮"
        case .health:        return "💊"
        case .beauty:        return "💄"
        case .electronics:   return "📱"
        case .household:     return "🏠"
        case .other:         return "📦"
        }
    }
}
