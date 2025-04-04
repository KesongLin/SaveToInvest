import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Combine

class FirebaseService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    // Change access level from private to internal (default)
    let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupAuthListener()
    }
    
    // MARK: - Authentication
    
    private func setupAuthListener() {
        Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }
            
            if let firebaseUser = firebaseUser {
                self.getUserData(userId: firebaseUser.uid) { user in
                    if let user = user {
                        self.currentUser = user
                        self.isAuthenticated = true
                    } else {
                        // 用户在Auth中存在但在Firestore中不存在，创建用户文档
                        let newUser = User(id: firebaseUser.uid, email: firebaseUser.email ?? "")
                        self.createUser(user: newUser) { success in
                            if success {
                                self.currentUser = newUser
                                self.isAuthenticated = true
                            }
                        }
                    }
                }
            } else {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            completion(error == nil, error)
        }
    }
    
    func signUp(email: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
            Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    print("Firebase Authentication Error: \(error.localizedDescription)")
                    // Print detailed error information
                    if let nsError = error as NSError? {
                        print("Error Code: \(nsError.code)")
                        print("Error Domain: \(nsError.domain)")
                        print("Error UserInfo: \(nsError.userInfo)")
                    }
                }
                completion(error == nil, error)
            }
        }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    // MARK: - User
    
    func getUserData(userId: String, completion: @escaping (User?) -> Void) {
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("Error getting user data: \(error)")
                completion(nil)
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists,
                  let data = snapshot.data() else {
                completion(nil)
                return
            }
            
            completion(User(dictionary: data))
        }
    }
    
    func createUser(user: User, completion: @escaping (Bool) -> Void) {
        db.collection("users").document(user.id).setData(user.dictionary) { error in
            if let error = error {
                print("Error creating user: \(error)")
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    func updateUser(user: User, completion: @escaping (Bool) -> Void) {
        db.collection("users").document(user.id).updateData(user.dictionary) { error in
            if let error = error {
                print("Error updating user: \(error)")
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    // MARK: - Expenses
    
    func getExpenses(userId: String, completion: @escaping ([Expense]) -> Void) {
        db.collection("expenses")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting expenses: \(error)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let expenses = documents.compactMap { Expense(dictionary: $0.data()) }
                completion(expenses)
            }
    }
    
    func streamExpenses(userId: String) -> AnyPublisher<[Expense], Never> {
        let subject = PassthroughSubject<[Expense], Never>()
        
        db.collection("expenses")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error streaming expenses: \(error)")
                    subject.send([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }
                
                let expenses = documents.compactMap { Expense(dictionary: $0.data()) }
                subject.send(expenses)
            }
        
        return subject.eraseToAnyPublisher()
    }
    

    func addExpense(expense: Expense, completion: @escaping (Bool) -> Void) {
        print("Starting to add expense to Firestore...")
        db.collection("expenses").document(expense.id).setData(expense.dictionary) { error in
            if let error = error {
                print("Error adding expense: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            // Rather than waiting for trackUserSpendingBehavior, complete immediately
            completion(true)
            
            // Then do the tracking separately - this ensures the UI doesn't wait
            self.trackUserSpendingBehavior(userId: expense.userId, expense: expense)
        }
    }
    
    func updateExpense(expense: Expense, completion: @escaping (Bool) -> Void) {
        db.collection("expenses").document(expense.id).updateData(expense.dictionary) { error in
            if let error = error {
                print("Error updating expense: \(error)")
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    func deleteExpense(expenseId: String, completion: @escaping (Bool) -> Void) {
        db.collection("expenses").document(expenseId).delete { error in
            if let error = error {
                print("Error deleting expense: \(error)")
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    // MARK: - Investments (Cloud-Managed)
    
    func getInvestments(completion: @escaping ([Investment]) -> Void) {
        db.collection("investments").getDocuments { snapshot, error in
            if let error = error {
                print("Error getting investments: \(error)")
                completion(Investment.defaultOptions)
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                // 如果没有投资数据，则使用默认选项
                self.setupDefaultInvestments { success in
                    if success {
                        self.getInvestments(completion: completion)
                    } else {
                        completion(Investment.defaultOptions)
                    }
                }
                return
            }
            
            let decoder = JSONDecoder()
            
            let investments = documents.compactMap { document -> Investment? in
                guard let jsonData = document.data()["data"] as? String,
                      let data = jsonData.data(using: .utf8) else {
                    return nil
                }
                
                do {
                    return try decoder.decode(Investment.self, from: data)
                } catch {
                    print("Error decoding investment: \(error)")
                    return nil
                }
            }
            
            completion(investments)
        }
    }
    
    private func setupDefaultInvestments(completion: @escaping (Bool) -> Void) {
        let encoder = JSONEncoder()
        let batch = db.batch()
        
        do {
            for investment in Investment.defaultOptions {
                let encodedData = try encoder.encode(investment)
                guard let jsonString = String(data: encodedData, encoding: .utf8) else {
                    continue
                }
                
                let docRef = db.collection("investments").document(investment.id)
                batch.setData(["data": jsonString], forDocument: docRef)
            }
            
            batch.commit { error in
                if let error = error {
                    print("Error setting up default investments: \(error)")
                    completion(false)
                    return
                }
                completion(true)
            }
        } catch {
            print("Error encoding investments: \(error)")
            completion(false)
        }
    }
    // MARK: - ML Related Methods
        
    func getExpenseClassifications(userId: String, completion: @escaping ([String: Bool]?) -> Void) {
        db.collection("users").document(userId).collection("expenseClassifications").getDocuments { snapshot, error in
            if let error = error {
                print("Error getting user expense classifications: \(error)")
                completion(nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(nil)
                return
            }
            
            var classifications: [String: Bool] = [:]
            
            for document in documents {
                if let title = document.data()["title"] as? String,
                   let isNecessary = document.data()["isNecessary"] as? Bool {
                    classifications[title] = isNecessary
                }
            }
            
            completion(classifications)
        }
    }

    func updateExpenseClassification(userId: String, expenseTitle: String, isNecessary: Bool) {
        let data: [String: Any] = [
            "title": expenseTitle,
            "isNecessary": isNecessary,
            "updatedAt": Timestamp(date: Date())
        ]
        
        db.collection("users").document(userId).collection("expenseClassifications").document(expenseTitle)
            .setData(data) { error in
                if let error = error {
                    print("Error updating expense classification: \(error)")
                }
            }
    }

    func getExpensesByDateRange(userId: String, startDate: Date, endDate: Date, completion: @escaping ([Expense]) -> Void) {
        db.collection("expenses")
            .whereField("userId", isEqualTo: userId)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("date", isLessThanOrEqualTo: Timestamp(date: endDate))
            .order(by: "date", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting expenses: \(error)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let expenses = documents.compactMap { Expense(dictionary: $0.data()) }
                completion(expenses)
            }
    }

    func updateUserSpendingInsights(userId: String, insights: [String: Any]) {
        db.collection("users").document(userId).collection("insights").document("spending")
            .setData(insights, merge: true) { error in
                if let error = error {
                    print("Error updating user spending insights: \(error)")
                }
            }
    }
}
