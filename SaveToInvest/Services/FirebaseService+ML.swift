//
//  FirebaseService+ML.swift
//  SaveToInvest
//
//  Created on 3/30/25.
//

import Foundation
import FirebaseFirestore

// Extension to add ML-specific functions to FirebaseService
extension FirebaseService {
    
    func analyzeExpensePatterns(userId: String, completion: @escaping ([ExpenseCategory: Double]) -> Void) {
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        
        getExpensesByDateRange(userId: userId, startDate: sixMonthsAgo, endDate: Date()) { expenses in
            // Group expenses by category
            let expensesByCategory = Dictionary(grouping: expenses) { $0.category }
            
            // Calculate average spending per category
            var categoryAverages: [ExpenseCategory: Double] = [:]
            
            for (category, expenses) in expensesByCategory {
                let totalSpent = expenses.reduce(0) { $0 + $1.amount }
                let monthCount = Calendar.current.dateComponents([.month], from: sixMonthsAgo, to: Date()).month ?? 6
                let monthlyAverage = totalSpent / Double(max(1, monthCount))
                
                categoryAverages[category] = monthlyAverage
            }
            
            completion(categoryAverages)
        }
    }
    
    func identifyRecurringExpenses(userId: String, completion: @escaping ([String: [String: Any]]) -> Void) {
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        
        getExpensesByDateRange(userId: userId, startDate: threeMonthsAgo, endDate: Date()) { expenses in
            // Group expenses by title (case insensitive)
            let expensesByTitle = Dictionary(grouping: expenses) {
                $0.title.lowercased()
            }
            
            // Filter for potential recurring expenses (those that appear in multiple months)
            var recurringExpenses: [String: [String: Any]] = [:]
            
            for (title, expenses) in expensesByTitle {
                // Get the unique months in which this expense appears
                let uniqueMonths = Set(expenses.map { expense -> String in
                    let components = Calendar.current.dateComponents([.year, .month], from: expense.date)
                    return "\(components.year ?? 0)-\(components.month ?? 0)"
                })
                
                // If it appears in at least 2 different months, consider it recurring
                if uniqueMonths.count >= 2 {
                    let avgAmount = expenses.reduce(0) { $0 + $1.amount } / Double(expenses.count)
                    let category = expenses.first?.category.rawValue ?? "Unknown"
                    
                    recurringExpenses[title] = [
                        "averageAmount": avgAmount,
                        "category": category,
                        "frequency": "Monthly",
                        "occurrences": expenses.count,
                        "months": Array(uniqueMonths)
                    ] as [String: Any]
                }
            }
            
            completion(recurringExpenses)
        }
    }
    
    func predictExpenseCategory(title: String, amount: Double, completion: @escaping (ExpenseCategory) -> Void) {
        // Simple keyword-based prediction
        let titleLower = title.lowercased()
        
        // Create a dictionary mapping keywords to categories
        let keywordCategoryMap: [String: ExpenseCategory] = [
            "rent": .housing,
            "mortgage": .housing,
            "apartment": .housing,
            "grocery": .food,
            "restaurant": .food,
            "dinner": .food,
            "lunch": .food,
            "coffee": .food,
            "utilities": .utilities,
            "electric": .utilities,
            "water": .utilities,
            "gas": .utilities,
            "internet": .utilities,
            "phone": .utilities,
            "uber": .transportation,
            "lyft": .transportation,
            "taxi": .transportation,
            "bus": .transportation,
            "train": .transportation,
            "fuel": .transportation,
            "gas station": .transportation,
            "doctor": .healthcare,
            "medical": .healthcare,
            "medicine": .healthcare,
            "hospital": .healthcare,
            "movie": .entertainment,
            "concert": .entertainment,
            "netflix": .entertainment,
            "spotify": .entertainment,
            "clothes": .shopping,
            "shoes": .shopping,
            "amazon": .shopping,
            "tuition": .education,
            "book": .education,
            "course": .education,
            "vacation": .travel,
            "hotel": .travel,
            "flight": .travel,
            "airbnb": .travel
        ]
        
        // Check if any keyword matches
        for (keyword, category) in keywordCategoryMap {
            if titleLower.contains(keyword) {
                completion(category)
                return
            }
        }
        
        // If no match, use amount to help predict
        if amount > 1000 {
            completion(.housing)
        } else if amount > 200 {
            completion(.shopping)
        } else if amount > 50 {
            completion(.food)
        } else {
            completion(.other)
        }
    }
    
    // Helper method to save ML insights to user profile
    func saveUserInsights(userId: String, insights: [String: Any]) {
        db.collection("users").document(userId).collection("insights").document("ml")
            .setData(insights, merge: true) { error in
                if let error = error {
                    print("Error saving ML insights: \(error)")
                }
            }
    }
}
