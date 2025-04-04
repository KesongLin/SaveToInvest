//
//  ExpenseClassifierService.swift
//  SaveToInvest
//
//  Created by Kesong Lin on 3/30/25.
//

import Foundation
import FirebaseFirestore

class ExpenseClassifierService {
    
    // Singleton pattern for global access
    static let shared = ExpenseClassifierService()
    
    // Historical classification data to improve predictions
    private var userClassificationHistory: [String: Bool] = [:]
    private let firebaseService = FirebaseService()
    
    private init() {
        loadUserTrainingData()
    }
    
    // Feature extraction for expense classification
    private let keywordDictionary: [String: Bool] = [
        // Necessary keywords
        "rent": true,
        "mortgage": true,
        "grocery": true,
        "utilities": true,
        "electric": true,
        "water": true,
        "gas": true,
        "internet": true,
        "phone": true,
        "insurance": true,
        "medicine": true,
        "doctor": true,
        "hospital": true,
        "transportation": true,
        "bus": true,
        "train": true,
        "fuel": true,
        
        // Non-necessary keywords
        "restaurant": false,
        "dining": false,
        "cafe": false,
        "coffee": false,
        "bar": false,
        "movie": false,
        "entertainment": false,
        "shopping": false,
        "clothes": false,
        "shoes": false,
        "electronics": false,
        "game": false,
        "subscription": false,
        "travel": false,
        "vacation": false,
        "hotel": false
    ]
    
    // Load user's historical classifications from Firebase/local storage
    private func loadUserTrainingData() {
        if let userId = firebaseService.currentUser?.id {
            firebaseService.getExpenseClassifications(userId: userId) { [weak self] classifications in
                if let classifications = classifications {
                    self?.userClassificationHistory = classifications
                }
            }
        }
    }
    
    // Save user's manual classifications to improve the model
    func saveUserClassification(expenseTitle: String, category: ExpenseCategory, isNecessary: Bool) {
        // Normalize the title for better pattern matching
        let normalizedTitle = expenseTitle.lowercased()
        userClassificationHistory[normalizedTitle] = isNecessary
        
        // Save to Firebase for persistence
        if let userId = firebaseService.currentUser?.id {
            firebaseService.updateExpenseClassification(userId: userId, expenseTitle: normalizedTitle, isNecessary: isNecessary)
        }
    }
    
    // Main classification function
    func predictIsNecessary(title: String, amount: Double, category: ExpenseCategory) -> Bool {
        // Step 1: Check if the user has already classified this exact title
        let normalizedTitle = title.lowercased()
        if let previousClassification = userClassificationHistory[normalizedTitle] {
            return previousClassification
        }
        
        // Step 2: Check if the category has a default necessity
        let categoryNecessity = category.isTypicallyNecessary
        
        // Step 3: Check amount relative to user's average spending in this category
        let isHighAmount = isExpenseAmountHigh(amount: amount, category: category)
        
        // Step 4: Keyword matching from the title
        var keywordScore = 0.0
        var matchCount = 0
        
        for (keyword, isNecessary) in keywordDictionary {
            if normalizedTitle.contains(keyword) {
                keywordScore += isNecessary ? 1.0 : -1.0
                matchCount += 1
            }
        }
        
        // If we have keyword matches, use them for classification
        if matchCount > 0 {
            let normalizedScore = keywordScore / Double(matchCount)
            return normalizedScore > 0
        }
        
        // Step 5: If we're unsure, fall back to category default,
        // but consider amount (high amounts in necessary categories might be luxury)
        if isHighAmount && categoryNecessity {
            // Might be a luxury version of a necessary expense
            return false
        }
        
        return categoryNecessity
    }
    
    // Helper function to determine if an expense amount is high relative to user history
    private func isExpenseAmountHigh(amount: Double, category: ExpenseCategory) -> Bool {
        // In a real app, compare to user's average spending in this category
        // For now, use simple threshold based on category
        
        switch category {
        case .food:
            return amount > 50.0 // Expensive meal
        case .housing:
            return amount > 3000.0 // Luxury housing
        case .transportation:
            return amount > 100.0 // Luxury transport
        case .utilities:
            return amount > 200.0 // High utility bill
        case .healthcare:
            return amount > 300.0 // Expensive healthcare
        case .education:
            return amount > 500.0 // Premium education expense
        case .shopping:
            return amount > 100.0 // Expensive shopping
        case .entertainment:
            return amount > 75.0 // Expensive entertainment
        case .travel:
            return amount > 300.0 // Luxury travel
        case .other:
            return amount > 100.0 // Generic threshold
        }
    }
    
