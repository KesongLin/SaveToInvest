import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @EnvironmentObject private var expenseAnalyzer: ExpenseAnalyzer
    
    @State private var showDefaultInvestmentPicker = false
    @State private var defaultProjectionYears = 10
    
    private var userSettings: UserSettings {
        return viewModel.firebaseService.currentUser?.settings ?? UserSettings()
    }
    
    private var userEmail: String {
        return viewModel.firebaseService.currentUser?.email ?? "not logged in"
    }
    
    var body: some View {
        NavigationView {
            Form {
                // 用户信息部分
                Section(header: Text("Account Information")) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text(viewModel.firebaseService.currentUser?.displayName ?? "user")
                                .font(.headline)
                            
                            Text(userEmail)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 10)
                    }
                    .padding(.vertical, 5)
                }
                
                // 投资偏好设置
                Section(header: Text("investment preference")) {
                    Picker("Default Investment Duration", selection: $defaultProjectionYears) {
                        Text("1 year").tag(1)
                        Text("5 year").tag(5)
                        Text("10 year").tag(10)
                        Text("20 yaer").tag(20)
                    }
                    .pickerStyle(DefaultPickerStyle())
                    
                    Button(action: {
                        showDefaultInvestmentPicker = true
                    }) {
                        HStack {
                            Text("Default Investment Options")
                            Spacer()
                            Text(getDefaultInvestmentName())
                                .foregroundColor(.secondary)
                        }
                    }
                    .sheet(isPresented: $showDefaultInvestmentPicker) {
                        InvestmentPickerView(
                            investments: expenseAnalyzer.investments,
                            selectedInvestmentId: userSettings.defaultInvestmentId,
                            onSelect: { investmentId in
                                updateUserSettings(defaultInvestmentId: investmentId)
                                showDefaultInvestmentPicker = false
                            }
                        )
                    }
                }
                
                // 支出分类偏好
                Section(header: Text("Expenditure classification preferences")) {
                    NavigationLink(destination: CategoryPreferencesView(
                        categoryPreferences: userSettings.categoryPreferences,
                        onUpdate: { preferences in
                            updateUserSettings(categoryPreferences: preferences)
                        }
                    )) {
                        Text("Need for customized expenditures")
                    }
                    
                    Text("You can customize which spending categories are considered necessary based on your lifestyle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 数据和隐私
                Section(header: Text("Data and privacy")) {
                    Button(action: {
                        // 导出数据功能
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export data")
                        }
                    }
                    
                    Button(action: {
                        // 清除所有数据功能
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear all data")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // 关于和反馈
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        // 发送反馈功能
                    }) {
                        Text("Send Feedback")
                    }
                    
                    Link("privacy policy", destination: URL(string: "https://example.com/privacy")!)
                    Link("terms of service", destination: URL(string: "https://example.com/terms")!)
                }
                
                // 退出登录
                Section {
                    Button(action: {
                        viewModel.signOut()
                    }) {
                        HStack {
                            Spacer()
                            Text("Log out")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Setting")
            .onChange(of: defaultProjectionYears) { newValue in
                updateUserSettings(defaultProjectionYears: newValue)
            }
        }
    }
    
    private func getDefaultInvestmentName() -> String {
        guard let defaultInvestmentId = userSettings.defaultInvestmentId else {
            return "Not set"
        }
        
        return expenseAnalyzer.getInvestmentName(for: defaultInvestmentId)
    }
    
    private func updateUserSettings(
        defaultInvestmentId: String? = nil,
        defaultProjectionYears: Int? = nil,
        categoryPreferences: [String: Bool]? = nil
    ) {
        var newSettings = userSettings
        
        if let defaultInvestmentId = defaultInvestmentId {
            newSettings.defaultInvestmentId = defaultInvestmentId
        }
        
        if let defaultProjectionYears = defaultProjectionYears {
            newSettings.defaultProjectionYears = defaultProjectionYears
        }
        
        if let categoryPreferences = categoryPreferences {
            newSettings.categoryPreferences = categoryPreferences
        }
        
        viewModel.updateUserSettings(settings: newSettings)
    }
}

struct InvestmentPickerView: View {
    let investments: [Investment]
    let selectedInvestmentId: String?
    let onSelect: (String) -> Void
    
    var body: some View {
        NavigationView {
            List(investments) { investment in
                Button(action: {
                    onSelect(investment.id)
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(investment.name)
                                .font(.headline)
                            
                            Text("Average annual rate of return：\(String(format: "%.2f", investment.averageAnnualReturn))%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if investment.id == selectedInvestmentId {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("Select Default Investment")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    onSelect(selectedInvestmentId ?? "")
                }
            )
        }
    }
}

struct CategoryPreferencesView: View {
    let categoryPreferences: [String: Bool]
    let onUpdate: ([String: Bool]) -> Void
    
    @State private var preferences: [String: Bool] = [:]
    
    var body: some View {
        List {
            ForEach(ExpenseCategory.allCases, id: \.self) { category in
                Toggle(isOn: binding(for: category.rawValue)) {
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(preferences[category.rawValue] == true ? .green : .orange)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(category.rawValue)
                                .font(.headline)
                            
                            Text(preferences[category.rawValue] == true ? "Necessary expenditures": "Non-necessary expenditures")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))
            }
        }
        .navigationTitle("Expenditure classification preferences")
        .navigationBarItems(
            trailing: Button("Save") {
                onUpdate(preferences)
            }
        )
        .onAppear {
            // 初始化偏好设置
            var initialPreferences: [String: Bool] = [:]
            
            for category in ExpenseCategory.allCases {
                if let isNecessary = categoryPreferences[category.rawValue] {
                    initialPreferences[category.rawValue] = isNecessary
                } else {
                    initialPreferences[category.rawValue] = category.isTypicallyNecessary
                }
            }
            
            preferences = initialPreferences
        }
    }
    
    private func binding(for key: String) -> Binding<Bool> {
        return Binding(
            get: {
                return self.preferences[key] ?? false
            },
            set: {
                self.preferences[key] = $0
            }
        )
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = MainViewModel()
        SettingsView()
            .environmentObject(viewModel)
            .environmentObject(ExpenseAnalyzer(firebaseService: FirebaseService()))
    }
}
