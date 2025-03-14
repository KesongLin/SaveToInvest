import SwiftUI

struct AddExpenseView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var viewModel: MainViewModel
    
    @State private var title = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var selectedCategory = ExpenseCategory.food
    @State private var isNecessary = true
    @State private var notes = ""
    
    @State private var showingDatePicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("标题", text: $title)
                    
                    HStack {
                        Text("$")
                        TextField("金额", text: $amount)
                            .keyboardType(.decimalPad)
                    }
                    
                    Button(action: {
                        showingDatePicker.toggle()
                    }) {
                        HStack {
                            Text("日期")
                            Spacer()
                            Text(dateFormatter.string(from: date))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if showingDatePicker {
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .labelsHidden()
                    }
                }
                
                Section(header: Text("分类")) {
                    Picker("类别", selection: $selectedCategory) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                        }
                    }
                    
                    Toggle("是必要支出", isOn: $isNecessary)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                    
                    if !isNecessary {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            
                            Text("此支出将被标记为非必要，用于机会成本分析")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("备注")) {
                    TextField("添加备注（可选）", text: $notes)
                }
                
                Section {
                    Button(action: saveExpense) {
                        Text("保存支出")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .background(isFormValid ? Color.blue : Color.gray)
                            .cornerRadius(8)
                    }
                    .disabled(!isFormValid)
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("添加支出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !title.isEmpty && !amount.isEmpty && Double(amount) != nil && Double(amount)! > 0
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    private func saveExpense() {
        guard let amountValue = Double(amount) else { return }
        
        viewModel.addExpense(
            title: title,
            amount: amountValue,
            date: date,
            category: selectedCategory,
            isNecessary: isNecessary,
            notes: notes.isEmpty ? nil : notes
        )
        
        presentationMode.wrappedValue.dismiss()
    }
}

struct AddExpenseView_Previews: PreviewProvider {
    static var previews: some View {
        AddExpenseView()
            .environmentObject(MainViewModel())
    }
}
