import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    var id: String
    var email: String
    var displayName: String?
    var createdAt: Date
    var settings: UserSettings
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "email": email,
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let displayName = displayName {
            dict["displayName"] = displayName
        }
        
        dict["settings"] = settings.dictionary
        
        return dict
    }
    
    init(id: String, email: String, displayName: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = Date()
        self.settings = UserSettings()
    }
    
    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let email = dictionary["email"] as? String,
              let createdTimestamp = dictionary["createdAt"] as? Timestamp else {
            return nil
        }
        
        self.id = id
        self.email = email
        self.displayName = dictionary["displayName"] as? String
        self.createdAt = createdTimestamp.dateValue()
        
        if let settingsDict = dictionary["settings"] as? [String: Any] {
            self.settings = UserSettings(dictionary: settingsDict) ?? UserSettings()
        } else {
            self.settings = UserSettings()
        }
    }
}

struct UserSettings: Codable {
    var defaultInvestmentId: String?
    var defaultProjectionYears: Int = 10
    var isFirstLaunch: Bool = true
    var categoryPreferences: [String: Bool] = [:]
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "defaultProjectionYears": defaultProjectionYears,
            "isFirstLaunch": isFirstLaunch
        ]
        
        if let defaultInvestmentId = defaultInvestmentId {
            dict["defaultInvestmentId"] = defaultInvestmentId
        }
        
        dict["categoryPreferences"] = categoryPreferences
        
        return dict
    }
    
    init() {}
    
    init?(dictionary: [String: Any]) {
        self.defaultInvestmentId = dictionary["defaultInvestmentId"] as? String
        self.defaultProjectionYears = dictionary["defaultProjectionYears"] as? Int ?? 10
        self.isFirstLaunch = dictionary["isFirstLaunch"] as? Bool ?? true
        self.categoryPreferences = dictionary["categoryPreferences"] as? [String: Bool] ?? [:]
    }
}
