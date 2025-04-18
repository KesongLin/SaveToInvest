//
//  InvestmentDataManager.swift
//  SaveToInvest
//
//  Created by Kesong Lin on 4/2/25.
//

import Foundation
import FirebaseFirestore
import Combine

class InvestmentDataManager {
    // Change to lazy for deferred initialization
    static var shared = InvestmentDataManager()
    
    // Default tickers to track if user hasn't set any
    private let defaultTickers = [
        "SPY",    // S&P 500
        "QQQ",    // NASDAQ-100
        "BND",    // Total Bond Market
        "VTI",    // Vanguard Total Stock Market ETF
        "AAPL",   // Apple
        "MSFT",   // Microsoft
        "AMZN",   // Amazon
        "GOOGL",  // Alphabet (Google)
        "VNQ",    // Vanguard Real Estate ETF
        "VWO"     // Vanguard Emerging Markets ETF
    ]
    
    // Published properties for UI updates
    @Published var investments: [Investment] = []
    @Published var isRefreshing: Bool = false
    @Published var lastRefreshDate: Date?
    
    // Maps ETF tickers to their descriptive names and types
    private let tickerMetadata: [String: (name: String, type: InvestmentType)] = [
        "SPY": ("S&P 500", .index),
        "QQQ": ("NASDAQ-100", .index),
        "BND": ("Total Bond Market", .bond),
        "VTI": ("Total US Stock Market", .etf),
        "AAPL": ("Apple Inc.", .stock),
        "MSFT": ("Microsoft Corp.", .stock),
        "AMZN": ("Amazon.com Inc.", .stock),
        "GOOGL": ("Alphabet Inc.", .stock),
        "VNQ": ("US Real Estate", .etf),
        "VWO": ("Emerging Markets", .etf),
        "VXUS": ("Total International Stock", .etf),
        "VYM": ("High Dividend Yield", .etf),
        "DIA": ("Dow Jones Industrial Average", .index),
        "IWM": ("Russell 2000 Small Cap", .index),
        "GLD": ("Gold", .etf),
        "SLV": ("Silver", .etf),
        "TLT": ("20+ Year Treasury Bonds", .bond),
        "LQD": ("Corporate Bonds", .bond)
    ]
    
    private var cancellables = Set<AnyCancellable>()
    
    // CHANGE: Use optional for deferred initialization
    private var firebaseService: FirebaseService?
    
    private init() {
        // Only load cached investments in init
        // Don't access Firestore here
        loadCachedInvestments()
    }
    
    // ADDED: Method to initialize with shared Firebase service
    func initialize(with service: FirebaseService) {
        self.firebaseService = service
        
        // Optional: now that we have Firebase, we could load from there
        if let userId = service.currentUser?.id {
            loadInvestmentsFromFirebase(userId: userId)
        }
    }
    
    // Refresh all investment data
    func refreshInvestments() async {
        // Make sure we're not already refreshing
        if isRefreshing {
            return
        }
        
        // Set refreshing flag
        DispatchQueue.main.async {
            self.isRefreshing = true
        }
        
        // Determine which tickers to refresh
        let tickersToRefresh = investments.isEmpty ?
            defaultTickers :
            investments.map { $0.ticker }
        
        // Refresh the data from the API
        let stockDataMap = await StockAPIService.shared.refreshAllInvestments(tickers: tickersToRefresh)
        
        // Update or create investment objects
        var updatedInvestments: [Investment] = []
        
        for ticker in tickersToRefresh {
            if let stockData = stockDataMap[ticker] {
                // If we found data, update the investment
                let metadata = tickerMetadata[ticker] ?? (name: ticker, type: .stock)
                
                // Determine risk level based on volatility
                let riskLevel: RiskLevel
                if stockData.volatility < 15 {
                    riskLevel = .low
                } else if stockData.volatility < 25 {
                    riskLevel = .medium
                } else {
                    riskLevel = .high
                }
                
                // Create or update the investment
                let investment = Investment(
                    id: ticker,
                    name: metadata.name,
                    ticker: ticker,
                    type: metadata.type,
                    historicalReturns: stockData.yearlyReturns,
                    riskLevel: riskLevel,
                    annualizedReturn: stockData.annualizedReturn,
                    volatility: stockData.volatility,
                    sharpeRatio: stockData.sharpeRatio
                )
                
                updatedInvestments.append(investment)
            } else {
                // If API call failed, use existing data if available
                if let existingInvestment = investments.first(where: { $0.ticker == ticker }) {
                    updatedInvestments.append(existingInvestment)
                } else if let defaultInvestment = Investment.defaultOptions.first(where: { $0.ticker == ticker }) {
                    // Use default data as fallback
                    updatedInvestments.append(defaultInvestment)
                }
            }
        }
        
        // Update published property
        DispatchQueue.main.async {
            self.investments = updatedInvestments
            self.isRefreshing = false
            self.lastRefreshDate = Date()
            
            // Cache the updated investments
            self.cacheInvestments()
        }
        
        // Save to Firebase if a user is logged in and service exists
        if let userId = firebaseService?.currentUser?.id {
            saveInvestmentsToFirebase(investments: updatedInvestments, userId: userId)
        }
    }
    
