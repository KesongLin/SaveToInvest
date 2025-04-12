//
//  OpportunityView.swift
//  SaveToInvest
//
//  Updated on 4/12/25.
//

import SwiftUI
import Combine

struct OpportunityView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @EnvironmentObject private var expenseAnalyzer: ExpenseAnalyzer
    
    @State private var selectedTimeframe: Int = 5 // Default showing 5 years
    @State private var selectedInvestmentIndex: Int = 0
    @State private var showDetailedAnalysis: Bool = false
    @State private var selectedView: OpportunityViewTab = .overview
    @State private var savingsPlan: SavingsAndInvestmentPlan?
    @State private var isRefreshing = false
    @State private var lastRefreshed: Date?
    @State private var realtimeQuotes: [String: QuoteData] = [:]
    
    private enum OpportunityViewTab {
        case overview
        case insights
        case comparison
    }
    
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
            VStack(spacing: 0) {
                // Tab selector
                segmentedTabSelector
                
                // Main content based on selected tab
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedView {
                        case .overview:
                            opportunityOverviewContent
                        case .insights:
                            SavingsInsightsView()
                                .environmentObject(viewModel)
                                .environmentObject(expenseAnalyzer)
                        case .comparison:
                            investmentComparisonContent
                        }
                    }
                    .padding(.vertical)
                }
                
                // Info about last refreshed time
                if let refreshDate = lastRefreshed, !isRefreshing {
                    HStack {
                        Spacer()
                        
                        Text("Last updated: \(timeAgoString(from: refreshDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 5)
                }
            }
            .navigationTitle("Investment Opportunities")
            .navigationBarItems(
                trailing: HStack {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    
                    Button(action: refreshData) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                }
            )
            .onAppear {
                loadData()
                // Get real-time quotes
                fetchRealtimeQuotes()
            }
            .onDisappear {
                // Clean up any resources if needed
            }
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
    
    // MARK: - View Components
    
    private var segmentedTabSelector: some View {
        Picker("View", selection: $selectedView) {
            Text("Overview").tag(OpportunityViewTab.overview)
            Text("Insights").tag(OpportunityViewTab.insights)
            Text("Compare").tag(OpportunityViewTab.comparison)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    private var opportunityOverviewContent: some View {
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
                                HStack {
                                    Text(investments[index].name)
                                    if let quote = realtimeQuotes[investments[index].ticker] {
                                        Text("(\(String(format: "%.1f", quote.changePercent))%)")
                                            .foregroundColor(quote.changePercent >= 0 ? .green : .red)
                                    }
                                }.tag(index)
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
            
            // Daily habit savings opportunities
            DailyHabitSavingsCard()
                .padding(.horizontal)
            
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
            
            // Investment information with real-time data
            VStack(alignment: .leading, spacing: 10) {
                if !investments.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("About \(investments[selectedInvestmentIndex].name)")
                                .font(.headline)
                            
                            HStack {
                                if let quote = realtimeQuotes[investments[selectedInvestmentIndex].ticker] {
                                    Text("Current Price: $\(String(format: "%.2f", quote.price))")
                                        .font(.subheadline)
                                    
                                    Text("\(quote.changePercent >= 0 ? "+" : "")\(String(format: "%.2f", quote.changePercent))%")
                                        .font(.subheadline)
                                        .foregroundColor(quote.changePercent >= 0 ? .green : .red)
                                        .padding(.horizontal, 5)
                                        .background(quote.changePercent >= 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                        .cornerRadius(5)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Quality indicator
                        VStack(alignment: .center) {
                            Text(investments[selectedInvestmentIndex].investmentQuality.rawValue)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(qualityColor(investments[selectedInvestmentIndex].investmentQuality))
                                .cornerRadius(5)
                            
                            Text("Quality")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Annual Return: \(String(format: "%.2f", investments[selectedInvestmentIndex].annualizedReturn))%")
                                .font(.subheadline)
                            
                            Text("Risk Level: \(investments[selectedInvestmentIndex].riskLevel.rawValue)")
                                .font(.subheadline)
                                .foregroundColor(riskColor(investments[selectedInvestmentIndex].riskLevel))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 5) {
                            Text("Volatility: \(String(format: "%.1f", investments[selectedInvestmentIndex].volatility))%")
                                .font(.subheadline)
                            
                            Text("Sharpe Ratio: \(String(format: "%.2f", investments[selectedInvestmentIndex].sharpeRatio))")
                                .font(.subheadline)
                        }
                    }
                    
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
    }
    
    private var investmentComparisonContent: some View {
        VStack(spacing: 20) {
            // Comparison header
            Text("Compare Investments")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            // Monthly savings input
            VStack(alignment: .leading, spacing: 5) {
                Text("Your monthly savings: \(formatCurrency(totalMonthlySavings))")
                    .font(.subheadline)
                
                // Timeframe selector
                Picker("Timeframe", selection: $selectedTimeframe) {
                    Text("1 Year").tag(1)
                    Text("5 Years").tag(5)
                    Text("10 Years").tag(10)
                    Text("20 Years").tag(20)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.top, 5)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Investment comparison cards
            if !investments.isEmpty {
                let sortedInvestments = investments.sorted { $0.annualizedReturn > $1.annualizedReturn }
                
                ForEach(sortedInvestments.prefix(5), id: \.id) { investment in
                    investmentComparisonCard(investment: investment)
                }
            } else {
                Text("No investment data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            
            // Risk vs. Return chart (simplified version)
            VStack(alignment: .leading, spacing: 10) {
                Text("Risk vs. Return")
                    .font(.headline)
                
                GeometryReader { geometry in
                    ZStack {
                        // Axes
                        Path { path in
                            // X-axis
                            path.move(to: CGPoint(x: 40, y: geometry.size.height - 40))
                            path.addLine(to: CGPoint(x: geometry.size.width - 20, y: geometry.size.height - 40))
                            
                            // Y-axis
                            path.move(to: CGPoint(x: 40, y: geometry.size.height - 40))
                            path.addLine(to: CGPoint(x: 40, y: 20))
                        }
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        
                        // Axis labels
                        Text("Risk (Volatility)")
                            .font(.caption)
                            .position(x: geometry.size.width / 2, y: geometry.size.height - 15)
                        
                        Text("Return")
                            .font(.caption)
                            .rotationEffect(Angle(degrees: -90))
                            .position(x: 15, y: geometry.size.height / 2)
                        
                        // Plot points for investments
                        ForEach(investments) { investment in
                            // Calculate x-y position based on risk and return
                            let maxVolatility = investments.map { $0.volatility }.max() ?? 30.0
                            let maxReturn = investments.map { $0.annualizedReturn }.max() ?? 20.0
                            
                            let xPos = 40 + (geometry.size.width - 60) * CGFloat(investment.volatility / maxVolatility)
                            let yPos = (geometry.size.height - 40) - (geometry.size.height - 60) * CGFloat(investment.annualizedReturn / maxReturn)
                            
                            ZStack {
                                // Investment point
                                Circle()
                                    .fill(riskColor(investment.riskLevel))
                                    .frame(width: 12, height: 12)
                                
                                // Tooltip on hover (simplified)
                                Text(investment.ticker)
                                    .font(.system(size: 8))
                                    .padding(4)
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(4)
                                    .offset(y: -15)
                            }
                            .position(x: xPos, y: yPos)
                        }
                    }
                }
                .frame(height: 200)
                .padding()
                .background(Color(.systemBackground))
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
    
    private func investmentComparisonCard(investment: Investment) -> some View {
        // Calculate future value for this investment
        let rate = investment.annualizedReturn / 100 / 12 // Monthly rate
        let months = Double(selectedTimeframe * 12)
        let futureValue = totalMonthlySavings * ((pow(1 + rate, months) - 1) / rate)
        let totalContributions = totalMonthlySavings * months
        let interestEarned = futureValue - totalContributions
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                // Ticker and name
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(investment.ticker)
                            .font(.headline)
                        
                        if let quote = realtimeQuotes[investment.ticker] {
                            HStack(spacing: 2) {
                                Image(systemName: quote.changePercent >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.caption)
                                
                                Text("\(String(format: "%.2f", quote.changePercent))%")
                                    .font(.caption)
                            }
                            .foregroundColor(quote.changePercent >= 0 ? .green : .red)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(quote.changePercent >= 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            .cornerRadius(5)
                        }
                    }
                    
                    Text(investment.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Return and risk
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(String(format: "%.2f", investment.annualizedReturn))% return")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    
                    Text("\(investment.riskLevel.rawValue) risk")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Projection values
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Future Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(futureValue))
                        .font(.headline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Interest Earned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(interestEarned))
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
            
            // Growth bar
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 10)
                    .cornerRadius(5)
                
                // Contributions
                Rectangle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: totalContributions > 0 ? CGFloat(totalContributions / futureValue) * UIScreen.main.bounds.width * 0.8 : 0, height: 10)
                
                // Interest
                Rectangle()
                    .fill(Color.green)
                    .frame(width: interestEarned > 0 ? CGFloat(interestEarned / futureValue) * UIScreen.main.bounds.width * 0.8 : 0, height: 10)
                    .offset(x: totalContributions > 0 ? CGFloat(totalContributions / futureValue) * UIScreen.main.bounds.width * 0.8 : 0)
            }
            .cornerRadius(5)
            .frame(height: 10)
            
            // Growth legend
            HStack {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: 10, height: 10)
                        .cornerRadius(2)
                    
                    Text("Contributions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .cornerRadius(2)
                    
                    Text("Interest")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    // MARK: - Helper Methods
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    private func loadData() {
        // Generate savings plan
        DispatchQueue.main.async {
            self.savingsPlan = self.viewModel.generateSavingsAndInvestmentPlan()
        }
        
        // Set the last refreshed time
        if let refreshDate = InvestmentDataManager.shared.lastRefreshDate {
            self.lastRefreshed = refreshDate
        }
    }
    
    private func refreshData() {
        isRefreshing = true
        
        Task {
            await viewModel.refreshInvestmentData()
            fetchRealtimeQuotes()
            
            DispatchQueue.main.async {
                self.isRefreshing = false
                self.lastRefreshed = Date()
            }
        }
    }
    
    private func fetchRealtimeQuotes() {
        Task {
            // Fetch quotes for all investments
            for investment in investments {
                if let quote = await viewModel.getRealTimeQuote(for: investment.ticker) {
                    DispatchQueue.main.async {
                        self.realtimeQuotes[investment.ticker] = quote
                    }
                }
            }
        }
    }
    
    private func qualityColor(_ quality: InvestmentQuality) -> Color {
        switch quality {
        case .poor:
            return .red
        case .belowAverage:
            return .orange
        case .average:
            return .yellow
        case .good:
            return .green
        case .excellent:
            return .blue
        }
    }
    
    private func riskColor(_ riskLevel: RiskLevel) -> Color {
        switch riskLevel {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate time components
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            return "\(day) day\(day == 1 ? "" : "s") ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour) hour\(hour == 1 ? "" : "s") ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute) minute\(minute == 1 ? "" : "s") ago"
        } else {
            return "Just now"
        }
    }
}

struct OpportunityView_Previews: PreviewProvider {
    static var previews: some View {
        OpportunityView()
            .environmentObject(MainViewModel())
            .environmentObject(ExpenseAnalyzer(firebaseService: FirebaseService()))
    }
}
