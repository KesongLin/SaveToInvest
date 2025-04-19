import Foundation
import Combine

class ExpenseAnalyzer: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var unnecessaryExpenses: [Expense] = []
    @Published var monthlySummary: [CategorySummary] = []
    @Published var opportunityCosts: [OpportunityCost] = []
    @Published var investments: [Investment] = []
    
    private var firebaseService: FirebaseService
    private var cancellables = Set<AnyCancellable>()
    
    @objc func refreshExpenseData() {
        print("📱 RefreshExpenses notification received")
        if let userId = firebaseService.currentUser?.id {
            print("🔄 Refreshing expense data for user: \(userId)")
            
            // Cancel existing subscriptions
            cancellables.removeAll()
            
            // Re-subscribe to expense changes
            streamExpenses(userId: userId)
        } else {
            print("⚠️ Cannot refresh expenses: No authenticated user")
        }
    }
    
    
    init(firebaseService: FirebaseService) {
        self.firebaseService = firebaseService
        
        // 加载投资选项
        loadInvestments()
        
        // 监听用户认证状态变化
        firebaseService.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated, let userId = firebaseService.currentUser?.id {
                    self?.streamExpenses(userId: userId)
                } else {
                    self?.expenses = []
                    self?.unnecessaryExpenses = []
                    self?.monthlySummary = []
                    self?.opportunityCosts = []
                }
            }
            .store(in: &cancellables)
        
        // Add this observer for app becoming active
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshExpenseData),
            name: Notification.Name("RefreshExpenses"),
            object: nil
        )
    }
    
    // MARK: - Data Loading
    
    private func loadInvestments() {
        firebaseService.getInvestments { [weak self] investments in
            DispatchQueue.main.async {
                self?.investments = investments
            }
        }
    }
    
    private func streamExpenses(userId: String) {
        firebaseService.streamExpenses(userId: userId)
            .sink { [weak self] expenses in
                DispatchQueue.main.async {
                    self?.expenses = expenses
                    self?.analyzeExpenses()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Expense Analysis
    
    func analyzeExpenses() {
        // Check if we're already on the main thread
        if Thread.isMainThread {
            // Directly execute the analysis
            performAnalysis()
        } else {
            // Dispatch to the main thread
            DispatchQueue.main.async { [weak self] in
                self?.performAnalysis()
            }
        }
    }
    
    // Helper method to perform the actual analysis
    private func performAnalysis() {
        // 1. Identify unnecessary expenses
        identifyUnnecessaryExpenses()
        
        // 2. Generate monthly spending summary
        generateMonthlySummary()
        
        // 3. Calculate opportunity costs
        calculateOpportunityCosts()
        
        // Log completion for debugging
        print("Expense analysis completed with \(expenses.count) total expenses and \(unnecessaryExpenses.count) unnecessary expenses")
    }
    
    // Add this new method to force refresh data from Firebase
    func forceRefresh() {
        guard let userId = firebaseService.currentUser?.id else { return }
        
        // Cancel existing subscriptions to prevent duplicates
        cancellables.removeAll()
        
        // Re-subscribe to expense stream
        streamExpenses(userId: userId)
        
        // Log the refresh action
        print("Forced refresh of expense data for user: \(userId)")
    }
    
    private func identifyUnnecessaryExpenses() {
        // 基于用户设置和智能分类识别非必要支出
        let userCategoryPreferences = firebaseService.currentUser?.settings.categoryPreferences ?? [:]
        
        // 过滤出最近一个月的非必要支出
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        
        unnecessaryExpenses = expenses.filter { expense in
            // 如果用户明确设置了这个类别是否必要，使用用户设置
            if let isNecessary = userCategoryPreferences[expense.category.rawValue] {
                return !isNecessary && expense.date >= oneMonthAgo
            }
            
            // 否则使用预定义的分类规则
            return !expense.isNecessary && expense.date >= oneMonthAgo
        }
    }
    
    private func generateMonthlySummary() {
        // 将支出按类别分组并计算每个类别的总金额
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let recentExpenses = expenses.filter { $0.date >= oneMonthAgo }
        
        var categorySummary: [ExpenseCategory: Double] = [:]
        
        for expense in recentExpenses {
            let currentAmount = categorySummary[expense.category] ?? 0
            categorySummary[expense.category] = currentAmount + expense.amount
        }
        
        // 转换为摘要对象数组
        monthlySummary = categorySummary.map { category, amount in
            return CategorySummary(
                category: category,
                totalAmount: amount,
                isNecessary: category.isTypicallyNecessary
            )
        }.sorted { $0.totalAmount > $1.totalAmount }
    }
    
    private func calculateOpportunityCosts() {
        guard !unnecessaryExpenses.isEmpty, !investments.isEmpty else {
            opportunityCosts = []
            return
        }
        
        // 按类别分组非必要支出并计算月度总额
        var categoryCosts: [ExpenseCategory: Double] = [:]
        
        for expense in unnecessaryExpenses {
            let currentAmount = categoryCosts[expense.category] ?? 0
            categoryCosts[expense.category] = currentAmount + expense.amount
        }
        
        // 为每个类别生成机会成本
        var newOpportunityCosts: [OpportunityCost] = []
        
        for (category, monthlyAmount) in categoryCosts {
            // 使用默认的SPY投资选项（也可以根据设置选择不同的投资）
            guard let defaultInvestment = investments.first(where: { $0.id == "SPY" }) ?? investments.first else {
                continue
            }
            
            let yearlySavings = monthlyAmount * 12
            let years = firebaseService.currentUser?.settings.defaultProjectionYears ?? 10
            
            var opportunityCost = OpportunityCost(
                expenseId: category.rawValue,
                investmentId: defaultInvestment.id,
                monthlyAmount: monthlyAmount,
                yearlySavings: yearlySavings,
                years: years
            )
            
            // 计算投资回报
            opportunityCost.calculateReturns(averageAnnualReturn: defaultInvestment.averageAnnualReturn)
            
            newOpportunityCosts.append(opportunityCost)
        }
        
        opportunityCosts = newOpportunityCosts.sorted { $0.monthlyAmount > $1.monthlyAmount }
    }
    
    // MARK: - Helper Methods
    
    func getInvestmentName(for id: String) -> String {
        return investments.first(where: { $0.id == id })?.name ?? "Investment"
    }
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    func refreshExpenseStream() {
        if let userId = firebaseService.currentUser?.id {
            // Cancel existing subscriptions
            cancellables.removeAll()
            
            // Resubscribe to expense changes
            streamExpenses(userId: userId)
            
            // Log the refresh
            print("Refreshed expense stream for user: \(userId)")
        }
    }
}

struct CategorySummary: Identifiable {
    var id = UUID()
    var category: ExpenseCategory
    var totalAmount: Double
    var isNecessary: Bool
}
