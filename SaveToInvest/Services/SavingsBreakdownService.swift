//
//  SavingsBreakdownService.swift
//  SaveToInvest
//
//  Created by Kesong Lin on 4/2/25.
//


import Foundation

class SavingsBreakdownService {
    // Singleton instance
    static let shared = SavingsBreakdownService()
    
    // Standard expense categories with typical costs
    private struct StandardExpense {
        let name: String
        let category: ExpenseCategory
        let typicalCost: Double
        let frequency: ExpenseFrequency
        let icon: String
    }
    
    enum ExpenseFrequency: String {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"
        case yearly = "yearly"
        
        var occurrencesPerMonth: Double {
            switch self {
            case .daily: return 30.0
            case .weekly: return 4.3
            case .monthly: return 1.0
            case .yearly: return 1.0 / 12.0
            }
        }
    }
    
    private let standardExpenses: [StandardExpense] = [
        // Food & Dining
        StandardExpense(name: "Coffee Shop", category: .food, typicalCost: 5.0, frequency: .daily, icon: "cup.and.saucer.fill"),
        StandardExpense(name: "Lunch Out", category: .food, typicalCost: 15.0, frequency: .daily, icon: "takeoutbag.and.cup.and.straw.fill"),
        StandardExpense(name: "Dinner Out", category: .food, typicalCost: 35.0, frequency: .weekly, icon: "fork.knife"),
        StandardExpense(name: "Food Delivery", category: .food, typicalCost: 25.0, frequency: .weekly, icon: "bicycle"),
        
        // Entertainment
        StandardExpense(name: "Movie Theater", category: .entertainment, typicalCost: 15.0, frequency: .weekly, icon: "film.fill"),
        StandardExpense(name: "Streaming Services", category: .entertainment, typicalCost: 15.0, frequency: .monthly, icon: "tv.fill"),
        StandardExpense(name: "Concerts", category: .entertainment, typicalCost: 80.0, frequency: .monthly, icon: "music.note"),
        StandardExpense(name: "Gaming", category: .entertainment, typicalCost: 60.0, frequency: .monthly, icon: "gamecontroller.fill"),
        
        // Shopping
        StandardExpense(name: "Clothing", category: .shopping, typicalCost: 100.0, frequency: .monthly, icon: "tshirt.fill"),
        StandardExpense(name: "Electronics", category: .shopping, typicalCost: 100.0, frequency: .monthly, icon: "headphones"),
        StandardExpense(name: "Impulse Purchases", category: .shopping, typicalCost: 50.0, frequency: .weekly, icon: "bag.fill"),
        
        // Transportation
        StandardExpense(name: "Rideshare", category: .transportation, typicalCost: 20.0, frequency: .weekly, icon: "car.fill"),
        
        // Travel
        StandardExpense(name: "Weekend Trips", category: .travel, typicalCost: 200.0, frequency: .monthly, icon: "airplane"),
        StandardExpense(name: "Vacation", category: .travel, typicalCost: 1500.0, frequency: .yearly, icon: "beach.umbrella.fill")
    ]
    
    private init() {}
    
