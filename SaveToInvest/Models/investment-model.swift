import Foundation

struct Investment: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var ticker: String
    var type: InvestmentType
    var historicalReturns: [YearlyReturn]
    var riskLevel: RiskLevel
    
    // New fields for enhanced metrics
    var annualizedReturn: Double = 0
    var volatility: Double = 0
    var sharpeRatio: Double = 0
    var lastUpdated: Date = Date()
    
    // Calculate average year return (original calculation)
    var averageAnnualReturn: Double {
        guard !historicalReturns.isEmpty else { return annualizedReturn }
        let sum = historicalReturns.reduce(0) { $0 + $1.returnPercentage }
        return sum / Double(historicalReturns.count)
    }
    
    // Calculate risk-adjusted return
    var riskAdjustedReturn: Double {
        guard volatility > 0 else { return 0 }
        return annualizedReturn / volatility
    }
    
    // Determine if this is a good investment based on Sharpe ratio
    var investmentQuality: InvestmentQuality {
        if sharpeRatio < 0 {
            return .poor
        } else if sharpeRatio < 0.5 {
            return .belowAverage
        } else if sharpeRatio < 1.0 {
            return .average
        } else if sharpeRatio < 1.5 {
            return .good
        } else {
            return .excellent
        }
    }
    
    // Recommended allocation percentage based on risk
    func recommendedAllocation(for riskTolerance: RiskTolerance) -> Double {
        switch (riskTolerance, riskLevel) {
        case (.conservative, .low):
            return 60.0
        case (.conservative, .medium):
            return 20.0
        case (.conservative, .high):
            return 10.0
        case (.moderate, .low):
            return 40.0
        case (.moderate, .medium):
            return 40.0
        case (.moderate, .high):
            return 20.0
        case (.aggressive, .low):
            return 20.0
        case (.aggressive, .medium):
            return 30.0
        case (.aggressive, .high):
            return 50.0
        }
    }
}

struct YearlyReturn: Identifiable, Codable {
    var id: String = UUID().uuidString
    var year: Int
    var returnPercentage: Double
}

enum InvestmentType: String, Codable, CaseIterable {
    case etf = "ETF"
    case stock = "Stock"
    case bond = "Bond"
    case index = "Index Fund"
    case crypto = "Cryptocurrency"
    
    var description: String {
        switch self {
        case .etf: return "Exchange Traded Fund"
        case .stock: return "Individual Stock"
        case .bond: return "Bond Fund"
        case .index: return "Index Fund"
        case .crypto: return "Cryptocurrency"
        }
    }
    
    var icon: String {
        switch self {
        case .etf, .index: return "chart.bar.fill"
        case .stock: return "dollarsign.circle.fill"
        case .bond: return "shield.fill"
        case .crypto: return "bitcoinsign.circle.fill"
        }
    }
}

enum RiskLevel: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "red"
        }
    }
    
    var description: String {
        switch self {
        case .low: return "Conservative - Lower returns, lower volatility"
        case .medium: return "Moderate - Balanced returns and volatility"
        case .high: return "Aggressive - Higher potential returns, higher volatility"
        }
    }
}

enum InvestmentQuality: String {
    case poor = "Poor"
    case belowAverage = "Below Average"
    case average = "Average"
    case good = "Good"
    case excellent = "Excellent"
    
    var color: String {
        switch self {
        case .poor: return "red"
        case .belowAverage: return "orange"
        case .average: return "yellow"
        case .good: return "green"
        case .excellent: return "blue"
        }
    }
    
    var description: String {
        switch self {
        case .poor: return "High risk relative to return"
        case .belowAverage: return "Risk outweighs return potential"
        case .average: return "Balanced risk and return"
        case .good: return "Good return for the risk level"
        case .excellent: return "Excellent return with controlled risk"
        }
    }
}

enum RiskTolerance: String, CaseIterable {
    case conservative = "Conservative"
    case moderate = "Moderate"
    case aggressive = "Aggressive"
    
    var description: String {
        switch self {
        case .conservative: return "Focus on capital preservation with stable returns"
        case .moderate: return "Balance between growth and stability"
        case .aggressive: return "Maximize growth potential, can tolerate volatility"
        }
    }
}

// Add extension to the existing code for default options
extension Investment {
    static let defaultOptions: [Investment] = [
        Investment(
            name: "S&P 500",
            ticker: "SPY",
            type: .index,
            historicalReturns: [
                YearlyReturn(year: 2018, returnPercentage: -4.38),
                YearlyReturn(year: 2019, returnPercentage: 31.49),
                YearlyReturn(year: 2020, returnPercentage: 18.40),
                YearlyReturn(year: 2021, returnPercentage: 28.71),
                YearlyReturn(year: 2022, returnPercentage: -18.11),
                YearlyReturn(year: 2023, returnPercentage: 24.23)
            ],
            riskLevel: .medium,
            annualizedReturn: 11.82,
            volatility: 17.5,
            sharpeRatio: 0.67
        ),
        Investment(
            name: "NASDAQ-100",
            ticker: "QQQ",
            type: .etf,
            historicalReturns: [
                YearlyReturn(year: 2018, returnPercentage: -0.12),
                YearlyReturn(year: 2019, returnPercentage: 39.12),
                YearlyReturn(year: 2020, returnPercentage: 48.63),
                YearlyReturn(year: 2021, returnPercentage: 27.51),
                YearlyReturn(year: 2022, returnPercentage: -32.58),
                YearlyReturn(year: 2023, returnPercentage: 54.03)
            ],
            riskLevel: .high,
            annualizedReturn: 18.95,
            volatility: 25.3,
            sharpeRatio: 0.75
        ),
        Investment(
            name: "Total Bond Market",
            ticker: "BND",
            type: .bond,
            historicalReturns: [
                YearlyReturn(year: 2018, returnPercentage: -0.05),
                YearlyReturn(year: 2019, returnPercentage: 8.71),
                YearlyReturn(year: 2020, returnPercentage: 7.74),
                YearlyReturn(year: 2021, returnPercentage: -1.67),
                YearlyReturn(year: 2022, returnPercentage: -13.04),
                YearlyReturn(year: 2023, returnPercentage: 5.08)
            ],
            riskLevel: .low,
            annualizedReturn: 3.2,
            volatility: 7.3,
            sharpeRatio: 0.44
        )
    ]
}