    // ADDED: Load investments from Firebase
    private func loadInvestmentsFromFirebase(userId: String) {
        // Skip if no Firebase service
        guard let db = firebaseService?.db else { return }
        
        db.collection("investments")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error getting investments: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let decoder = JSONDecoder()
                
                var loadedInvestments: [Investment] = []
                
                for document in documents {
                    if let jsonData = document.data()["data"] as? String,
                       let data = jsonData.data(using: .utf8) {
                        do {
                            let investment = try decoder.decode(Investment.self, from: data)
                            loadedInvestments.append(investment)
                        } catch {
                            print("Error decoding investment: \(error)")
                        }
                    }
                }
                
                if !loadedInvestments.isEmpty {
                    DispatchQueue.main.async {
                        self?.investments = loadedInvestments
                    }
                }
            }
    }
    
    // UPDATED: Save investments to Firebase
    private func saveInvestmentsToFirebase(investments: [Investment], userId: String) {
        // Skip if no Firebase service
        guard let db = firebaseService?.db else { return }
        
        let encoder = JSONEncoder()
        
        for investment in investments {
            do {
                let encodedData = try encoder.encode(investment)
                if let jsonString = String(data: encodedData, encoding: .utf8) {
                    db.collection("investments")
                        .document(investment.id)
                        .setData(["data": jsonString, "updatedAt": FieldValue.serverTimestamp()])
                }
            } catch {
                print("Error encoding investment: \(error)")
            }
        }
    }
    
    // Load cached investments from UserDefaults
    private func loadCachedInvestments() {
        if let cachedData = UserDefaults.standard.data(forKey: "cachedInvestments") {
            do {
                let decoder = JSONDecoder()
                let cachedInvestments = try decoder.decode([Investment].self, from: cachedData)
                self.investments = cachedInvestments
                
                // Also load the last refresh date
                if let timestamp = UserDefaults.standard.object(forKey: "lastInvestmentRefresh") as? Date {
                    self.lastRefreshDate = timestamp
                }
            } catch {
                print("Error decoding cached investments: \(error)")
                // If we can't load from cache, use default options
                self.investments = Investment.defaultOptions
            }
        } else {
            // Use default options if no cache exists
            self.investments = Investment.defaultOptions
        }
    }
    
    // Cache investments to UserDefaults
    private func cacheInvestments() {
        do {
            let encoder = JSONEncoder()
            let encodedData = try encoder.encode(investments)
            UserDefaults.standard.set(encodedData, forKey: "cachedInvestments")
            
            // Also save the refresh timestamp
            UserDefaults.standard.set(lastRefreshDate, forKey: "lastInvestmentRefresh")
        } catch {
            print("Error caching investments: \(error)")
        }
    }
    
    // Function to get real-time quote for a specific ticker
    func getRealTimeQuote(for ticker: String) async -> QuoteData? {
        do {
            return try await StockAPIService.shared.getRealTimeQuote(for: ticker)
        } catch {
            print("Error getting real-time quote for \(ticker): \(error)")
            return nil
        }
    }
    
    // Get available stock tickers for user selection
    func getAvailableStocks() -> [String] {
        return Array(tickerMetadata.keys).sorted()
    }
    
    // Get metadata for a specific ticker
    func getMetadata(for ticker: String) -> (name: String, type: InvestmentType)? {
        return tickerMetadata[ticker]
    }
}
