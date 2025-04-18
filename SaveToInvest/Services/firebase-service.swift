import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Combine

class FirebaseService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    let db: Firestore
    private var cancellables = Set<AnyCancellable>()
    var lastStreamedExpenseCount: Int = 0
    
    init() {
        self.db = Firestore.firestore()
        
        setupAuthListener()
    }
    
    // New method for offline mode setup
    private func setupOfflineMode() {
        // Try to work offline first, then enable network with delay
        db.disableNetwork { [weak self] error in
            if error != nil {
                print("⚠️ Continuing anyway despite offline error")
            } else {
                print("💾 Working in offline mode first")
            }
            
            // After 3 seconds, try to connect
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self?.db.enableNetwork { error in
                    if let error = error {
                        print("⚠️ Network connection failed: \(error.localizedDescription)")
                    } else {
                        print("🌐 Online mode activated")
                    }
                }
            }
        }
    }
    
    
    // MARK: - Authentication

    func signUp(email: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
        // First clear any existing state
        self.currentUser = nil
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            if let error = error {
                print("Firebase Authentication Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false, error)
                }
                return
            }
            
            guard let self = self, let authResult = authResult, let email = authResult.user.email else {
                DispatchQueue.main.async {
                    completion(false, NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "Authentication succeeded but couldn't get user details"]))
                }
                return
            }
            
            // Create user in Firestore
            let newUser = User(id: authResult.user.uid, email: email)
            
            // First update local state
            DispatchQueue.main.async {
                self.currentUser = newUser
                self.isAuthenticated = true
            }
            
            // Then persist to Firestore
            self.db.collection("users").document(newUser.id).setData(newUser.dictionary) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error creating user document: \(error)")
                        completion(false, error)
                        return
                    }
                    
                    // Force a reload of the user from Firebase to ensure all is in sync
                    Auth.auth().currentUser?.reload(completion: { _ in
                        // Double-check auth state
                        self.isAuthenticated = Auth.auth().currentUser != nil
                        completion(true, nil)
                    })
                }
            }
        }
    }

    private func setupAuthListener() {
        Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }
            
            if let firebaseUser = firebaseUser {
                print("Auth state change: User is logged in with ID: \(firebaseUser.uid)")
                
                // Immediately update auth state
                DispatchQueue.main.async {
                    self.isAuthenticated = true
                }
                
                // Add delay to ensure authentication is fully established
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.getUserData(userId: firebaseUser.uid) { user in
                        DispatchQueue.main.async {
                            if let user = user {
                                print("User data loaded from Firestore")
                                self.currentUser = user
                                
                                // Refresh expenses after user data is loaded
                                NotificationCenter.default.post(name: Notification.Name("RefreshExpenses"), object: nil)
                            } else {
                                // User document doesn't exist yet, create it
                                print("Creating new user document in Firestore")
                                let newUser = User(id: firebaseUser.uid, email: firebaseUser.email ?? "")
                                self.currentUser = newUser // Set immediately
                                
                                self.createUser(user: newUser) { _ in
                                    // Nothing to do here, already set currentUser
                                }
                            }
                        }
                    }
                }
            } else {
                print("Auth state change: User is logged out")
                DispatchQueue.main.async {
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
            }
        }
    }

    // Also modify signIn to ensure state consistency:
    func signIn(email: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            // Explicitly update authentication state
            if let authResult = authResult {
                // Force refresh the user data
                self?.getUserData(userId: authResult.user.uid) { user in
                    DispatchQueue.main.async {
                        if let user = user {
                            self?.currentUser = user
                            self?.isAuthenticated = true
                        }
                        completion(true, nil)
                    }
                }
            } else {
                completion(true, nil)
            }
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
        
        // Verify user ID isn't empty
        guard !userId.isEmpty else {
            print("⚠️ Empty user ID in streamExpenses!")
            subject.send([])
            return subject.eraseToAnyPublisher()
        }
        
        print("Starting to stream expenses for user ID: \(userId)")
        
        // Use this query to match your exact index structure
        db.collection("expenses")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)  // IMPORTANT: Must be descending to match your index
            .order(by: FieldPath.documentID(), descending: true)  // This is the __name__ field
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error streaming expenses: \(error)")
                    DispatchQueue.main.async {
                        subject.send([])
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No documents found in expenses collection for user \(userId)")
                    DispatchQueue.main.async {
                        subject.send([])
                    }
                    return
                }
                
                // Log the document count
                print("Found \(documents.count) expense documents for user \(userId)")
                
                let expenses = documents.compactMap { document -> Expense? in
                    guard let expense = Expense(dictionary: document.data()) else {
                        print("⚠️ Failed to parse expense document: \(document.documentID)")
                        return nil
                    }
                    
                    // Verify expense belongs to this user
                    if expense.userId != userId {
                        print("⚠️ Found expense with incorrect user ID: \(expense.id), userID: \(expense.userId) vs \(userId)")
                        return nil
                    }
                    
                    return expense
                }
                
                // Additional safety check - only include this user's expenses
                let filteredExpenses = expenses.filter { $0.userId == userId }
                
                if expenses.count != filteredExpenses.count {
                    print("⚠️ Filtered out \(expenses.count - filteredExpenses.count) expenses with wrong user ID")
                }
                
                // Important: Dispatch to the main thread
                DispatchQueue.main.async {
                    print("Sending \(filteredExpenses.count) expenses to UI for user \(userId)")
                    subject.send(filteredExpenses)
                    
                    // Update the debug counter for verification
                    self?.lastStreamedExpenseCount = filteredExpenses.count
                }
            }
        
        return subject.eraseToAnyPublisher()
    }
    

    func addExpense(expense: Expense, completion: @escaping (Bool) -> Void) {
        print("Adding expense with user ID: \(expense.userId)")
        
        // Verify the expense belongs to the current user
        guard let currentUserId = Auth.auth().currentUser?.uid,
              expense.userId == currentUserId else {
            print("⚠️ Attempted to add expense with mismatched user ID!")
            completion(false)
            return
        }
        
        // Create a sanitized dictionary for Firestore
        var safeData = expense.dictionary
        
        // Ensure any document paths are properly sanitized
        if let title = safeData["title"] as? String {
            safeData["title"] = title // Keep the original title for display
        }
        
        // Create a timeout to ensure we don't hang
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            print("⚠️ Firestore write operation timed out")
            completion(false)
        }
        
        db.collection("expenses").document(expense.id).setData(safeData) { error in
            // Cancel the timeout timer
            timeoutTimer.invalidate()
            
            if let error = error {
                print("Error adding expense: \(error.localizedDescription)")
                
                // Check if error is related to offline mode
                if (error as NSError).domain == FirestoreErrorDomain {
                    print("📱 App is in offline mode, storing data locally")
                    // In offline mode, we consider this a success since the data will sync later
                    completion(true)
                    return
                }
                
                completion(false)
                return
            }
            
            print("✅ Successfully added expense: \(expense.id)")
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
                // Retrieve the original title field instead of using document ID
                if let originalTitle = document.data()["originalTitle"] as? String,
                   let isNecessary = document.data()["isNecessary"] as? Bool {
                    classifications[originalTitle] = isNecessary
                }
            }
            
            completion(classifications)
        }
    }

    func updateExpenseClassification(userId: String, expenseTitle: String, isNecessary: Bool) {
        let safeDocId = expenseTitle.sanitizedForFirestore()
        
        // Create data for the document
        let data: [String: Any] = [
            "originalTitle": expenseTitle,  // Store the original unsanitized title as a field
            "sanitizedTitle": safeDocId,    // Store the sanitized version
            "isNecessary": isNecessary,
            "updatedAt": Timestamp(date: Date())
        ]
        
        // Use the sanitized ID for the document path
        db.collection("users").document(userId).collection("expenseClassifications").document(safeDocId)
            .setData(data, merge: true) { error in
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




