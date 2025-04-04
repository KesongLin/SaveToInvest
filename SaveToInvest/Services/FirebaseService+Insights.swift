//
//  FirebaseService+Insights.swift
//  SaveToInvest
//
//  Created on 3/30/25.
//

import Foundation
import FirebaseFirestore

// Extension to add user insights methods to FirebaseService
extension FirebaseService {
    
    // Get user spending insights
    func getUserSpendingInsights(userId: String, completion: @escaping ([String: Any]?) -> Void) {
        db.collection("users").document(userId).collection("insights").document("spending")
            .getDocument { snapshot, error in
                if let error = error {
                    print("Error getting user spending insights: \(error)")
                    completion(nil)
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists,
                      let data = snapshot.data() else {
                    completion(nil)
                    return
                }
                
                completion(data)
            }
    }
    
    // Helper method to track user spending behavior
    func trackUserSpendingBehavior(userId: String, expense: Expense) {
        // Get current month and year
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: expense.date)
        guard let year = components.year, let month = components.month else { return }
        
        let monthYearId = "\(year)-\(month)"
        
        // Update monthly spending summary
        let monthlySummaryRef = db.collection("users").document(userId)
            .collection("spending_summary").document(monthYearId)
        
        // Use a transaction to safely update the summary
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let document = try transaction.getDocument(monthlySummaryRef)
                
                var summary: [String: Any]
                
                if document.exists {
                    // Existing summary - update it
                    guard var existingSummary = document.data() else {
                        return nil
                    }
                    
                    summary = existingSummary
                    
                    // Update total amount
                    let currentTotal = existingSummary["totalAmount"] as? Double ?? 0
                    summary["totalAmount"] = currentTotal + expense.amount
                    
                    // Update category amounts
                    var categoryAmounts = existingSummary["categoryAmounts"] as? [String: Double] ?? [:]
                    let currentCategoryAmount = categoryAmounts[expense.category.rawValue] ?? 0
                    categoryAmounts[expense.category.rawValue] = currentCategoryAmount + expense.amount
                    summary["categoryAmounts"] = categoryAmounts
                    
                    // Update necessary vs unnecessary breakdown
                    var necessaryAmount = existingSummary["necessaryAmount"] as? Double ?? 0
                    var unnecessaryAmount = existingSummary["unnecessaryAmount"] as? Double ?? 0
                    
                    if expense.isNecessary {
                        necessaryAmount += expense.amount
                    } else {
                        unnecessaryAmount += expense.amount
                    }
                    
                    summary["necessaryAmount"] = necessaryAmount
                    summary["unnecessaryAmount"] = unnecessaryAmount
                    
                } else {
                    // Create new summary
                    summary = [
                        "year": year,
                        "month": month,
                        "totalAmount": expense.amount,
                        "categoryAmounts": [expense.category.rawValue: expense.amount],
                        "necessaryAmount": expense.isNecessary ? expense.amount : 0,
                        "unnecessaryAmount": expense.isNecessary ? 0 : expense.amount,
                        "updatedAt": Timestamp(date: Date())
                    ]
                }
                
                transaction.setData(summary, forDocument: monthlySummaryRef)
                return nil
                
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }) { (_, error) in
            if let error = error {
                print("Error updating spending summary: \(error)")
            }
        }
    }
}
