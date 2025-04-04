import Foundation

struct OpportunityCost: Identifiable, Codable {
    var id: String = UUID().uuidString
    var expenseId: String
    var investmentId: String
    var monthlyAmount: Double
    var yearlySavings: Double
    var years: Int
    var projectedReturns: [ProjectedReturn]
    
    init(expenseId: String, investmentId: String, monthlyAmount: Double, yearlySavings: Double, years: Int) {
        self.expenseId = expenseId
        self.investmentId = investmentId
        self.monthlyAmount = monthlyAmount
        self.yearlySavings = yearlySavings
        self.years = years
        self.projectedReturns = []
    }
    
    // 计算复利投资回报
    mutating func calculateReturns(averageAnnualReturn: Double) {
        projectedReturns = []
        
        var balance = 0.0
        let monthlyReturn = averageAnnualReturn / 12.0 / 100.0
        
        for year in 1...years {
            var yearEndBalance = balance
            
            // 计算每个月的复利
            for _ in 1...12 {
                yearEndBalance += monthlyAmount
                yearEndBalance *= (1 + monthlyReturn)
            }
            
            let totalContributions = monthlyAmount * Double(year * 12)
            let returnAmount = yearEndBalance - totalContributions
            
            projectedReturns.append(ProjectedReturn(
                year: year,
                totalContributions: totalContributions,
                returnAmount: returnAmount,
                totalValue: yearEndBalance
            ))
            
            balance = yearEndBalance
        }
    }
}

struct ProjectedReturn: Identifiable, Codable {
    var id: String = UUID().uuidString
    var year: Int
    var totalContributions: Double
    var returnAmount: Double
    var totalValue: Double
    
    var returnPercentage: Double {
        guard totalContributions > 0 else { return 0 }
        return (returnAmount / totalContributions) * 100
    }
}
