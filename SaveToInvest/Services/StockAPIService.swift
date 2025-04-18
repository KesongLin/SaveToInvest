//
//  StockAPIService.swift
//  SaveToInvest
//
//  Created by Kesong Lin on 4/2/25.
//

import Foundation
import Combine

class StockAPIService {
    // Singleton pattern
    static let shared = StockAPIService()
    
    // Alpha Vantage API key - replace with your own
    private let apiKey = "L2TI9STV8QWJ9WZN"
    private let baseURL = "https://www.alphavantage.co/query"
    
    // Cache to prevent excessive API calls
    private var cachedStockData: [String: StockData] = [:]
    private var lastUpdateTime: [String: Date] = [:]
    private let cacheExpiryTime: TimeInterval = 3600 // Cache expires after 1 hour
    
    // Rate limiting properties
    private var lastAPICallTime: Date?
    private let minTimeBetweenCalls: TimeInterval = 12 // seconds between API calls
    private var quoteCache: [String: (data: QuoteData, timestamp: Date)] = [:]
    
    private init() {}
    
    // Get stock data asynchronously
    func getStockData(for ticker: String) async throws -> StockData {
        // Check cache first
        if let cachedData = cachedStockData[ticker],
           let lastUpdate = lastUpdateTime[ticker],
           Date().timeIntervalSince(lastUpdate) < cacheExpiryTime {
            return cachedData
        }
        
        // Apply rate limiting
        if let lastCall = lastAPICallTime, Date().timeIntervalSince(lastCall) < minTimeBetweenCalls {
            let waitTime = minTimeBetweenCalls - Date().timeIntervalSince(lastCall)
            if waitTime > 0 {
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        
        // Update last API call time
        lastAPICallTime = Date()
        
        // Construct URL for time series data
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "function", value: "TIME_SERIES_MONTHLY"),
            URLQueryItem(name: "symbol", value: ticker),
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "outputsize", value: "compact")
        ]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        // Make API request
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // Parse the response
        let stockData = try parseTimeSeriesData(data: data, ticker: ticker)
        
        // Cache the result
        cachedStockData[ticker] = stockData
        lastUpdateTime[ticker] = Date()
        
