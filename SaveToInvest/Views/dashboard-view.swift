import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @EnvironmentObject private var expenseAnalyzer: ExpenseAnalyzer
    
    @State private var showAddExpense = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 头部用户欢迎
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("欢迎，\(viewModel.firebaseService.currentUser?.displayName ?? "用户")")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("让我们分析你的支出")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
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
                
                // 本月支出概览
                VStack(alignment: .leading, spacing: 10) {
                    Text("本月支出概览")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if expenseAnalyzer.monthlySummary.isEmpty {
                        emptyStateView(message: "暂无支出数据")
                    } else {
                        ExpenseSummaryCard(categorySummaries: expenseAnalyzer.monthlySummary)
                    }
                }
                
                // 非必要支出分析
                VStack(alignment: .leading, spacing: 10) {
                    Text("非必要支出分析")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if expenseAnalyzer.unnecessaryExpenses.isEmpty {
                        emptyStateView(message: "没有发现非必要支出")
                    } else {
                        UnnecessaryExpensesCard(
                            unnecessaryExpenses: expenseAnalyzer.unnecessaryExpenses,
                            opportunityCosts: expenseAnalyzer.opportunityCosts,
                            getInvestmentName: expenseAnalyzer.getInvestmentName
                        )
                    }
                }
                
                // 最大的节省机会
                VStack(alignment: .leading, spacing: 10) {
                    Text("节省与投资机会")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if expenseAnalyzer.opportunityCosts.isEmpty {
                        emptyStateView(message: "添加支出以查看投资机会")
                    } else {
                        OpportunityHighlightCard(
                            opportunityCosts: expenseAnalyzer.opportunityCosts,
                            getInvestmentName: expenseAnalyzer.getInvestmentName,
                            formatCurrency: expenseAnalyzer.formatCurrency
                        )
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("仪表板")
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView()
                .environmentObject(viewModel)
        }
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
}

struct ExpenseSummaryCard: View {
    let categorySummaries: [CategorySummary]
    
    var body: some View {
        VStack {
            ForEach(categorySummaries.prefix(5)) { summary in
                HStack {
                    Image(systemName: summary.category.icon)
                        .frame(width: 30)
                    
                    Text(summary.category.rawValue)
                    
                    Spacer()
                    
                    Text("$\(summary.totalAmount, specifier: "%.2f")")
                        .fontWeight(.medium)
                }
                .padding(.vertical, 5)
                
                if summary.id != categorySummaries.prefix(5).last?.id {
                    Divider()
                }
            }
            
            if categorySummaries.count > 5 {
                Button(action: {}) {
                    Text("查看全部")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.top, 5)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct UnnecessaryExpensesCard: View {
    let unnecessaryExpenses: [Expense]
    let opportunityCosts: [OpportunityCost]
    let getInvestmentName: (String) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("本月非必要支出：$\(totalAmount, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            ForEach(unnecessaryExpenses.prefix(3)) { expense in
                HStack {
                    Image(systemName: expense.category.icon)
                        .foregroundColor(.orange)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading) {
                        Text(expense.title)
                            .font(.subheadline)
                        
                        Text(expense.category.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("$\(expense.amount, specifier: "%.2f")")
                        .fontWeight(.medium)
                }
                
                if expense.id != unnecessaryExpenses.prefix(3).last?.id {
                    Divider()
                }
            }
            
            if unnecessaryExpenses.count > 3 {
                Button(action: {}) {
                    Text("查看全部")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.top, 5)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private var totalAmount: Double {
        unnecessaryExpenses.reduce(0) { $0 + $1.amount }
    }
}

struct OpportunityHighlightCard: View {
    let opportunityCosts: [OpportunityCost]
    let getInvestmentName: (String) -> String
    let formatCurrency: (Double) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            if let topOpportunity = opportunityCosts.first {
                // 显示最大的机会
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Image(systemName: "arrow.up.forward")
                            .foregroundColor(.green)
                        
                        Text("每月节省")
                            .font(.subheadline)
                        
                        Text(formatCurrency(topOpportunity.monthlyAmount))
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("1年后")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let year1 = topOpportunity.projectedReturns.first {
                                Text(formatCurrency(year1.totalValue))
                                    .font(.headline)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("5年后")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let year5 = topOpportunity.projectedReturns.first(where: { $0.year == 5 }) {
                                Text(formatCurrency(year5.totalValue))
                                    .font(.headline)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("10年后")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let year10 = topOpportunity.projectedReturns.first(where: { $0.year == 10 }) {
                                Text(formatCurrency(year10.totalValue))
                                    .font(.headline)
                            }
                        }
                    }
                    
                    Text("投资到：\(getInvestmentName(topOpportunity.investmentId))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                }
            }
            
            Button(action: {}) {
                Text("查看详细机会分析")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environmentObject(MainViewModel())
            .environmentObject(ExpenseAnalyzer(firebaseService: FirebaseService()))
    }
}
