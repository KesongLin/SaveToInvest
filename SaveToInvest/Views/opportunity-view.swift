import SwiftUI

struct OpportunityView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @EnvironmentObject private var expenseAnalyzer: ExpenseAnalyzer
    
    @State private var selectedTimeframe: Int = 5 // Default showing 5 years
    @State private var selectedInvestmentIndex: Int = 0
    @State private var showDetailedAnalysis: Bool = false
    
    private var investments: [Investment] {
        return expenseAnalyzer.investments
    }
    
    private var totalMonthlySavings: Double {
        return expenseAnalyzer.opportunityCosts.reduce(0) { $0 + $1.monthlyAmount }
    }
    
    private var totalYearlySavings: Double {
        return totalMonthlySavings * 12
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Total savings opportunity card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Monthly savings opportunity")
                            .font(.headline)
                        
                        HStack(alignment: .firstTextBaseline) {
                            Text(formatCurrency(totalMonthlySavings))
                                .font(.system(size: 36, weight: .bold))
                            
                            Text("/ month")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Yearly savings: \(formatCurrency(totalYearlySavings))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Divider
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Investment selection
                        VStack(alignment: .leading, spacing: 5) {
                            Text("If that money was invested in:")
                                .font(.subheadline)
                            
                            if !investments.isEmpty {
                                Picker("Investment Options", selection: $selectedInvestmentIndex) {
                                    ForEach(0..<investments.count, id: \.self) { index in
                                        Text(investments[index].name).tag(index)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .padding(.vertical, 5)
                            }
                            
                            Text("Investment timeframe:")
                                .font(.subheadline)
                                .padding(.top, 5)
                            
                            Picker("Investment Timeframe", selection: $selectedTimeframe) {
                                Text("1 year").tag(1)
                                Text("5 years").tag(5)
                                Text("10 years").tag(10)
                                Text("20 years").tag(20)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                    
                    // Investment return projection
                    if !expenseAnalyzer.opportunityCosts.isEmpty && !investments.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Return on investment projections")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            InvestmentReturnChart(
                                opportunityCosts: expenseAnalyzer.opportunityCosts,
                                selectedInvestment: investments[selectedInvestmentIndex],
                                selectedTimeframe: selectedTimeframe
                            )
                            .frame(height: 250)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Detailed opportunity costs list
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Opportunity cost of non-essential expenses")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if expenseAnalyzer.opportunityCosts.isEmpty {
                            Text("No data available on non-essential expenses")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .padding(.horizontal)
                        } else {
                            ForEach(expenseAnalyzer.opportunityCosts) { opportunity in
                                OpportunityCostRow(
                                    opportunity: opportunity,
                                    investment: investments[selectedInvestmentIndex],
                                    timeframe: selectedTimeframe,
                                    formatCurrency: formatCurrency
                                )
                            }
                        }
                    }
                    
                    // Investment information
                    VStack(alignment: .leading, spacing: 5) {
                        if !investments.isEmpty {
                            Text("About \(investments[selectedInvestmentIndex].name)")
                                .font(.headline)
                            
                            Text("Historical average annual return: \(String(format: "%.2f", investments[selectedInvestmentIndex].averageAnnualReturn))%")
                                .font(.subheadline)
                            
                            Text("Risk level: \(investments[selectedInvestmentIndex].riskLevel.rawValue)")
                                .font(.subheadline)
                            
                            Text("Past performance is not indicative of future results. Investment involves risk.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 5)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                    
                    // Button to see detailed analysis
                    // In opportunity-view.swift, replace the sheet presentation with:
                    Button(action: {
                        showDetailedAnalysis = true
                    }) {
                        Text("View detailed opportunity analysis")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Investment Opportunities")
            // Attach the sheet modifier here on the outer container
            .sheet(isPresented: $showDetailedAnalysis) {
                DetailedOpportunityView(
                    selectedTimeframe: selectedTimeframe,
                    selectedInvestmentIndex: selectedInvestmentIndex,
                    monthlyContribution: totalMonthlySavings
                )
                .environmentObject(expenseAnalyzer)
                .environmentObject(viewModel)
            }
        }
    }
        
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

