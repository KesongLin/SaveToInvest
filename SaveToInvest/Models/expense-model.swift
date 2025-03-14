import Foundation
import FirebaseFirestore

struct Expense: Identifiable, Codable {
    var id: String = UUID().uuidString
    var title: String
    var amount: Double
    var date: Date
    var category: ExpenseCategory
    var isNecessary: Bool
    var notes: String?
    var createdAt: Date = Date()
    var userId: String
    
    // Firestore适配器
    var dictionary: [String: Any] {
        return [
            "id": id,
            "title": title,
            "amount": amount,
            "date": Timestamp(date: date),
            "category": category.rawValue,
            "isNecessary": isNecessary,
            "notes": notes ?? "",
            "createdAt": Timestamp(date: createdAt),
            "userId": userId
        ]
    }
    
    init(id: String = UUID().uuidString, 
         title: String, 
         amount: Double, 
         date: Date, 
         category: ExpenseCategory, 
         isNecessary: Bool, 
         notes: String? = nil,
         userId: String) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.category = category
        self.isNecessary = isNecessary
        self.notes = notes
        self.userId = userId
    }
    
    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let title = dictionary["title"] as? String,
              let amount = dictionary["amount"] as? Double,
              let timestamp = dictionary["date"] as? Timestamp,
              let categoryRaw = dictionary["category"] as? String,
              let isNecessary = dictionary["isNecessary"] as? Bool,
              let userId = dictionary["userId"] as? String,
              let category = ExpenseCategory(rawValue: categoryRaw) else {
            return nil
        }
        
        self.id = id
        self.title = title
        self.amount = amount
        self.date = timestamp.dateValue()
        self.category = category
        self.isNecessary = isNecessary
        self.notes = dictionary["notes"] as? String
        
        if let createdTimestamp = dictionary["createdAt"] as? Timestamp {
            self.createdAt = createdTimestamp.dateValue()
        }
        
        self.userId = userId
    }
}

enum ExpenseCategory: String, Codable, CaseIterable {
    case food = "Food"
    case housing = "Housing"
    case transportation = "Transportation"
    case entertainment = "Entertainment"
    case utilities = "Utilities"
    case healthcare = "Healthcare"
    case shopping = "Shopping"
    case education = "Education"
    case travel = "Travel"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .housing: return "house"
        case .transportation: return "car"
        case .entertainment: return "film"
        case .utilities: return "bolt"
        case .healthcare: return "heart"
        case .shopping: return "bag"
        case .education: return "book"
        case .travel: return "airplane"
        case .other: return "ellipsis.circle"
        }
    }
    
    var isTypicallyNecessary: Bool {
        switch self {
        case .food, .housing, .transportation, .utilities, .healthcare, .education:
            return true
        case .entertainment, .shopping, .travel, .other:
            return false
        }
    }
}
