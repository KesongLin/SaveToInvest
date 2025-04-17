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
    
    // Updated addExpense function that fixes loading issues and incorporates ML classification
    func addExpense(title: String, amount: Double, date: Date, category: ExpenseCategory, isNecessary: Bool, notes: String?) {
        guard let userId = firebaseService.currentUser?.id else {
            // If there's no user ID, don't show loading and return early
            self.errorMessage = "User not authenticated"
            self.showError = true
            return
        }
        
        isLoading = true
        
        // Use a timeout to ensure the loading state gets cleared
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                if self?.isLoading == true {
                    self?.isLoading = false
                    self?.errorMessage = "Operation timed out"
                    self?.showError = true
                }
            }
        }
        
        // Save the user's classification for ML model improvement
        ExpenseClassifierService.shared.saveUserClassification(
            expenseTitle: title,
            category: category,
            isNecessary: isNecessary
        )
        
        // Generate a safe document ID that doesn't use the title
        let safeId = UUID().uuidString
        
        let expense = Expense(
            id: safeId, // Use UUID instead of anything based on title
            title: title,
            amount: amount,
            date: date,
            category: category,
            isNecessary: isNecessary,
            notes: notes,
            userId: userId
        )
        
        firebaseService.addExpense(expense: expense) { [weak self] success in
            // Always clear loading state, whether successful or not
            DispatchQueue.main.async {
                // Cancel the timeout timer since we got a response
                timeoutTimer.invalidate()
                
                self?.isLoading = false
                
                if !success {
                    self?.errorMessage = "Failed to add expense"
                    self?.showError = true
                }
            }
        }
    }
}
