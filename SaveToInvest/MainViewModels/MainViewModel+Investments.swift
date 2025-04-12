//
//  MainViewModel+Investments.swift
//  SaveToInvest
//
//  Created on 4/2/25.
//

import Foundation
import Combine
import SwiftUI

// Extension for MainViewModel to handle investment data
extension MainViewModel {
    // Initialize investment data and setup auto-refresh
    func setupInvestmentData() {
        // Register for app lifecycle notifications to refresh data when app becomes active
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBecameActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Set up a publisher to monitor investment data changes
        // Instead of storing in cancellables, we'll keep track directly in the extension
        let cancellable = InvestmentDataManager.shared.$investments
            .sink { [weak self] investments in
                DispatchQueue.main.async {
                    self?.expenseAnalyzer.investments = investments
                    // Recalculate opportunity costs after updating investments
                    self?.updateOpportunityCosts()
                }
            }
        
        // Store the cancellable using an associated object to avoid accessing private properties
        objc_setAssociatedObject(self, "investmentsCancellable", cancellable, .OBJC_ASSOCIATION_RETAIN)
        
        // Refresh investment data immediately
        Task {
            await refreshInvestmentData()
        }
    }
    
    // Handle app becoming active - refresh investment data
    @objc private func handleAppBecameActive() {
        Task {
            await refreshInvestmentData()
        }
    }
    
    // Refresh investment data from API
    func refreshInvestmentData() async {
        // Only refresh if we haven't refreshed in the last hour
        if let lastRefresh = InvestmentDataManager.shared.lastRefreshDate,
           Date().timeIntervalSince(lastRefresh) < 3600 {
            return
        }
        
        isLoading = true
        
        await InvestmentDataManager.shared.refreshInvestments()
        
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
    
    // Generate savings and investment plan
    func generateSavingsAndInvestmentPlan(
        riskTolerance: RiskTolerance = .moderate,
        savingsTarget: Double? = nil
    ) -> SavingsAndInvestmentPlan {
        // Get all expenses for the user
        guard let userId = firebaseService.currentUser?.id else {
            // Return empty plan if no user
            return SavingsAndInvestmentPlan(
                recommendedMonthlySavings: 0,
                riskTolerance: riskTolerance,
                savingsPotential: SavingsPotentialReport(
                    totalUnnecessarySpending: 0,
                    savingsAt20Percent: 0,
                    savingsAt50Percent: 0,
                    savingsAt70Percent: 0,
                    categorySavings: [:],
                    specificSavings: []
                ),
                recommendedInvestments: [],
                totalProjections: []
            )
        }
        
        // Calculate plan using SavingsBreakdownService
        return SavingsBreakdownService.shared.createSavingsAndInvestmentPlan(
            from: expenseAnalyzer.expenses,
            investments: expenseAnalyzer.investments,
            riskTolerance: riskTolerance,
            savingsTarget: savingsTarget
        )
    }
    
    // Get real-time quote for a specific ticker
    func getRealTimeQuote(for ticker: String) async -> QuoteData? {
        return await InvestmentDataManager.shared.getRealTimeQuote(for: ticker)
    }
    
    // Calculate potential savings from reducing specific expenses
    func calculateSpecificSavings() -> [SpecificSaving] {
        // Get unnecessary expenses
        let unnecessaryExpenses = expenseAnalyzer.unnecessaryExpenses
        
        // Return empty array if no expenses
        if unnecessaryExpenses.isEmpty {
            return []
        }
        
        // Calculate savings using SavingsBreakdownService
        let savingsPotential = SavingsBreakdownService.shared.calculateSavingsPotential(
            from: unnecessaryExpenses
        )
        
        return savingsPotential.specificSavings
    }
    
    // Update opportunity costs instead of calling private method
    private func updateOpportunityCosts() {
        // Since we can't access the private calculateOpportunityCosts method,
        // we'll update the investments directly and let the ExpenseAnalyzer handle it
        
        // The analyzer will recalculate the opportunity costs when needed
        expenseAnalyzer.analyzeExpenses()
    }
}
