//
//  DetailedOpportunityView.swift
//  SaveToInvest
//
//  Created on 3/31/25.
//

import SwiftUI
import Charts


struct DetailedOpportunityView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var expenseAnalyzer: ExpenseAnalyzer
    
    
    
    // Parameters to customize the analysis
    @State private var selectedTimeframe: Int
    @State private var selectedInvestmentIndex: Int
    @State private var reinvestDividends: Bool = true
    @State private var monthlyContribution: Double
    @State private var initialInvestment: Double = 0
    
    // For comparison feature
    @State private var compareWithInflation: Bool = true
    @State private var inflationRate: Double = 3.0 // Default inflation assumption
    
    // Chart data state
    @State private var showDetailedBreakdown: Bool = false
    
    private var investments: [Investment] {
        return expenseAnalyzer.investments
    }
    
    private var opportunityCosts: [OpportunityCost] {
        return expenseAnalyzer.opportunityCosts
    }
    
    // Initialize with default values or passed values
    init(selectedTimeframe: Int = 10, selectedInvestmentIndex: Int = 0, monthlyContribution: Double? = nil) {
        self._selectedTimeframe = State(initialValue: selectedTimeframe)
        self._selectedInvestmentIndex = State(initialValue: selectedInvestmentIndex)
        
        // If no monthly contribution is provided, use the sum from opportunityCosts
        let defaultContribution = monthlyContribution ?? 0
        self._monthlyContribution = State(initialValue: defaultContribution)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Detailed Investment Analysis")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("See how your savings could grow over time")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom)
                
                // Investment Parameters
                VStack(alignment: .leading, spacing: 15) {
                    Text("Investment Parameters")
                        .font(.headline)
                    
                    // Investment Selection
                    if !investments.isEmpty {
                        Picker("Investment Vehicle", selection: $selectedInvestmentIndex) {
                            ForEach(0..<investments.count, id: \.self) { index in
                                HStack {
                                    Text(investments[index].name)
                                    Text("(\(String(format: "%.1f", investments[index].averageAnnualReturn))%)")
                                        .foregroundColor(.secondary)
                                }
                                .tag(index)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(.vertical, 5)
                    }
                    
                    // Initial Investment
                    HStack {
                        Text("Initial Investment")
                        Spacer()
                        TextField("Amount", value: $initialInvestment, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Monthly Contribution
                    HStack {
                        Text("Monthly Contribution")
                        Spacer()
                        TextField("Amount", value: $monthlyContribution, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Investment Duration
                    HStack {
                        Text("Investment Duration")
                        Spacer()
                        Picker("", selection: $selectedTimeframe) {
                            Text("1 Year").tag(1)
                            Text("5 Years").tag(5)
                            Text("10 Years").tag(10)
                            Text("20 Years").tag(20)
                            Text("30 Years").tag(30)
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 100)
                    }
                    
                    // Dividend Reinvestment
                    Toggle("Reinvest Dividends", isOn: $reinvestDividends)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // Investment Growth Chart
                VStack(alignment: .leading, spacing: 15) {
                    Text("Projected Growth Over Time")
                        .font(.headline)
                    
                    // Summary Statistics
                    HStack {
                        Spacer()
                        
                        VStack {
                            Text("Total Invested")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(initialInvestment + (monthlyContribution * Double(selectedTimeframe) * 12)))
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text("Final Value")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(calculateFinalValue()))
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text("Total Return")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            let totalReturn = calculateFinalValue() - (initialInvestment + (monthlyContribution * Double(selectedTimeframe) * 12))
                            Text(formatCurrency(totalReturn))
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical)
                    
                    // Simplified chart (not using actual Charts API for compatibility)
                    ZStack {
                        // Chart background
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 200)
                        
                        // Growth curve
                        Path { path in
                            let width: CGFloat = UIScreen.main.bounds.width - 60
                            let height: CGFloat = 180
                            
                            path.move(to: CGPoint(x: 0, y: height))
                            
                            for i in 0...100 {
                                let x = CGFloat(i) * width / 100
                                let normalized = Double(i) / 100.0
                                let powValue = pow(1 + getAnnualReturnRate() / 100 / 12, Double(selectedTimeframe * 12) * normalized)
                                let yValue = initialInvestment * powValue + monthlyContribution * ((powValue - 1) / (getAnnualReturnRate() / 100 / 12))
                                let maxPossibleValue = calculateFinalValue()
                                let y = height - CGFloat(yValue / maxPossibleValue) * height
                                
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        .stroke(Color.blue, lineWidth: 3)
                        
                        // Inflation comparison curve
                        if compareWithInflation {
                            Path { path in
                                let width: CGFloat = UIScreen.main.bounds.width - 60
                                let height: CGFloat = 180
                                
                                path.move(to: CGPoint(x: 0, y: height))
                                
                                for i in 0...100 {
                                    let x = CGFloat(i) * width / 100
                                    let normalized = Double(i) / 100.0
                                    
                                    // Simple inflation calculation
                                    let years = Double(selectedTimeframe) * normalized
                                    let inflationFactor = pow(1 + inflationRate / 100, years)
                                    let yValue = (initialInvestment + monthlyContribution * Double(selectedTimeframe) * 12 * normalized) * inflationFactor
                                    
                                    let maxPossibleValue = calculateFinalValue()
                                    let y = height - CGFloat(yValue / maxPossibleValue) * height
                                    
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            .stroke(Color.orange, lineWidth: 2)
                            .opacity(0.7)
                        }
                        
                        // Chart labels
                        VStack {
                            Spacer()
                            HStack {
                                Text("Year 0")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Year \(selectedTimeframe)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical)
                    
                    // Chart Legend
                    HStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                        Text("Investment Growth")
                            .font(.caption)
                        
                        if compareWithInflation {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 12, height: 12)
                            Text("Inflation-Adjusted Savings")
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        Toggle("Compare with Inflation", isOn: $compareWithInflation)
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // Year-by-Year Breakdown
                VStack(alignment: .leading, spacing: 15) {
                    Button(action: {
                        showDetailedBreakdown.toggle()
                    }) {
                        HStack {
                            Text("Year-by-Year Breakdown")
                                .font(.headline)
                            
                            Spacer()
                            
                            Image(systemName: showDetailedBreakdown ? "chevron.up" : "chevron.down")
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if showDetailedBreakdown {
                        VStack(spacing: 15) {
                            // Header row
                            HStack {
                                Text("Year")
                                    .font(.caption)
                                    .frame(width: 40, alignment: .leading)
                                
                                Text("Contributions")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                
                                Text("Interest")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                
                                Text("Balance")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding(.bottom, 5)
                            
                            // Generate year-by-year data
                            ForEach(0...min(selectedTimeframe, 10), id: \.self) { year in
                                HStack {
                                    Text("\(year)")
                                        .font(.footnote)
                                        .frame(width: 40, alignment: .leading)
                                    
                                    Text(formatCurrency(year == 0 ? initialInvestment : monthlyContribution * 12))
                                        .font(.footnote)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    
                                    let yearlyValues = calculateYearlyValues()
                                    let interestForYear = year == 0 ? 0 : yearlyValues[year].interest
                                    
                                    Text(formatCurrency(interestForYear))
                                        .font(.footnote)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    
                                    Text(formatCurrency(yearlyValues[year].balance))
                                        .font(.footnote)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                
                                if year < min(selectedTimeframe, 10) {
                                    Divider()
                                }
                            }
                            
                            // Show "View All" button if more years than we're showing
                            if selectedTimeframe > 10 {
                                Button(action: {
                                    // In a real app, navigate to full breakdown
                                }) {
                                    Text("View All \(selectedTimeframe) Years")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .padding(.top, 5)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // Comparison section
                VStack(alignment: .leading, spacing: 15) {
                    Text("How This Money Could Change Your Life")
                        .font(.headline)
                    
                    let finalValue = calculateFinalValue()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        ComparisonItem(
                            title: "Retirement Contribution",
                            description: "This amount could represent \(String(format: "%.1f", finalValue / 200000 * 100))% of a comfortable retirement fund."
                        )
                        
                        ComparisonItem(
                            title: "Education Fund",
                            description: "This could pay for \(String(format: "%.1f", finalValue / 25000)) years of university tuition."
                        )
                        
                        ComparisonItem(
                            title: "Home Purchase",
                            description: "This represents \(String(format: "%.1f", (finalValue / 300000) * 100))% of a down payment on an average home."
                        )
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // Share and Export Actions
                HStack {
                    Button(action: {
                        // Share functionality
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Analysis")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        // Save to PDF functionality
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.doc")
                            Text("Save as PDF")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(10)
                    }
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationBarTitle("Opportunity Analysis", displayMode: .inline)
        .onAppear {
            // Initialize monthly contribution from opportunity costs if not already set
            if monthlyContribution == 0 {
                let totalMonthlySavings = opportunityCosts.reduce(0) { $0 + $1.monthlyAmount }
                monthlyContribution = totalMonthlySavings
            }
        }
    }
    
    // Helper Components
    struct ComparisonItem: View {
        let title: String
        let description: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 5)
        }
    }
    
    // Helper Methods
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    private func getAnnualReturnRate() -> Double {
        if investments.isEmpty || selectedInvestmentIndex >= investments.count {
            return 7.0 // Default if no investment is selected
        }
        
        return investments[selectedInvestmentIndex].averageAnnualReturn
    }
    
    private func calculateFinalValue() -> Double {
        let rate = getAnnualReturnRate() / 100 / 12 // Monthly rate
        let months = Double(selectedTimeframe * 12)
        
        // Standard compound interest formula for recurring deposits
        let futureValueOfRecurring = monthlyContribution * ((pow(1 + rate, months) - 1) / rate)
        
        // Plus compound interest on initial investment
        let futureValueOfInitial = initialInvestment * pow(1 + rate, months)
        
        return futureValueOfRecurring + futureValueOfInitial
    }
    
    private struct YearlyValue {
        let year: Int
        let contributions: Double
        let interest: Double
        let balance: Double
    }
    
    private func calculateYearlyValues() -> [YearlyValue] {
        let rate = getAnnualReturnRate() / 100 / 12 // Monthly rate
        var yearlyValues: [YearlyValue] = []
        
        var runningBalance = initialInvestment
        var totalContributions = initialInvestment
        
        // Add initial year
        yearlyValues.append(YearlyValue(
            year: 0,
            contributions: initialInvestment,
            interest: 0,
            balance: initialInvestment
        ))
        
        for year in 1...selectedTimeframe {
            var yearlyInterest = 0.0
            
            // Calculate monthly compounding for the year
            for _ in 1...12 {
                let monthlyInterest = runningBalance * rate
                yearlyInterest += monthlyInterest
                
                runningBalance += monthlyInterest + monthlyContribution
                totalContributions += monthlyContribution
            }
            
            yearlyValues.append(YearlyValue(
                year: year,
                contributions: Double(year) * monthlyContribution * 12 + initialInvestment,
                interest: yearlyInterest,
                balance: runningBalance
            ))
        }
        
        return yearlyValues
    }
}

// Preview provider
struct DetailedOpportunityView_Previews: PreviewProvider {
    static var previews: some View {
        let mockFirebaseService = FirebaseService()
        let mockExpenseAnalyzer = ExpenseAnalyzer(firebaseService: mockFirebaseService)
        
        return DetailedOpportunityView(
            selectedTimeframe: 10,
            selectedInvestmentIndex: 0,
            monthlyContribution: 500
        )
        .environmentObject(mockExpenseAnalyzer)
    }
}