    // Calculate savings potential based on user's expenses
    func calculateSavingsPotential(from expenses: [Expense]) -> SavingsPotentialReport {
        let unnecessaryExpenses = expenses.filter { !$0.isNecessary }
        
        // Calculate total unnecessary spending
        let totalUnnecessaryAmount = unnecessaryExpenses.reduce(0) { $0 + $1.amount }
        
        // Calculate savings scenarios
        let savings20Percent = totalUnnecessaryAmount * 0.2
        let savings50Percent = totalUnnecessaryAmount * 0.5
        let savings70Percent = totalUnnecessaryAmount * 0.7
        
        // Group expenses by category
        let expensesByCategory = Dictionary(grouping: unnecessaryExpenses) { $0.category }
        
        // Calculate categorical savings
        var categorySavings: [ExpenseCategory: Double] = [:]
        for (category, expenses) in expensesByCategory {
            categorySavings[category] = expenses.reduce(0) { $0 + $1.amount }
        }
        
        // Generate specific expense reductions
        var specificSavings: [SpecificSaving] = []
        
        // Process each standard expense type
        for standardExpense in standardExpenses {
            // Calculate how much the user might be spending on this category
            let categoryExpenses = unnecessaryExpenses.filter { $0.category == standardExpense.category }
            let categoryTotal = categoryExpenses.reduce(0) { $0 + $1.amount }
            
            // Skip if user doesn't spend in this category
            if categoryTotal <= 0 {
                continue
            }
            
            // Calculate potential reductions based on standard expense
            let monthlyCost = standardExpense.typicalCost * standardExpense.frequency.occurrencesPerMonth
            
            // Skip if this specific expense would represent more than 80% of the category total
            // (This helps filter out unlikely matches)
            if monthlyCost > categoryTotal * 0.8 {
                continue
            }
            
            // Calculate various reduction scenarios
            let reduction25 = monthlyCost * 0.25
            let reduction50 = monthlyCost * 0.5
            let reduction75 = monthlyCost * 0.75
            
            specificSavings.append(SpecificSaving(
                name: standardExpense.name,
                category: standardExpense.category,
                icon: standardExpense.icon,
                currentMonthlyCost: monthlyCost,
                reductionOptions: [
                    ReductionOption(percentage: 25, savings: reduction25, description: "Cut by 25%"),
                    ReductionOption(percentage: 50, savings: reduction50, description: "Cut by 50%"),
                    ReductionOption(percentage: 75, savings: reduction75, description: "Cut by 75%")
                ]
            ))
        }
        
        return SavingsPotentialReport(
            totalUnnecessarySpending: totalUnnecessaryAmount,
            savingsAt20Percent: savings20Percent,
            savingsAt50Percent: savings50Percent,
            savingsAt70Percent: savings70Percent,
            categorySavings: categorySavings,
            specificSavings: specificSavings.sorted(by: { $0.currentMonthlyCost > $1.currentMonthlyCost })
        )
    }
    
    // Calculate investment projections for a specific monthly saving amount
    func calculateInvestmentProjection(
        monthlySavings: Double,
        investmentReturn: Double,
        years: Int
    ) -> InvestmentProjection {
        // Monthly interest rate
        let monthlyRate = investmentReturn / 100 / 12
        
        // Calculate future value with compound interest
        let months = Double(years * 12)
        let futureValue = monthlySavings * ((pow(1 + monthlyRate, months) - 1) / monthlyRate)
        
        // Calculate total contributions
        let totalContributions = monthlySavings * months
        
        // Calculate interest earned
        let interestEarned = futureValue - totalContributions
        
        return InvestmentProjection(
            monthlySavings: monthlySavings,
            annualReturn: investmentReturn,
            years: years,
            futureValue: futureValue,
            totalContributions: totalContributions,
            interestEarned: interestEarned
        )
    }
    
