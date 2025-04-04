//
//  InvestmentComponents.swift
//  SaveToInvest
//
//  Created on 3/30/25.
//

import SwiftUI

struct InvestmentReturnChart: View {
    let opportunityCosts: [OpportunityCost]
    let selectedInvestment: Investment
    let selectedTimeframe: Int
    
    // Colors for the chart
    private let barColor = Color.blue
    private let gridColor = Color.gray.opacity(0.3)
    private let textColor = Color.secondary
    
    private var maxValue: Double {
        let values = getProjectedValues()
        return values.map { $0.value }.max() ?? 1000
    }
    
    private func getProjectedValues() -> [(year: Int, value: Double)] {
        // Find the relevant opportunity cost if available
        let relevantOpportunity = opportunityCosts.first
        
        var projectedValues: [(year: Int, value: Double)] = []
        
        // If we have actual opportunity cost data
        if let opportunity = relevantOpportunity,
           let projectedReturn = opportunity.projectedReturns.first(where: { $0.year == selectedTimeframe }) {
            // Use actual projected returns for the selected timeframe
            projectedValues.append((selectedTimeframe, projectedReturn.totalValue))
        } else {
            // Fallback to a simple calculation based on investment return rate
            let monthlyAmount = opportunityCosts.reduce(0) { $0 + $1.monthlyAmount }
            let rate = selectedInvestment.averageAnnualReturn / 100 / 12 // Monthly rate
            let months = Double(selectedTimeframe * 12)
            
            // Compound interest formula for regular contributions
            let futureValue = monthlyAmount * ((pow(1 + rate, months) - 1) / rate)
            projectedValues.append((selectedTimeframe, futureValue))
        }
        
        // Add intermediary points for a better visualization
        if selectedTimeframe > 1 {
            for year in 1..<selectedTimeframe {
                let value = projectedValues[0].value * Double(year) / Double(selectedTimeframe)
                projectedValues.append((year, value))
            }
        }
        
        return projectedValues.sorted(by: { $0.year < $1.year })
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Grid lines
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<5) { i in
                        Divider()
                            .background(gridColor)
                            .padding(.bottom, geometry.size.height / 5 - 1)
                    }
                }
                
                // Y-axis labels
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<5) { i in
                        let value = maxValue * Double(4 - i) / 4
                        Text(formatCurrency(value))
                            .font(.caption)
                            .foregroundColor(textColor)
                            .padding(.bottom, geometry.size.height / 5 - 10)
                    }
                }
                .padding(.leading, 5)
                
                // X-axis labels and bars
                HStack(alignment: .bottom, spacing: 5) {
                    // Space for Y-axis labels
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 60)
                    
                    // Bars
                    HStack(alignment: .bottom, spacing: (geometry.size.width - 80) / CGFloat(getProjectedValues().count * 2)) {
                        ForEach(getProjectedValues(), id: \.year) { dataPoint in
                            VStack {
                                Rectangle()
                                    .fill(barColor)
                                    .frame(width: 30, height: CGFloat(dataPoint.value / maxValue) * (geometry.size.height - 30))
                                
                                Text("Year \(dataPoint.year)")
                                    .font(.caption)
                                    .foregroundColor(textColor)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .padding(.top, 10)
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

struct OpportunityCostRow: View {
    let opportunity: OpportunityCost
    let investment: Investment
    let timeframe: Int
    let formatCurrency: (Double) -> String
    
    var finalValue: Double {
        if let projectedReturn = opportunity.projectedReturns.first(where: { $0.year == timeframe }) {
            return projectedReturn.totalValue
        } else {
            // Fallback calculation if we don't have the exact projection
            let rate = investment.averageAnnualReturn / 100 / 12
            let months = Double(timeframe * 12)
            return opportunity.monthlyAmount * ((pow(1 + rate, months) - 1) / rate)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(getExpenseCategoryName())
                    .font(.headline)
                
                Spacer()
                
                Text(formatCurrency(opportunity.monthlyAmount))
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Monthly savings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(opportunity.monthlyAmount))
                        .font(.subheadline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Future value in \(timeframe) years")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(finalValue))
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            Divider()
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
    }
    
    private func getExpenseCategoryName() -> String {
        // Extract category name from the expenseId
        // Normally this would come from the expense details
        if let categoryString = ExpenseCategory(rawValue: opportunity.expenseId) {
            return categoryString.rawValue
        } else {
            return opportunity.expenseId
        }
    }
}

// Preview provider for SwiftUI canvas
struct InvestmentComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            InvestmentReturnChart(
                opportunityCosts: [
                    OpportunityCost(
                        expenseId: "Entertainment",
                        investmentId: "SPY",
                        monthlyAmount: 100,
                        yearlySavings: 1200,
                        years: 10
                    )
                ],
                selectedInvestment: Investment(
                    name: "S&P 500",
                    ticker: "SPY",
                    type: .index,
                    historicalReturns: [
                        YearlyReturn(year: 2023, returnPercentage: 24.23)
                    ],
                    riskLevel: .medium
                ),
                selectedTimeframe: 5
            )
            .frame(height: 250)
            .padding()
            
            OpportunityCostRow(
                opportunity: OpportunityCost(
                    expenseId: "Entertainment",
                    investmentId: "SPY",
                    monthlyAmount: 150,
                    yearlySavings: 1800,
                    years: 10
                ),
                investment: Investment(
                    name: "S&P 500",
                    ticker: "SPY",
                    type: .index,
                    historicalReturns: [
                        YearlyReturn(year: 2023, returnPercentage: 24.23)
                    ],
                    riskLevel: .medium
                ),
                timeframe: 5,
                formatCurrency: { amount in
                    let formatter = NumberFormatter()
                    formatter.numberStyle = .currency
                    formatter.currencyCode = "USD"
                    return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
                }
            )
            .padding()
        }
    }
}
