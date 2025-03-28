import SwiftUI

struct OpportunityView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @EnvironmentObject private var expenseAnalyzer: ExpenseAnalyzer
    
    @State private var selectedTimeframe: Int = 5 // 默认显示5年
    @State private var selectedInvestmentIndex: Int = 0
    
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
                    // 总节省机会卡片
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Monthly savings")
                            .font(.headline)
                        
                        HStack(alignment: .firstTextBaseline) {
                            Text(formatCurrency(totalMonthlySavings))
                                .font(.system(size: 36, weight: .bold))
                            
                            Text("/ month")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Yearly saveings：\(formatCurrency(totalYearlySavings))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // 分隔线
                        Divider()
                            .padding(.vertical, 8)
                        
                        // 时间选择器
                        VStack(alignment: .leading, spacing: 5) {
                            Text("If that money is invested in：")
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
                            
                            Text("Length of investment：")
                                .font(.subheadline)
                                .padding(.top, 5)
                            
                            Picker("Length of investment", selection: $selectedTimeframe) {
                                Text("1 year").tag(1)
                                Text("5 year").tag(5)
                                Text("10 year").tag(10)
                                Text("20 year").tag(20)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                    
                    // 投资回报预测
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
                    
                    // 详细支出机会成本列表
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Opportunity cost of non-essential expenditures")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if expenseAnalyzer.opportunityCosts.isEmpty {
                            Text("Data on non-essential expenditures are not available")
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
                    
                    // 投资说明
                    VStack(alignment: .leading, spacing: 5) {
                        if !investments.isEmpty {
                            Text("About \(investments[selectedInvestmentIndex].name)")
                                .font(.headline)
                            
                            Text("Historical average annualized rate of return：\(String(format: "%.2f", investments[selectedInvestmentIndex].averageAnnualReturn))%")
                                .font(.subheadline)
                            
                            Text("Risk level：\(investments[selectedInvestmentIndex].riskLevel.rawValue)")
                                .font(.subheadline)
                            
                            Text("Past performance is not indicative of future performance. Investment involves risks, be cautious when entering the market.")
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
                }
                .padding(.vertical)
            }
            .navigationTitle("Investment Opportunities")
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

struct InvestmentReturnChart: View {
    let opportunityCosts: [OpportunityCost]
    let selectedInvestment: Investment
    let selectedTimeframe: Int
    
    private var projectedReturn: ProjectedReturn? {
        guard let opportunity = opportunityCosts.first else { return nil }
        
        // 使用第一个机会成本作为模板，计算总的投资回报
        var combinedOpportunity = OpportunityCost(
            expenseId: "combined",
            investmentId: selectedInvestment.id,
            monthlyAmount: opportunityCosts.reduce(0) { $0 + $1.monthlyAmount },
            yearlySavings: opportunityCosts.reduce(0) { $0 + $1.monthlyAmount } * 12,
            years: selectedTimeframe
        )
        
        combinedOpportunity.calculateReturns(averageAnnualReturn: selectedInvestment.averageAnnualReturn)
        
        return combinedOpportunity.projectedReturns.first(where: { $0.year == selectedTimeframe })
    }
    
    var body: some View {
        VStack {
            if let projectedReturn = projectedReturn {
                VStack(spacing: 15) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(selectedTimeframe)Total value after years")
                                .font(.headline)
                            
                            Text(formatCurrency(projectedReturn.totalValue))
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("return on investment")
                                .font(.headline)
                            
                            Text(formatCurrency(projectedReturn.returnAmount))
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // 简单条形图显示本金vs收益
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.blue.opacity(0.7))
                            .frame(width: calculateWidth(value: projectedReturn.totalContributions), height: 30)
                            .overlay(
                                Text("capital").font(.caption).foregroundColor(.white)
                            )
                        
                        Rectangle()
                            .fill(Color.green.opacity(0.7))
                            .frame(width: calculateWidth(value: projectedReturn.returnAmount), height: 30)
                            .overlay(
                                Text("earnings").font(.caption).foregroundColor(.white)
                            )
                    }
                    .cornerRadius(5)
                    
                    Text("return on investment (ROI)：\(String(format: "%.2f", projectedReturn.returnPercentage))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            } else {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
        }
    }
    
    private func calculateWidth(value: Double) -> CGFloat {
        guard let totalValue = projectedReturn?.totalValue, totalValue > 0 else { return 0 }
        
        // 计算在总宽度中的比例
        let width = CGFloat(value / totalValue) * UIScreen.main.bounds.width * 0.85
        return max(width, 40) // 确保至少有最小宽度以显示文本
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

struct OpportunityCostRow: View {
    let opportunity: OpportunityCost
    let investment: Investment
    let timeframe: Int
    let formatCurrency: (Double) -> String
    
    private var projectedReturn: ProjectedReturn? {
        return opportunity.projectedReturns.first(where: { $0.year == timeframe })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Monthly savings：\(formatCurrency(opportunity.monthlyAmount))")
                    .font(.headline)
                
                Spacer()
                
                Text("every year：\(formatCurrency(opportunity.yearlySavings))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let projectedReturn = projectedReturn {
                HStack {
                    Text("\(timeframe)later in the year：")
                        .font(.subheadline)
                    
                    Text(formatCurrency(projectedReturn.totalValue))
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Text("earnings：\(formatCurrency(projectedReturn.returnAmount))")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct OpportunityView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = MainViewModel()
        OpportunityView()
            .environmentObject(viewModel)
            .environmentObject(ExpenseAnalyzer(firebaseService: FirebaseService()))
    }
}
