//
//  ContentView.swift
//  SaveToInvest
//
//  Created by Kesong Lin on 3/14/25.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @EnvironmentObject private var expenseAnalyzer: ExpenseAnalyzer

    @State private var showAddExpense = false
    @State private var showImportView = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome，\(viewModel.firebaseService.currentUser?.displayName ?? "user")")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Let's analyze your expenses")
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

                VStack(alignment: .leading, spacing: 10) {
                    Text("Overview of expenditures for the month")
                        .font(.headline)
                        .padding(.horizontal)

                    if expenseAnalyzer.monthlySummary.isEmpty {
                        emptyStateView(message: "No expenditure data available")
                    } else {
                        ExpenseSummaryCard(categorySummaries: expenseAnalyzer.monthlySummary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Analysis of non-essential expenditures")
                        .font(.headline)
                        .padding(.horizontal)

                    if expenseAnalyzer.unnecessaryExpenses.isEmpty {
                        emptyStateView(message: "No non-essential expenditures were identified")
                    } else {
                        UnnecessaryExpensesCard(
                            unnecessaryExpenses: expenseAnalyzer.unnecessaryExpenses,
                            opportunityCosts: expenseAnalyzer.opportunityCosts,
                            getInvestmentName: expenseAnalyzer.getInvestmentName
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Savings and investment opportunities")
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
            .padding(.vertical)
        }
        .navigationTitle("dashboard")
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showImportView) {
            ImportDataView()
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
                    Text("View All")
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
            Text("Non-essential expenses for the month：$\(totalAmount, specifier: "%.2f")")
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
                    Text("View All")
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
                        
                        Text("Monthly savings")
                            .font(.subheadline)
                        
                        Text(formatCurrency(topOpportunity.monthlyAmount))
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    
                    Divider()
                    
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
                            Text("5 year")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let year5 = topOpportunity.projectedReturns.first(where: { $0.year == 5 }) {
                                Text(formatCurrency(year5.totalValue))
                                    .font(.headline)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("10 year")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let year10 = topOpportunity.projectedReturns.first(where: { $0.year == 10 }) {
                                Text(formatCurrency(year10.totalValue))
                                    .font(.headline)
                            }
                        }
                    }
                    
                    Text("invest in：\(getInvestmentName(topOpportunity.investmentId))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                }
            }
        }
    }
    
    struct DashboardView_Previews: PreviewProvider {
        static var previews: some View {
            DashboardView()
                .environmentObject(MainViewModel())
                .environmentObject(ExpenseAnalyzer(firebaseService: FirebaseService()))
        }
    }
}
