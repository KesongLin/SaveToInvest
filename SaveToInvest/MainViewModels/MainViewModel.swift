import Foundation
import Combine

class MainViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    let firebaseService: FirebaseService
    let expenseAnalyzer: ExpenseAnalyzer
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.firebaseService = FirebaseService()
        self.expenseAnalyzer = ExpenseAnalyzer(firebaseService: firebaseService)
        
        setupBindings()
    }
    
    private func setupBindings() {
        // 监听认证状态变化
        firebaseService.$isAuthenticated
            .sink { [weak self] _ in
                self?.isLoading = false
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Authentication
    
    func signIn(email: String, password: String) {
        isLoading = true
        
        firebaseService.signIn(email: email, password: password) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if !success, let error = error {
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                }
            }
        }
    }
    
    func signUp(email: String, password: String) {
        isLoading = true
        
        firebaseService.signUp(email: email, password: password) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if !success, let error = error {
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                }
            }
        }
    }
    
    func signOut() {
        firebaseService.signOut()
    }
    
    // MARK: - Expense Management
    
    func updateExpense(_ expense: Expense) {
        isLoading = true
        
        firebaseService.updateExpense(expense: expense) { [weak self] success in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if !success {
                    self?.errorMessage = "Failed to update expense"
                    self?.showError = true
                }
            }
        }
    }
    
    func deleteExpense(id: String) {
        isLoading = true
        
        firebaseService.deleteExpense(expenseId: id) { [weak self] success in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if !success {
                    self?.errorMessage = "Failed to delete expense"
                    self?.showError = true
                }
            }
        }
    }
    
    // MARK: - User Settings
    
    func updateUserSettings(settings: UserSettings) {
        guard var user = firebaseService.currentUser else { return }
        
        isLoading = true
        
        user.settings = settings
        
        firebaseService.updateUser(user: user) { [weak self] success in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if !success {
                    self?.errorMessage = "Failed to update settings"
                    self?.showError = true
                }
            }
        }
    }
}