    // Consider recurring transactions and patterns
    func analyzeUserSpendingPatterns() -> [ExpenseCategory: Double] {
        // Get user's expenses from the past 6 months
        guard let userId = firebaseService.currentUser?.id else {
            return [:]
        }
        
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        var categoryInsights: [ExpenseCategory: Double] = [:]
        var categoryTrends: [ExpenseCategory: Bool] = [:] // true = increasing, false = decreasing
        var recurringExpensesByCategory: [ExpenseCategory: [(String, Double)]] = [:]
        
        // Fetch expenses from Firebase
        firebaseService.getExpensesByDateRange(userId: userId, startDate: sixMonthsAgo, endDate: Date()) { expenses in
            // Group expenses by month and category for trend analysis
            let expensesByMonth = Dictionary(grouping: expenses) { expense in
                let components = Calendar.current.dateComponents([.year, .month], from: expense.date)
                return "\(components.year ?? 0)-\(components.month ?? 0)"
            }
            
            // Sort months chronologically
            let sortedMonths = expensesByMonth.keys.sorted()
            
            // Calculate average spending per category
            let expensesByCategory = Dictionary(grouping: expenses) { $0.category }
            for (category, categoryExpenses) in expensesByCategory {
                let totalSpent = categoryExpenses.reduce(0) { $0 + $1.amount }
                let monthlyAverage = totalSpent / Double(min(6, sortedMonths.count)) // Up to 6 months
                categoryInsights[category] = monthlyAverage
                
                // Look for recurring expenses within each category
                let expensesByTitle = Dictionary(grouping: categoryExpenses) { $0.title.lowercased() }
                let possiblyRecurring = expensesByTitle.filter { _, expenses in
                    // If something appears in at least 3 different months, consider it recurring
                    let uniqueMonths = Set(expenses.map {
                        let components = Calendar.current.dateComponents([.year, .month], from: $0.date)
                        return "\(components.year ?? 0)-\(components.month ?? 0)"
                    })
                    return uniqueMonths.count >= 3
                }
                
                recurringExpensesByCategory[category] = possiblyRecurring.map { title, expenses in
                    let avgAmount = expenses.reduce(0) { $0 + $1.amount } / Double(expenses.count)
                    return (title, avgAmount)
                }
                
                // Detect trend (increasing or decreasing)
                if sortedMonths.count >= 3 {
                    var monthlyTotals: [String: Double] = [:]
                    for month in sortedMonths {
                        let monthExpenses = expensesByMonth[month] ?? []
                        let categoryMonthExpenses = monthExpenses.filter { $0.category == category }
                        monthlyTotals[month] = categoryMonthExpenses.reduce(0) { $0 + $1.amount }
                    }
                    
                    // Check if spending is trending up or down
                    let recentMonths = Array(sortedMonths.suffix(3))
                    if recentMonths.count == 3 {
                        let trend = (monthlyTotals[recentMonths[2]] ?? 0) > (monthlyTotals[recentMonths[0]] ?? 0)
                        categoryTrends[category] = trend
                    }
                }
            }
            
            // Store insights in user preferences
            let userPreferences: [String: Any] = [
                "categoryAverages": self.mapToDictionary(categoryInsights),
                "categoryTrends": self.mapToDictionary(categoryTrends),
                "recurringExpenses": self.mapRecurringExpenses(recurringExpensesByCategory)
            ]
            
            self.firebaseService.updateUserSpendingInsights(userId: userId, insights: userPreferences)
        }
        
        return categoryInsights
    }
    
    // Helper methods to convert dictionaries for Firebase storage
    private func mapToDictionary<T>(_ dict: [ExpenseCategory: T]) -> [String: T] {
        var result: [String: T] = [:]
        for (key, value) in dict {
            result[key.rawValue] = value
        }
        return result
    }
    
    private func mapRecurringExpenses(_ dict: [ExpenseCategory: [(String, Double)]]) -> [String: [[String: Any]]] {
        var result: [String: [[String: Any]]] = [:]
        for (category, expenses) in dict {
            let mappedExpenses: [[String: Any]] = expenses.map { title, amount in
                return ["title": title, "amount": amount] as [String: Any]
            }
            result[category.rawValue] = mappedExpenses
        }
        return result
    }
}
