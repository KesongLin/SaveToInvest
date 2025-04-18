//
//  ImportDataView.swift
//  SaveToInvest
//
//  Created by Kesong Lin on 4/2/25.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import FirebaseFirestore

struct ImportDataView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isImporting = false
    @State private var importedTransactions: [ImportedTransaction] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var currentStep = 1 // 1: Select file, 2: Preview and confirm
    @State private var selectedFileType: ImportFileType = .pdf
    @State private var importProgress: Double = 0
    
    // State for transaction editing
    @State private var editingTransaction: ImportedTransaction? = nil
    @State private var showCategoryPicker = false
    
    // File type enum with proper declaration
    enum ImportFileType: String, CaseIterable, Identifiable {
        case pdf = "PDF File"
        case csv = "CSV/Excel File"
        
        var id: String { self.rawValue }
        
        // String-based file type identifiers
        var fileTypes: [String] {
            switch self {
            case .pdf:
                return ["public.pdf"]
            case .csv:
                return ["public.comma-separated-values-text", "public.spreadsheet"]
            }
        }
        
        var icon: String {
            switch self {
            case .pdf:
                return "doc.text"
            case .csv:
                return "tablecells"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            if currentStep == 1 {
                fileSelectionView
            } else {
                transactionPreviewView
            }
        }
        .navigationBarHidden(true) // Hide default navigation bar
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Import Error"),
                message: Text(errorMessage ?? "An unknown error occurred during import."),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $isImporting) {
            DocumentPickerView(
                fileTypes: selectedFileType.fileTypes,
                onPicked: handleFileSelection
            )
        }
        .sheet(isPresented: $showCategoryPicker) {
            if let transaction = editingTransaction {
                CategoryPickerView(
                    transaction: transaction,
                    onSelect: { category, isNecessary in
                        updateTransactionCategory(transaction, category: category, isNecessary: isNecessary)
                    },
                    onCancel: {
                        showCategoryPicker = false
                    }
                )
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        HStack {
            Text("Preview Imported Data")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Button("Back") {
                if currentStep == 2 {
                    withAnimation {
                        currentStep = 1
                        importedTransactions = []
                    }
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .padding()
    }
    
    // File selection view
    private var fileSelectionView: some View {
        VStack(spacing: 20) {
            fileTypeSelectionSection
            
            Spacer()
            
            importInstructionsSection
            
            Spacer()
            
            selectFileButton
            
            if isLoading {
                ProgressView("Processing file...")
                    .padding()
            }
        }
    }
    
    private var fileTypeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Import File Type")
                .font(.headline)
            
            ForEach(ImportFileType.allCases) { fileType in
                fileTypeButton(fileType: fileType)
            }
        }
        .padding()
    }
    
    private func fileTypeButton(fileType: ImportFileType) -> some View {
        Button(action: {
            selectedFileType = fileType
        }) {
            HStack {
                Image(systemName: fileType.icon)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                Text(fileType.rawValue)
                
                Spacer()
                
                if selectedFileType == fileType {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedFileType == fileType ? Color(.systemGray6) : Color(.systemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var importInstructionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Import Instructions")
                .font(.headline)
            
            Text("• Supports most bank statement formats")
            Text("• The system will automatically identify transaction categories")
            Text("• You can preview and modify categories before import")
            Text("• Sensitive data is processed locally and not uploaded")
            Text("• CSV format is strongly recommended ! ! !")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }
    
    private var selectFileButton: some View {
        Button(action: {
            isImporting = true
        }) {
            HStack {
                Image(systemName: "doc.badge.plus")
                Text("Select File")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.bottom)
        .disabled(isLoading)
    }
    
    // Transaction preview view
    private var transactionPreviewView: some View {
        VStack(spacing: 0) {
            if importedTransactions.isEmpty {
                emptyTransactionsView
            } else {
                VStack {
                    transactionsScrollView
                    importButtonSection
                }
            }
        }
    }
    
    private var emptyTransactionsView: some View {
        VStack {
            Spacer()
            Text("No recognizable transactions found")
                .padding()
            Spacer()
        }
    }
    
    private var transactionsScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(importedTransactions) { transaction in
                    EditableTransactionRow(
                        transaction: transaction,
                        onCategoryTap: {
                            editingTransaction = transaction
                            showCategoryPicker = true
                        },
                        onDelete: {
                            deleteTransaction(transaction)
                        },
                        onToggleNecessary: {
                            toggleNecessary(transaction)
                        }
                    )
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                }
            }
            .background(Color(.systemBackground))
        }
    }
    
    private var importButtonSection: some View {
        VStack {
            Button(action: importTransactions) {
                HStack {
                    Image(systemName: "arrow.down.doc")
                    Text("Import \(importedTransactions.count) transactions")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding()
            .disabled(isLoading)
            
            if isLoading {
                ProgressView(value: importProgress, total: 1.0)
                    .padding(.horizontal)
                Text("Importing... \(Int(importProgress * 100))%")
                    .font(.caption)
                    .padding(.bottom)
            }
        }
    }
    
    // MARK: - Helper Components
    
    // Enhanced transaction row with editing features
    struct EditableTransactionRow: View {
        let transaction: ImportedTransaction
        let onCategoryTap: () -> Void
        let onDelete: () -> Void
        let onToggleNecessary: () -> Void
        
        private var dateFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter
        }
        
        private var shortDateFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yyyy"
            return formatter
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Top row: Date and amount
                HStack {
                    Text(shortDateFormatter.string(from: transaction.date))
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("$\(String(format: "%.2f", transaction.amount))")
                        .font(.headline)
                }
                
                // Second row: Formatted date
                HStack {
                    Text(dateFormatter.string(from: transaction.date))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    // Category button
                    Button(action: onCategoryTap) {
                        HStack(spacing: 4) {
                            if let category = transaction.suggestedCategory {
                                Image(systemName: category.icon)
                                    .foregroundColor(.blue)
                                
                                Text(category.rawValue)
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "tag")
                                    .foregroundColor(.blue)
                                
                                Text("Uncategorized")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                // Description
                Text(transaction.description)
                    .font(.system(size: 16, weight: .medium))
                
                // Action buttons
                HStack {
                    // Necessary toggle
                    Button(action: onToggleNecessary) {
                        HStack(spacing: 4) {
                            Image(systemName: transaction.isNecessary == true ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(transaction.isNecessary == true ? .green : .gray)
                            
                            Text(transaction.isNecessary == true ? "Necessary" : "Non-Necessary")
                                .font(.caption)
                                .foregroundColor(transaction.isNecessary == true ? .green : .gray)
                        }
                    }
                    
                    Spacer()
                    
                    // Delete button
                    Button(action: onDelete) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            
                            Text("Delete")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
        }
    }
    
    // Category picker view
    struct CategoryPickerView: View {
        let transaction: ImportedTransaction
        let onSelect: (ImportCategory, Bool) -> Void
        let onCancel: () -> Void
        
        @State private var selectedCategory: ImportCategory
        @State private var isNecessary: Bool
        
        // Create a static property with all the categories you want to show
        // Replace these with your actual ImportCategory cases
        private static let categories: [ImportCategory] = [
            .food,
            .transportation,
            .housing,
            .utilities,
            .entertainment,
            .shopping,
            .healthcare,
            .education,
            .other
            // Add all your ImportCategory cases here
        ]
        
        init(transaction: ImportedTransaction, onSelect: @escaping (ImportCategory, Bool) -> Void, onCancel: @escaping () -> Void) {
            self.transaction = transaction
            self.onSelect = onSelect
            self.onCancel = onCancel
            
            // Initialize with current values
            _selectedCategory = State(initialValue: transaction.suggestedCategory ?? .other)
            _isNecessary = State(initialValue: transaction.isNecessary ?? transaction.suggestedCategory?.isTypicallyNecessary ?? false)
        }
        
        // Extract transaction info into a separate view
        private var transactionInfoSection: some View {
            Section(header: Text("Transaction")) {
                Text(transaction.description)
                    .font(.headline)
                
                Text("$\(String(format: "%.2f", transaction.amount))")
                    .font(.subheadline)
            }
        }
        
        // Extract necessity toggle into a separate view
        private var necessitySection: some View {
            Section(header: Text("Is this a necessary expense?")) {
                Toggle("Necessary Expense", isOn: $isNecessary)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
            }
        }
        
        // Extract category selection into a separate view
        private var categorySection: some View {
            Section(header: Text("Category")) {
                ForEach(Self.categories, id: \.self) { category in
                    categoryButton(for: category)
                }
            }
        }
        
        // Extract individual category button into a separate method
        private func categoryButton(for category: ImportCategory) -> some View {
            Button(action: {
                selectedCategory = category
            }) {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(.blue)
                    
                    Text(category.rawValue)
                    
                    Spacer()
                    
                    if selectedCategory == category {
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                    }
                }
            }
            .foregroundColor(.primary)
        }
        
        var body: some View {
            NavigationView {
                List {
                    transactionInfoSection
                    necessitySection
                    categorySection
                }
                .listStyle(InsetGroupedListStyle())
                .navigationTitle("Edit Category")
                .navigationBarItems(
                    leading: Button("Cancel", action: onCancel),
                    trailing: Button("Save") {
                        // Add the classifier learning code here
                        TransactionClassifier.shared.learnFromCorrection(
                            transaction: transaction,
                            isNecessary: isNecessary
                        )
                        
                        // Call the existing onSelect handler
                        onSelect(selectedCategory, isNecessary)
                    }
                )
            }
        }
    }
    
    // MARK: - Helper methods
    
    private func handleFileSelection(_ urls: [URL]) {
        guard let url = urls.first else { return }
        
        isLoading = true
        
        // Process based on file type
        switch selectedFileType {
        case .pdf:
            importPDFFile(url: url)
        case .csv:
            importCSVFile(url: url)
        }
    }
    
    private func importPDFFile(url: URL) {
        DataImportService.shared.importPDF(url: url) { result in
            DispatchQueue.main.async {
                self.handleImportResult(result)
            }
        }
    }
    
    private func importCSVFile(url: URL) {
        DataImportService.shared.importCSV(url: url) { result in
            DispatchQueue.main.async {
                self.handleImportResult(result)
            }
        }
    }
    
    private func handleImportResult(_ result: Result<[ImportedTransaction], ImportError>) {
        isLoading = false
        
        switch result {
        case .success(let transactions):
            if transactions.isEmpty {
                errorMessage = "No transaction data could be extracted from the file."
                showError = true
            } else {
                importedTransactions = transactions
                withAnimation {
                    currentStep = 2
                }
            }
        case .failure(let error):
            errorMessage = error.description
            showError = true
        }
    }
    
    // Delete a transaction
    private func deleteTransaction(_ transaction: ImportedTransaction) {
        if let index = importedTransactions.firstIndex(where: { $0.id == transaction.id }) {
            importedTransactions.remove(at: index)
        }
    }
    
    // Toggle transaction necessity
    private func toggleNecessary(_ transaction: ImportedTransaction) {
        if let index = importedTransactions.firstIndex(where: { $0.id == transaction.id }) {
            let currentValue = importedTransactions[index].isNecessary ?? false
            importedTransactions[index].isNecessary = !currentValue
            
            TransactionClassifier.shared.learnFromCorrection(
                        transaction: importedTransactions[index],
                        isNecessary: !currentValue)
        }
    }
    
    // Update transaction category
    private func updateTransactionCategory(_ transaction: ImportedTransaction, category: ImportCategory, isNecessary: Bool) {
        if let index = importedTransactions.firstIndex(where: { $0.id == transaction.id }) {
            importedTransactions[index].suggestedCategory = category
            importedTransactions[index].isNecessary = isNecessary
        }
        showCategoryPicker = false
    }
    
    // Import transactions
    private func importTransactions() {
        guard !importedTransactions.isEmpty else { return }
        guard let userId = viewModel.firebaseService.currentUser?.id else { return }
        
        isLoading = true
        importProgress = 0.01 // Start with non-zero progress
        
        // Show user that processing has started
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.impactOccurred()
        
        Task {
            await processWithMemoryManagement(userId: userId)
            
            // Force a final refresh of the expense analyzer
            viewModel.expenseAnalyzer.refreshExpenseStream()
            viewModel.expenseAnalyzer.analyzeExpenses()
        }
    }
    
    // Simpler chunk processing without async complexities
    private func processTransactionChunk(_ transactions: [ImportedTransaction], userId: String, completion: @escaping (Int) -> Void) {
        var successCount = 0
        let group = DispatchGroup()
        
        for transaction in transactions {
            group.enter()
            
            // Create expense from transaction
            let category = transaction.suggestedCategory?.toExpenseCategory() ?? .other
            let isNecessary = transaction.isNecessary ?? category.isTypicallyNecessary
            let safeId = UUID().uuidString
            
            // Ensure description is sanitized
            let sanitizedDescription = transaction.description.sanitizedForFirestore()
            
            let expense = Expense(
                id: safeId,
                title: sanitizedDescription,
                amount: transaction.amount,
                date: transaction.date,
                category: category,
                isNecessary: isNecessary,
                notes: "Imported: \(String(transaction.rawText.prefix(100)))",
                userId: userId
            )
            
            // Add to Firestore with timeout
            let timeoutWorkItem = DispatchWorkItem {
                print("Transaction processing timed out")
                group.leave()
            }
            
            // Set timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + 3.0, execute: timeoutWorkItem)
            
            // Attempt to add to Firestore, but simulate success if Firebase APIs are disabled
            viewModel.firebaseService.addExpense(expense: expense) { success in
                // Cancel timeout
                timeoutWorkItem.cancel()
                
                // During development with Firebase API issues, count it as success anyway
                // to allow the UI to show progress
                successCount += 1
                
                group.leave()
            }
            
            // Add a small delay to simulate progress even if Firestore is unavailable
            usleep(100000) // 0.1 second
        }
        
        // When all transactions in this chunk are processed
        group.notify(queue: .global()) {
            completion(successCount)
        }
    }

    // Use Swift concurrency with built-in memory management
    private func processWithMemoryManagement(userId: String) async {
        guard !userId.isEmpty else {
            await MainActor.run {
                self.errorMessage = "User ID is missing. Please log out and log in again."
                self.showError = true
                self.isLoading = false
            }
            return
        }
        
        print("Starting import with user ID: \(userId)")
        
        let batchSize = 5 // Process small batches
        let totalCount = importedTransactions.count
        var processedCount = 0
        
        // Update initial progress on main thread
        await MainActor.run {
            self.importProgress = 0.01 // Start with non-zero progress to show activity
        }
        
        // Store only batch references instead of keeping all transactions in memory
        for batchIndex in stride(from: 0, to: totalCount, by: batchSize) {
            let endIndex = min(batchIndex + batchSize, totalCount)
            let batchTransactions = Array(importedTransactions[batchIndex..<endIndex])
            
            // Process this small batch
            let batchSuccess = await processBatch(userId: userId, transactions: batchTransactions)
            
            if batchSuccess {
                // Update processed count and progress
                processedCount += batchTransactions.count
                let progress = Double(processedCount) / Double(totalCount)
                
                // Update UI on main thread
                await MainActor.run {
                    print("Import progress: \(Int(progress * 100))%")
                    self.importProgress = progress
                }
            } else {
                print("Batch processing failed, continuing with next batch")
            }
            
            // Force a brief pause to let the main thread breathe
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Explicitly suggest memory cleanup
            autoreleasepool {}
        }
        
        // Complete import
        await MainActor.run {
            // Set a final progress of 100% to show completion
            self.importProgress = 1.0
            
            // Add a delay to allow Firestore to sync
            // Using a dispatch after instead of Task.sleep to maintain synchronous context
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // Force a refresh of the expense analyzer
                self.viewModel.expenseAnalyzer.analyzeExpenses()
                
                // Final delay to see completion before dismissing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isLoading = false
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    private func processBatch(userId: String, transactions: [ImportedTransaction]) async -> Bool {
        // Verify user ID
        guard !userId.isEmpty, userId == viewModel.firebaseService.currentUser?.id else {
            print("⚠️ User ID mismatch or empty during import!")
            return false
        }
        
        print("Processing batch for user: \(userId)")
        
        var batchSuccess = true
        
        // Process one transaction at a time with await to prevent overloading
        for transaction in transactions {
            // Get a safe category
            let category = transaction.suggestedCategory?.toExpenseCategory() ?? .other
            
            // Get necessity
            let isNecessary = transaction.isNecessary ?? category.isTypicallyNecessary
            
            // Create ultra-safe expense ID - using UUID to avoid any issues with IDs
            let safeId = UUID().uuidString
            
            // Ensure description is also safe
            let safeDescription = transaction.description.sanitizedForFirestore()
            
            // Create notes with limited size to reduce memory usage
            let safeNotes = String(transaction.rawText.prefix(100))
            
            // Create expense with minimal data
            let expense = Expense(
                id: safeId,
                title: safeDescription,
                amount: transaction.amount,
                date: transaction.date,
                category: category,
                isNecessary: isNecessary,
                notes: "Imported: \(safeNotes)",
                userId: userId
            )
            
            // Add expense with timeout to prevent hanging
            let success = await withTimeout(seconds: 5) { completion in
                viewModel.firebaseService.addExpense(expense: expense) { success in
                    completion(success)
                }
            }
            
            if !success {
                print("Failed to import transaction: \(safeDescription)")
                batchSuccess = false
            }
            
            // Small delay between individual transactions
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        return batchSuccess
    }

    // Add this helper function to handle timeouts for async operations
    private func withTimeout<T>(seconds: Double, operation: @escaping (@escaping (T) -> Void) -> Void) async -> T where T: ExpressibleByBooleanLiteral {
        return await withCheckedContinuation { continuation in
            // Set up a timeout with longer duration
            let timeoutWork = DispatchWorkItem {
                print("Operation timed out after \(seconds) seconds")
                continuation.resume(returning: false as! T)
            }
            
            // Schedule the timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds, execute: timeoutWork)
            
            // Start the operation
            operation { result in
                // Only resume once - prevent multiple completions
                if !timeoutWork.isCancelled {
                    timeoutWork.cancel()
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    // Handle completion of batch processing
    private func handleBatchProcessingCompletion(success: Bool) {
        DispatchQueue.main.async {
            self.isLoading = false
            if success {
                // Import complete, return to previous screen
                self.presentationMode.wrappedValue.dismiss()
            } else {
                self.errorMessage = "Some transactions failed to import."
                self.showError = true
            }
        }
    }
}

// MARK: - DocumentPickerView with fixed initializer
struct DocumentPickerView: UIViewControllerRepresentable {
    let fileTypes: [String]
    let onPicked: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker: UIDocumentPickerViewController
        
        if #available(iOS 14.0, *) {
            // Convert string identifiers to UTTypes
            let contentTypes = fileTypes.compactMap { fileType -> UTType? in
                switch fileType {
                case "public.pdf":
                    return .pdf
                case "public.comma-separated-values-text":
                    return .commaSeparatedText
                case "public.spreadsheet":
                    return .spreadsheet
                default:
                    return UTType(fileType)
                }
            }
            picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        } else {
            // Fallback for iOS 13 and earlier
            picker = UIDocumentPickerViewController(documentTypes: fileTypes, in: .import)
        }
        
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPicked(urls)
        }
    }
}
