//
//  TransactionClassifier.swift
//  SaveToInvest
//
//  Created by Kesong Lin on 4/10/25.
//

import Foundation
import FirebaseFirestore

/// A classifier that learns from user corrections to transaction classifications
class TransactionClassifier {
    // Singleton instance
    static let shared = TransactionClassifier()
    
    // Firebase service reference for data persistence
    private let firebaseService = FirebaseService()
    
    // Classification history to improve predictions
    private var transactionClassificationHistory: [String: Bool] = [:]
    
    private init() {
        // Load any existing classification data
        loadUserData()
    }
    
    /// Load user's transaction classification data
    private func loadUserData() {
        guard let userId = firebaseService.currentUser?.id else { return }
        
        // We could load existing classification data from Firestore here
        // For now, just using the ExpenseClassifierService's data
        firebaseService.getExpenseClassifications(userId: userId) { [weak self] classifications in
            if let classifications = classifications {
                self?.transactionClassificationHistory = classifications
            }
        }
    }
    
    /// Learn from a user correction to transaction classification
    /// - Parameters:
    ///   - transaction: The transaction being classified
    ///   - isNecessary: Whether the transaction is necessary
    func learnFromCorrection(transaction: ImportedTransaction, isNecessary: Bool) {
        // Normalize the transaction description for consistent matching
        let normalizedDesc = transaction.description.lowercased()
        
        // Store the classification in memory
        transactionClassificationHistory[normalizedDesc] = isNecessary
        
        // Save to Firebase if possible
        if let userId = firebaseService.currentUser?.id {
            // Pass both the original and sanitized descriptions
            firebaseService.updateExpenseClassification(
                userId: userId,
                expenseTitle: normalizedDesc, // This will be sanitized in the method
                isNecessary: isNecessary
            )
        }
        
        print("Learned classification for '\(normalizedDesc)': \(isNecessary ? "necessary" : "non-necessary")")
        
        // Update ExpenseClassifierService as well
        if let category = transaction.suggestedCategory?.toExpenseCategory() {
            ExpenseClassifierService.shared.saveUserClassification(
                expenseTitle: transaction.description,
                category: category,
                isNecessary: isNecessary
            )
        }
    }
    
    /// Predict if a transaction is necessary based on previous learning
    /// - Parameters:
    ///   - transaction: The transaction to classify
    /// - Returns: Prediction of whether the transaction is necessary
    func predictIsNecessary(transaction: ImportedTransaction) -> Bool {
        // First check our learned classifications
        let normalizedDesc = transaction.description.lowercased()
        if let storedClassification = transactionClassificationHistory[normalizedDesc] {
            return storedClassification
        }
        
        // If no specific learning for this transaction, use the category default
        return transaction.suggestedCategory?.isTypicallyNecessary ?? false
    }
}