    // Calculate comprehensive savings and investment plan
    func createSavingsAndInvestmentPlan(
        from expenses: [Expense],
        investments: [Investment],
        riskTolerance: RiskTolerance = .moderate,
        savingsTarget: Double? = nil
    ) -> SavingsAndInvestmentPlan {
        // Get the savings potential report
        let savingsPotential = calculateSavingsPotential(from: expenses)
        
        // Determine the recommended savings amount
        // If user specified a target, use that, otherwise use 50% of unnecessary spending
        let recommendedMonthlySavings = savingsTarget ?? savingsPotential.savingsAt50Percent
        
        // Find the best investment options based on risk tolerance
        var recommendedInvestments: [RecommendedInvestment] = []
        var remainingAllocation = 100.0
        
        // Sort investments by quality for the given risk tolerance
        let sortedInvestments = investments
            .filter { investment in
                switch riskTolerance {
                case .conservative:
                    return investment.riskLevel == .low || investment.riskLevel == .medium
                case .moderate:
                    return true // All risk levels are acceptable
                case .aggressive:
                    return investment.riskLevel == .medium || investment.riskLevel == .high
                }
            }
            .sorted { inv1, inv2 in
                // First sort by risk level appropriate for tolerance
                if riskTolerance == .conservative {
                    if inv1.riskLevel.rawValue != inv2.riskLevel.rawValue {
                        return inv1.riskLevel == .low // Lower risk first for conservative
                    }
                } else if riskTolerance == .aggressive {
                    if inv1.riskLevel.rawValue != inv2.riskLevel.rawValue {
                        return inv1.riskLevel == .high // Higher risk first for aggressive
                    }
                }
                
                // Then sort by Sharpe ratio (higher is better)
                return inv1.sharpeRatio > inv2.sharpeRatio
            }
        
        // Allocate investments based on recommended percentages
        for investment in sortedInvestments {
            if recommendedInvestments.count >= 4 || remainingAllocation <= 0 {
                break // Limit to top 4 investments
            }
            
            var allocationPercentage = investment.recommendedAllocation(for: riskTolerance)
            
            // Adjust allocation if it exceeds remaining allocation
            if allocationPercentage > remainingAllocation {
                allocationPercentage = remainingAllocation
            }
            
            // Calculate monthly amount
            let monthlyAmount = (recommendedMonthlySavings * allocationPercentage) / 100.0
            
            // Skip if allocation is too small
            if allocationPercentage < 5 || monthlyAmount < 10 {
                continue
            }
            
            // Calculate projections
            let oneYearProjection = calculateInvestmentProjection(
                monthlySavings: monthlyAmount,
                investmentReturn: investment.annualizedReturn,
                years: 1
            )
            
            let fiveYearProjection = calculateInvestmentProjection(
                monthlySavings: monthlyAmount,
                investmentReturn: investment.annualizedReturn,
                years: 5
            )
            
            let tenYearProjection = calculateInvestmentProjection(
                monthlySavings: monthlyAmount,
                investmentReturn: investment.annualizedReturn,
                years: 10
            )
            
            let twentyYearProjection = calculateInvestmentProjection(
                monthlySavings: monthlyAmount,
                investmentReturn: investment.annualizedReturn,
                years: 20
            )
            
            // Add recommended investment
            recommendedInvestments.append(RecommendedInvestment(
                investment: investment,
                allocationPercentage: allocationPercentage,
                monthlyAmount: monthlyAmount,
                projections: [
                    oneYearProjection,
                    fiveYearProjection,
                    tenYearProjection,
                    twentyYearProjection
                ]
            ))
            
            // Update remaining allocation
            remainingAllocation -= allocationPercentage
        }
        
        // Calculate total projections
        let totalOneYearProjection = calculateInvestmentProjection(
            monthlySavings: recommendedMonthlySavings,
            investmentReturn: 7.0, // Average market return
            years: 1
        )
        
        let totalFiveYearProjection = calculateInvestmentProjection(
            monthlySavings: recommendedMonthlySavings,
            investmentReturn: 7.0,
            years: 5
        )
        
        let totalTenYearProjection = calculateInvestmentProjection(
            monthlySavings: recommendedMonthlySavings,
            investmentReturn: 7.0,
            years: 10
        )
        
        let totalTwentyYearProjection = calculateInvestmentProjection(
            monthlySavings: recommendedMonthlySavings,
            investmentReturn: 7.0,
            years: 20
        )
        
        return SavingsAndInvestmentPlan(
            recommendedMonthlySavings: recommendedMonthlySavings,
            riskTolerance: riskTolerance,
            savingsPotential: savingsPotential,
            recommendedInvestments: recommendedInvestments,
            totalProjections: [
                totalOneYearProjection,
                totalFiveYearProjection,
                totalTenYearProjection,
                totalTwentyYearProjection
            ]
        )
    }
}

// Data models for savings breakdown
struct SavingsPotentialReport {
    let totalUnnecessarySpending: Double
    let savingsAt20Percent: Double
    let savingsAt50Percent: Double
    let savingsAt70Percent: Double
    let categorySavings: [ExpenseCategory: Double]
    let specificSavings: [SpecificSaving]
}

struct SpecificSaving {
    let name: String
    let category: ExpenseCategory
    let icon: String
    let currentMonthlyCost: Double
    let reductionOptions: [ReductionOption]
}

struct ReductionOption {
    let percentage: Int
    let savings: Double
    let description: String
}

struct InvestmentProjection {
    let monthlySavings: Double
    let annualReturn: Double
    let years: Int
    let futureValue: Double
    let totalContributions: Double
    let interestEarned: Double
}

struct RecommendedInvestment {
    let investment: Investment
    let allocationPercentage: Double
    let monthlyAmount: Double
    let projections: [InvestmentProjection] // 1, 5, 10, 20 years
}

struct SavingsAndInvestmentPlan {
    let recommendedMonthlySavings: Double
    let riskTolerance: RiskTolerance
    let savingsPotential: SavingsPotentialReport
    let recommendedInvestments: [RecommendedInvestment]
    let totalProjections: [InvestmentProjection] // 1, 5, 10, 20 years
}
