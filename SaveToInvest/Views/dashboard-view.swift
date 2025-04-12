//
//  DashboardView.swift
//  SaveToInvest
//
//  Updated on 4/12/25.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @EnvironmentObject private var expenseAnalyzer: ExpenseAnalyzer

    @State private var showAddExpense = false
    @State private var showImportView = false
    @State private var isRefreshing = false
    @State private var specificSavings: [SpecificSaving] = []
    @State private var realTimeData: [String: QuoteData] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with welcome and actions
                dashboardHeader
                
                // Financial summary section
                financialSummarySection
                
                // Expense overview section
                expenseOverviewSection
                
                // Savings opportunity section
                savingsOpportunitySection
                
                // Investment highlights section
                investmentHighlightsSection
            }
            .padding(.vertical)
            .overlay(
                Group {
                    if isRefreshing {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        ProgressView("Refreshing data...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                    }
                }
            )
        }
        .navigationTitle("Dashboard")
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showImportView) {
            ImportDataView()
                .environmentObject(viewModel)
        }
        .onAppear {
            // Load data on appear
            loadDashboardData()
        }
        .refreshable {
            await refreshDashboardData()
        }
    }
    
    // MARK: - View Components
    
    private var dashboardHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome, \(viewModel.firebaseService.currentUser?.displayName ?? "User")")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Let's analyze your financial progress")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                showImportView = true
            }) {
                Image(systemName: "arrow.down.doc")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 4)

            Button(action: {
                showAddExpense = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
    }
    
    private var financialSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Financial Summary")
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 15) {
                // Total spending card
                summaryCard(
                    title: "Total Spending",
                    value: expenseAnalyzer.monthlySummary.reduce(0) { $0 + $1.totalAmount },
                    subtitle: "This month",
                    icon: "dollarsign.circle.fill",
                    color: .blue
                )
                
                // Non-essential spending card
                summaryCard(
                    title: "Non-essential",
                    value: expenseAnalyzer.monthlySummary.filter { !$0.isNecessary }.reduce(0) { $0 + $1.totalAmount },
                    subtitle: "This month",
                    icon: "cart.fill",
                    color: .orange
                )
            }
            .padding(.horizontal)
            
            HStack(spacing: 15) {
                // Savings potential card
                summaryCard(
                    title: "Savings Potential",
                    value: expenseAnalyzer.opportunityCosts.reduce(0) { $0 + $1.monthlyAmount * 0.5 },
                    subtitle: "Per month",
                    icon: "arrow.up.circle.fill",
                    color: .green
                )
                
                // Investment growth card (simplified)
                let growth = calculateInvestmentGrowth()
                summaryCard(
                    title: "Investment Growth",
                    value: growth.absolute,
                    subtitle: "\(String(format: "%.1f", growth.percentage))% increase",
                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
    }
    
    private func summaryCard(title: String, value: Double, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Text("$\(String(format: "%.2f", value))")
                .font(.title3)
                .fontWeight(.bold)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var expenseOverviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Expense Overview")
                .font(.headline)
                .padding(.horizontal)

            if expenseAnalyzer.monthlySummary.isEmpty {
                emptyStateView(message: "No expense data available")
            } else {
                ExpenseSummaryCard(categorySummaries: expenseAnalyzer.monthlySummary)
            }
        }
    }
    
    private var savingsOpportunitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Savings Opportunities")
                .font(.headline)
                .padding(.horizontal)

            if specificSavings.isEmpty {
                emptyStateView(message: "No specific savings opportunities identified")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(specificSavings.prefix(3), id: \.name) { saving in
                            ExpenseBreakdownCard(
                                expenseTitle: saving.name,
                                monthlyAmount: saving.currentMonthlyCost
                            ) { percentage in
                                // Handle selection - could log to analytics or add to a plan
                                print("Selected to reduce \(saving.name) by \(percentage)%")
                            }
                            .frame(width: UIScreen.main.bounds.width * 0.85)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var investmentHighlightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Investment Opportunities")
                .font(.headline)
                .padding(.horizontal)
            
            if expenseAnalyzer.opportunityCosts.isEmpty {
                emptyStateView(message: "Add expenses to view investment opportunities")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        OpportunityHighlightCard(
                            opportunityCosts: expenseAnalyzer.opportunityCosts,
                            getInvestmentName: expenseAnalyzer.getInvestmentName,
                            formatCurrency: expenseAnalyzer.formatCurrency
                        )
                        .frame(width: UIScreen.main.bounds.width * 0.9)
                        .padding(.leading)
                        
                        Spacer(minLength: 20)
                    }
                }
                
                // Real-time market highlights
                VStack(alignment: .leading, spacing: 8) {
                    Text("Market Highlights")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    
                    if realTimeData.isEmpty {
                        HStack {
                            Spacer()
                            Text("Loading market data...")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(Array(realTimeData.keys.sorted()), id: \.self) { ticker in
                                    if let quote = realTimeData[ticker] {
                                        marketQuoteCard(ticker: ticker, quote: quote)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Button(action: {
                    NotificationCenter.default.post(name: Notification.Name("JumpToOpportunityView"), object: nil)
                }) {
                    HStack {
                        Text("See all opportunities")
                            .font(.subheadline)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func marketQuoteCard(ticker: String, quote: QuoteData) -> some View {
        VStack(alignment: .center, spacing: 5) {
            Text(ticker)
                .font(.subheadline)
                .fontWeight(.bold)
            
            Text("$\(String(format: "%.2f", quote.price))")
                .font(.headline)
            
            HStack(spacing: 3) {
                Image(systemName: quote.changePercent >= 0 ? "arrow.up" : "arrow.down")
                    .font(.caption)
                
                Text("\(String(format: "%.2f", quote.changePercent))%")
                    .font(.caption)
            }
            .foregroundColor(quote.changePercent >= 0 ? .green : .red)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(quote.changePercent >= 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            .cornerRadius(10)
        }
        .padding()
        .frame(width: 120)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func emptyStateView(message: String) -> some View {
        HStack {
            Spacer()
            
            VStack(spacing: 10) {
                Image(systemName: "tray")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.secondary)
                
                Text(message)
                    .foregroundColor(.secondary)
            }
            .frame(height: 100)
            
            Spacer()
        }
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // MARK: - Helper Methods
    
    private func loadDashboardData() {
        // Load specific savings options
        specificSavings = viewModel.calculateSpecificSavings()
        
        // Load real-time market data
        loadMarketData()
    }
    
    private func refreshDashboardData() async {
        isRefreshing = true
        
        // Refresh investment data
        await viewModel.refreshInvestmentData()
        
        // Refresh specific savings
        DispatchQueue.main.async {
            self.specificSavings = self.viewModel.calculateSpecificSavings()
        }
        
        // Refresh market data
        loadMarketData()
        
        DispatchQueue.main.async {
            self.isRefreshing = false
        }
    }
    
    private func loadMarketData() {
        Task {
            // Get quotes for major indexes and stocks
            let keyTickers = ["SPY", "QQQ", "VTI", "BND"]
            
            for ticker in keyTickers {
                if let quote = await viewModel.getRealTimeQuote(for: ticker) {
                    DispatchQueue.main.async {
                        self.realTimeData[ticker] = quote
                    }
                }
            }
        }
    }
    
    private func calculateInvestmentGrowth() -> (absolute: Double, percentage: Double) {
        // For this demo, we'll use a simplified calculation
        // In a real app, this would use actual investment tracking data
        
        let opportunityCosts = expenseAnalyzer.opportunityCosts
        if opportunityCosts.isEmpty {
            return (0, 0)
        }
        
        let totalMonthly = opportunityCosts.reduce(0) { $0 + $1.monthlyAmount }
        let totalYearly = totalMonthly * 12
        
        // Assuming a portion is already being invested with average market returns
        let investedAmount = totalYearly * 0.3 // Assume 30% of potential savings is already being invested
        let growthRate = 0.07 // 7% annual return
        let growthAmount = investedAmount * growthRate
        
        return (growthAmount, growthRate * 100)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environmentObject(MainViewModel())
            .environmentObject(ExpenseAnalyzer(firebaseService: FirebaseService()))
    }
}
