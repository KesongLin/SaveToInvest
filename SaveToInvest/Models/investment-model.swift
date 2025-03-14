import Foundation

struct Investment: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var ticker: String
    var type: InvestmentType
    var historicalReturns: [YearlyReturn]
    var riskLevel: RiskLevel
    
    // 计算平均年回报率
    var averageAnnualReturn: Double {
        guard !historicalReturns.isEmpty else { return 0 }
        let sum = historicalReturns.reduce(0) { $0 + $1.returnPercentage }
        return sum / Double(historicalReturns.count)
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
}

// 预定义的投资选项
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
            riskLevel: .medium
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
            riskLevel: .high
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
            riskLevel: .low
        )
    ]
}