        return stockData
    }
    
    // Function to get real-time quote
    func getRealTimeQuote(for ticker: String) async -> QuoteData? {
        // Check cache first (valid for 5 minutes)
        if let cached = quoteCache[ticker],
           Date().timeIntervalSince(cached.timestamp) < 300 {
            return cached.data
        }
        
        // Apply rate limiting
        if let lastCall = lastAPICallTime, Date().timeIntervalSince(lastCall) < minTimeBetweenCalls {
            let waitTime = minTimeBetweenCalls - Date().timeIntervalSince(lastCall)
            if waitTime > 0 {
                do {
                    try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                } catch {
                    print("Sleep interrupted: \(error)")
                }
            }
        }
        
        // Update last API call time
        lastAPICallTime = Date()
        
        // Try to get data with error handling
        do {
            var components = URLComponents(string: baseURL)
            components?.queryItems = [
                URLQueryItem(name: "function", value: "GLOBAL_QUOTE"),
                URLQueryItem(name: "symbol", value: ticker),
                URLQueryItem(name: "apikey", value: apiKey)
            ]
            
            guard let url = components?.url else {
                return fallbackQuoteData(for: ticker)
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return fallbackQuoteData(for: ticker)
            }
            
            if httpResponse.statusCode == 429 {
                print("Rate limited by Alpha Vantage API")
                return fallbackQuoteData(for: ticker)
            }
            
            if httpResponse.statusCode != 200 {
                print("HTTP error: \(httpResponse.statusCode)")
                return fallbackQuoteData(for: ticker)
            }
            
            // Parse response
            let quote = try parseQuoteData(data: data, ticker: ticker)
            
            // Cache result
            quoteCache[ticker] = (quote, Date())
            
            return quote
            
        } catch {
            print("Error getting real-time quote for \(ticker): \(error)")
            return fallbackQuoteData(for: ticker)
        }
    }
    
    // Get stock fundamentals
    func getStockFundamentals(for ticker: String) async throws -> FundamentalData {
        // Apply rate limiting
        if let lastCall = lastAPICallTime, Date().timeIntervalSince(lastCall) < minTimeBetweenCalls {
            let waitTime = minTimeBetweenCalls - Date().timeIntervalSince(lastCall)
            if waitTime > 0 {
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        
        // Update last API call time
        lastAPICallTime = Date()
        
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "function", value: "OVERVIEW"),
            URLQueryItem(name: "symbol", value: ticker),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try parseFundamentalData(data: data, ticker: ticker)
    }
    
    // Parse time series data from Alpha Vantage
    private func parseTimeSeriesData(data: Data, ticker: String) throws -> StockData {
        let decoder = JSONDecoder()
        
        do {
            // Check for API error messages or rate limiting
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorNote = errorResponse["Note"] as? String {
                print("API returned a note: \(errorNote)")
                throw NSError(domain: "AlphaVantageError", code: 429, userInfo: [NSLocalizedDescriptionKey: errorNote])
            }
            
            let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            guard let timeSeriesData = jsonResponse?["Monthly Time Series"] as? [String: [String: String]] else {
                throw NSError(domain: "ParseError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid time series data structure"])
            }
            
            // Sort the dates in descending order
            let sortedDates = timeSeriesData.keys.sorted(by: >)
            var yearlyReturns: [YearlyReturn] = []
            var closePrices: [Double] = []
            var annualizedReturn: Double = 0
            var volatility: Double = 0
            
            // Calculate yearly returns for the last 5 years (or however many we have)
            for i in 0..<min(5, sortedDates.count-1) {
                if i + 12 < sortedDates.count {
                    let currentDateStr = sortedDates[i]
                    let previousYearDateStr = sortedDates[i + 12]
                    
                    if let currentPriceStr = timeSeriesData[currentDateStr]?["4. close"],
                       let previousYearPriceStr = timeSeriesData[previousYearDateStr]?["4. close"],
                       let currentPrice = Double(currentPriceStr),
                       let previousYearPrice = Double(previousYearPriceStr) {
                        
                        let year = Int(currentDateStr.prefix(4)) ?? 0
                        let returnPercentage = ((currentPrice - previousYearPrice) / previousYearPrice) * 100
                        yearlyReturns.append(YearlyReturn(year: year, returnPercentage: returnPercentage))
                    }
                }
                
                // Collect closing prices for volatility calculation
                if let priceStr = timeSeriesData[sortedDates[i]]?["4. close"],
                   let price = Double(priceStr) {
                    closePrices.append(price)
                }
            }
            
            // Calculate annualized return (geometric mean)
            if closePrices.count > 1 {
                let firstPrice = closePrices.last ?? 0
                let lastPrice = closePrices.first ?? 0
                let years = Double(closePrices.count) / 12.0
                
                if firstPrice > 0 && years > 0 {
                    // Calculate annualized return using CAGR formula
                    annualizedReturn = (pow((lastPrice / firstPrice), (1.0 / years)) - 1.0) * 100
                }
                
                // Calculate volatility (standard deviation of monthly returns)
                if closePrices.count > 1 {
                    var monthlyReturns: [Double] = []
                    for i in 0..<closePrices.count-1 {
                        let monthlyReturn = (closePrices[i] / closePrices[i+1]) - 1.0
                        monthlyReturns.append(monthlyReturn)
                    }
                    
                    let mean = monthlyReturns.reduce(0, +) / Double(monthlyReturns.count)
                    let variance = monthlyReturns.reduce(0) { sum, return_ in
                        sum + pow(return_ - mean, 2)
                    } / Double(monthlyReturns.count)
                    
                    volatility = sqrt(variance) * sqrt(12) * 100 // Annualized volatility
                }
            }
            
            // Calculate Sharpe ratio (assuming risk-free rate of 2%)
            let riskFreeRate = 2.0
            let sharpeRatio = (annualizedReturn - riskFreeRate) / (volatility > 0 ? volatility : 1)
            
            return StockData(
                ticker: ticker,
                yearlyReturns: yearlyReturns,
                annualizedReturn: annualizedReturn,
                volatility: volatility,
                sharpeRatio: sharpeRatio
            )
            
        } catch {
            print("Error parsing time series data: \(error)")
            throw error
        }
    }
    
    // Parse real-time quote data with better error handling
    private func parseQuoteData(data: Data, ticker: String) throws -> QuoteData {
        // Check for API error messages or rate limiting
        if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorNote = errorResponse["Note"] as? String {
            print("API returned a note: \(errorNote)")
            throw NSError(domain: "AlphaVantageError", code: 429, userInfo: [NSLocalizedDescriptionKey: errorNote])
        }
        
        do {
            let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            guard let quoteData = jsonResponse?["Global Quote"] as? [String: String],
                  !quoteData.isEmpty else {
                throw NSError(domain: "ParseError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid quote data structure"])
            }
            
            let price = Double(quoteData["05. price"] ?? "0") ?? 0
            let change = Double(quoteData["09. change"] ?? "0") ?? 0
            let changePercentString = quoteData["10. change percent"] ?? "0%"
            let changePercent = Double(changePercentString.replacingOccurrences(of: "%", with: "")) ?? 0
            
            return QuoteData(
                ticker: ticker,
                price: price,
                change: change,
                changePercent: changePercent,
                timestamp: Date()
            )
        } catch {
            print("Error parsing quote data: \(error)")
            throw error
        }
    }
    
    // Parse fundamental data with better error handling
    private func parseFundamentalData(data: Data, ticker: String) throws -> FundamentalData {
        // Check for API error messages or rate limiting
        if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorNote = errorResponse["Note"] as? String {
            print("API returned a note: \(errorNote)")
            throw NSError(domain: "AlphaVantageError", code: 429, userInfo: [NSLocalizedDescriptionKey: errorNote])
        }
        
        do {
            let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            guard let companyName = jsonResponse?["Name"] as? String else {
                throw NSError(domain: "ParseError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid fundamental data structure"])
            }
            
            let sector = jsonResponse?["Sector"] as? String ?? "Unknown"
            let industry = jsonResponse?["Industry"] as? String ?? "Unknown"
            let beta = Double(jsonResponse?["Beta"] as? String ?? "1.0") ?? 1.0
            let dividendYield = Double(jsonResponse?["DividendYield"] as? String ?? "0.0") ?? 0.0
            let peRatio = Double(jsonResponse?["PERatio"] as? String ?? "0.0") ?? 0.0
            
            return FundamentalData(
                ticker: ticker,
                companyName: companyName,
                sector: sector,
                industry: industry,
                beta: beta,
                dividendYield: dividendYield * 100, // Convert to percentage
                peRatio: peRatio
            )
        } catch {
            print("Error parsing fundamental data: \(error)")
            throw error
        }
    }
    
    // Function to refresh all investment data
    func refreshAllInvestments(tickers: [String]) async -> [String: StockData] {
        var result: [String: StockData] = [:]
        
        for ticker in tickers {
            do {
                // Apply rate limiting between requests
                if let lastCall = lastAPICallTime, Date().timeIntervalSince(lastCall) < minTimeBetweenCalls {
                    let waitTime = minTimeBetweenCalls - Date().timeIntervalSince(lastCall)
                    if waitTime > 0 {
                        try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                    }
                }
                
                lastAPICallTime = Date()
                
                let stockData = try await getStockData(for: ticker)
                result[ticker] = stockData
            } catch {
                print("Error refreshing data for \(ticker): \(error)")
            }
        }
        
        return result
    }
    
    // Fallback for when API calls fail
    private func fallbackQuoteData(for ticker: String) -> QuoteData? {
        // Try to use cached data even if it's older than 5 minutes
        if let cached = quoteCache[ticker] {
            return cached.data
        }
        
        // Create approximate data based on investment records
        if let stockData = cachedStockData[ticker] {
            // Create reasonable estimate based on historical data
            return QuoteData(
                ticker: ticker,
                price: 100.0, // Placeholder price
                change: 0.0,
                changePercent: stockData.annualizedReturn > 0 ? 0.1 : -0.1, // Small positive/negative change based on trend
                timestamp: Date()
            )
        }
        
        // Default fallback
        return QuoteData(
            ticker: ticker,
            price: 100.0,
            change: 0.0,
            changePercent: 0.0,
            timestamp: Date()
        )
    }
}

// Data models
struct StockData {
    let ticker: String
    let yearlyReturns: [YearlyReturn]
    let annualizedReturn: Double
    let volatility: Double
    let sharpeRatio: Double
}

struct QuoteData {
    let ticker: String
    let price: Double
    let change: Double
    let changePercent: Double
    let timestamp: Date
}

struct FundamentalData {
    let ticker: String
    let companyName: String
    let sector: String
    let industry: String
    let beta: Double
    let dividendYield: Double
    let peRatio: Double
}
