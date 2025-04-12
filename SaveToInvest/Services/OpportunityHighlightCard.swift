//
//  OpportunityHighlightCard.swift
//  SaveToInvest
//
//  Created by Kesong Lin on 4/2/25.
//


import SwiftUI
import Combine

struct OpportunityHighlightCard: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @EnvironmentObject private var expenseAnalyzer: ExpenseAnalyzer
    
    let opportunityCosts: [OpportunityCost]
    let getInvestmentName: (String) -> String
    let formatCurrency: (Double) -> String
    
    @State private var savingsPlan: SavingsAndInvestmentPlan?
    @State private var isLoading = false
    @State private var showRealTimeQuotes = false
    @State private var quoteData: [String: QuoteData] = [:]
    @State private var refreshTimer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header section with refresh button
            HStack {
                Text("Investment Potential")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    refreshInvestmentData()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
                .disabled(isLoading)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            // Monthly savings section
            if let topOpportunity = opportunityCosts.first {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Image(systemName: "arrow.up.forward")
                            .foregroundColor(.green)
                        
                        Text("Monthly savings")
                            .font(.subheadline)
                        
                        Text(formatCurrency(topOpportunity.monthlyAmount))
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    
                    Divider()
                    
                    // Future value projections
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("1 year")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let year1 = topOpportunity.projectedReturns.first {
                                Text(formatCurrency(year1.totalValue))
                                    .font(.headline)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("5 years")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let year5 = topOpportunity.projectedReturns.first(where: { $0.year == 5 }) {
                                Text(formatCurrency(year5.totalValue))
                                    .font(.headline)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("10 years")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let year10 = topOpportunity.projectedReturns.first(where: { $0.year == 10 }) {
                                Text(formatCurrency(year10.totalValue))
                                    .font(.headline)
                            }
                        }
                    }
                    
                    // Investment allocation recommendations
                    if let plan = savingsPlan, !plan.recommendedInvestments.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recommended allocation:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                            
                            HStack {
                                ForEach(plan.recommendedInvestments.prefix(3), id: \.investment.id) { recommended in
                                    investmentPill(
                                        name: recommended.investment.name,
                                        allocation: Int(recommended.allocationPercentage),
                                        ticker: recommended.investment.ticker
                                    )
                                    
                                    if recommended.investment.id != plan.recommendedInvestments.prefix(3).last?.investment.id {
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    
                    // Real-time quotes toggle
                    Button(action: {
                        showRealTimeQuotes.toggle()
                        if showRealTimeQuotes {
                            startQuoteUpdates()
                        } else {
                            stopQuoteUpdates()
                        }
                    }) {
                        HStack {
                            Image(systemName: showRealTimeQuotes ? "clock.fill" : "clock")
                                .font(.caption)
                            
                            Text(showRealTimeQuotes ? "Hide quotes" : "Show real-time quotes")
                                .font(.caption)
                        }
                        .padding(.vertical, 5)
                        .foregroundColor(.blue)
                    }
                    
                    // Real-time quotes display
                    if showRealTimeQuotes {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(quoteData.keys.sorted()), id: \.self) { ticker in
                                    if let quote = quoteData[ticker] {
                                        quoteCard(ticker: ticker, quote: quote)
                                    }
                                }
                                
                                if quoteData.isEmpty {
                                    ProgressView("Loading quotes...")
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .frame(height: 80)
                        .padding(.top, 5)
                    }
                }
            } else {
                // No data state
                VStack(spacing: 10) {
                    Text("Add non-essential expenses to see investment potential")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        // Action to add expense
                    }) {
                        Text("Add Expense")
                            .font(.caption)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onAppear {
            loadSavingsPlan()
        }
        .onDisappear {
            stopQuoteUpdates()
        }
    }
    
    // MARK: - Helper Views
    
    private func investmentPill(name: String, allocation: Int, ticker: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text(name)
                    .font(.caption)
                    .lineLimit(1)
                
                Text("\(allocation)%")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            if showRealTimeQuotes, let quote = quoteData[ticker], quote.changePercent != 0 {
                Text("\(quote.changePercent > 0 ? "+" : "")\(String(format: "%.2f", quote.changePercent))%")
                    .font(.system(size: 10))
                    .foregroundColor(quote.changePercent > 0 ? .green : .red)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(15)
    }
    
    private func quoteCard(ticker: String, quote: QuoteData) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ticker)
                .font(.caption)
                .fontWeight(.bold)
            
            Text("$\(String(format: "%.2f", quote.price))")
                .font(.caption)
            
            HStack(spacing: 2) {
                Image(systemName: quote.changePercent > 0 ? "arrow.up" : "arrow.down")
                    .font(.system(size: 8))
                
                Text("\(quote.changePercent > 0 ? "+" : "")\(String(format: "%.2f", quote.changePercent))%")
                    .font(.system(size: 10))
            }
            .foregroundColor(quote.changePercent > 0 ? .green : .red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    
    private func loadSavingsPlan() {
        // Generate savings plan once on load
        DispatchQueue.main.async {
            self.savingsPlan = self.viewModel.generateSavingsAndInvestmentPlan()
        }
    }
    
    private func refreshInvestmentData() {
        isLoading = true
        
        Task {
            await viewModel.refreshInvestmentData()
            
            // After refresh, update real-time quotes if they're showing
            if showRealTimeQuotes {
                await fetchRealTimeQuotes()
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    private func startQuoteUpdates() {
        // Initial fetch
        Task {
            await fetchRealTimeQuotes()
        }
        
        // Set up regular updates
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task {
                await fetchRealTimeQuotes()
            }
        }
    }
    
    private func stopQuoteUpdates() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func fetchRealTimeQuotes() async {
        // Determine which tickers to get quotes for
        var tickersToFetch = expenseAnalyzer.investments.map { $0.ticker }
        
        // Add any stocks from recommended investments not already included
        if let plan = savingsPlan {
            for recommended in plan.recommendedInvestments {
                if !tickersToFetch.contains(recommended.investment.ticker) {
                    tickersToFetch.append(recommended.investment.ticker)
                }
            }
        }
        
        // Fetch quotes for each ticker
        for ticker in tickersToFetch {
            if let quote = await viewModel.getRealTimeQuote(for: ticker) {
                DispatchQueue.main.async {
                    self.quoteData[ticker] = quote
                }
            }
        }
    }
}
