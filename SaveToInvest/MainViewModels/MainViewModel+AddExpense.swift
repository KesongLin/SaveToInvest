//
//  MainViewModel+AddExpense.swift
//  SaveToInvest
//
//  Created by Kesong Lin on 3/30/25.
//
import Foundation
import FirebaseFirestore


// Extension for MainViewModel to update addExpense function
extension MainViewModel {
    func addExpense(title: String, amount: Double, date: Date, category: ExpenseCategory, isNecessary: Bool, notes: String?) {
        guard let userId = firebaseService.currentUser?.id else {
            DispatchQueue.main.async {
                self.errorMessage = "User not authenticated"
                self.showError = true
            }
            return
        }
        
        // Show loading state
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        // Create a more robust timeout
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                if self?.isLoading == true {
                    self?.isLoading = false
                    self?.errorMessage = "Operation timed out. Your changes may still be saved."
                    self?.showError = true
                    
                    // Force a refresh to ensure we have the latest data
                    self?.expenseAnalyzer.forceRefresh()
                }
            }
        }
        
        // Save the user's classification for ML model improvement
        ExpenseClassifierService.shared.saveUserClassification(
            expenseTitle: title,
            category: category,
            isNecessary: isNecessary
        )
        
        // Generate a safe document ID
        let safeId = UUID().uuidString
        
        let expense = Expense(
            id: safeId,
            title: title,
            amount: amount,
            date: date,
            category: category,
            isNecessary: isNecessary,
            notes: notes,
            userId: userId
        )
        
        firebaseService.addExpense(expense: expense) { [weak self] success in
            // Always run on main thread and cancel timeout
            DispatchQueue.main.async {
                timeoutTimer.invalidate()
                
                self?.isLoading = false
                
                if !success {
                    self?.errorMessage = "Failed to add expense"
                    self?.showError = true
                } else {
                    // Force an immediate refresh on success
                    self?.expenseAnalyzer.analyzeExpenses()
                }
            }
        }
    }
}
