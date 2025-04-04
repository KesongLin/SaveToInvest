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
                Section(header: Text("Basic Information")) {
                    TextField("title", text: $title)
                    
                    HStack {
                        Text("$")
                        TextField("amounts", text: $amount)
                            .keyboardType(.decimalPad)
                    }
                    
                    Button(action: {
                        showingDatePicker.toggle()
                    }) {
                        HStack {
                            Text("dates")
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
                
                Section(header: Text("categories")) {
                    Picker("categories", selection: $selectedCategory) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                        }
                    }
                    
                    Toggle("Necessary expenditure", isOn: $isNecessary)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                    
                    if !isNecessary {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            
                            Text("This expenditure will be marked as non-essential for the purpose of opportunity cost analysis")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Note")) {
                    TextField("Add Remarks (optional)", text: $notes)
                }
                
                Section {
                    Button(action: saveExpense) {
                        Text("Save expense")
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
            .navigationTitle("Add expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel") {
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
