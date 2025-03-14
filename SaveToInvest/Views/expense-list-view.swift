import SwiftUI

struct ExpenseListView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @EnvironmentObject private var expenseAnalyzer: ExpenseAnalyzer
    
    @State private var showAddExpense = false
    @State private var searchText = ""
    @State private var selectedCategory: ExpenseCategory?
    @State private var sortOption: SortOption = .dateDesc
    
    private var filteredExpenses: [Expense] {
        var result = expenseAnalyzer.expenses
        
        // 应用搜索过滤
        if !searchText.isEmpty {
            result = result.filter { expense in
                expense.title.localizedCaseInsensitiveContains(searchText) ||
                expense.category.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 应用类别过滤
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        // 应用排序
        switch sortOption {
        case .dateDesc:
            return result.sorted(by: { $0.date > $1.date })
        case .dateAsc:
            return result.sorted(by: { $0.date < $1.date })
        case .amountDesc:
            return result.sorted(by: { $0.amount > $1.amount })
        case .amountAsc:
            return result.sorted(by: { $0.amount < $1.amount })
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 搜索和过滤控件
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("搜索支出", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // 分类过滤按钮行
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Button(action: {
                            selectedCategory = nil
                        }) {
                            Text("全部")
                                .padding(.vertical, 5)
                                .padding(.horizontal, 10)
                                .background(selectedCategory == nil ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedCategory == nil ? .white : .primary)
                                .cornerRadius(15)
                        }
                        
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                HStack {
                                    Image(systemName: category.icon)
                                    Text(category.rawValue)
                                }
                                .padding(.vertical, 5)
                                .padding(.horizontal, 10)
                                .background(selectedCategory == category ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedCategory == category ? .white : .primary)
                                .cornerRadius(15)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 排序选项
                HStack {
                    Text("排序方式：")
                        .font(.caption)
                    
                    Picker("排序", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.description).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // 支出列表
                if filteredExpenses.isEmpty {
                    Spacer()
                    VStack {
                        Image(systemName: "tray")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.secondary)
                        
                        Text("暂无支出记录")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("点击底部加号按钮添加支出")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 5)
                    }
                    .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(filteredExpenses) { expense in
                            ExpenseRow(expense: expense)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.deleteExpense(id: expense.id)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("支出记录")
            .navigationBarItems(
                trailing: Button(action: {
                    showAddExpense = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.blue)
                }
            )
            .sheet(isPresented: $showAddExpense) {
                AddExpenseView()
                    .environmentObject(viewModel)
            }
        }
    }
}

struct ExpenseRow: View {
    let expense: Expense
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 15) {
            // 类别图标
            ZStack {
                Circle()
                    .fill(expense.isNecessary ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: expense.category.icon)
                    .foregroundColor(expense.isNecessary ? .green : .orange)
            }
            
            // 支出信息
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.headline)
                
                Text(expense.category.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(dateFormatter.string(from: expense.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 金额
            Text("$\(expense.amount, specifier: "%.2f")")
                .font(.headline)
                .foregroundColor(expense.isNecessary ? .primary : .orange)
        }
        .padding(.vertical, 5)
    }
}

enum SortOption: String, CaseIterable {
    case dateDesc = "dateDesc"
    case dateAsc = "dateAsc"
    case amountDesc = "amountDesc"
    case amountAsc = "amountAsc"
    
    var description: String {
        switch self {
        case .dateDesc: return "日期（新到旧）"
        case .dateAsc: return "日期（旧到新）"
        case .amountDesc: return "金额（大到小）"
        case .amountAsc: return "金额（小到大）"
        }
    }
}

struct ExpenseListView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = MainViewModel()
        ExpenseListView()
            .environmentObject(viewModel)
            .environmentObject(ExpenseAnalyzer(firebaseService: FirebaseService()))
    }
}
