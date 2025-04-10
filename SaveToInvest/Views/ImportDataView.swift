//
//  ImportDataView.swift
//  SaveToInvest
//
//  Created by Kesong Lin on 4/2/25.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

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
        guard !importedTransactions.isEmpty, let userId = viewModel.firebaseService.currentUser?.id else {
            return
        }
        
        isLoading = true
        importProgress = 0.0
        
        // Use batch processing
        processTransactionsInBatches(userId: userId)
    }
    
    // Helper method to process transactions in batches
    private func processTransactionsInBatches(userId: String) {
        DataImportService.shared.processInBatches(
            items: importedTransactions,
            batchSize: 10,
            process: { batch, completion in
                processBatch(batch: batch, userId: userId, completion: completion)
            },
            completion: handleBatchProcessingCompletion
        )
    }
    
    // Process a single batch of transactions
    private func processBatch(batch: [ImportedTransaction], userId: String, completion: @escaping (Bool) -> Void) {
        var successCount = 0
        
        for transaction in batch {
            // Use the category that was potentially edited by the user
            let category = transaction.suggestedCategory?.toExpenseCategory() ?? .other
            
            // Use the necessity that was potentially edited by the user
            let isNecessary = transaction.isNecessary ?? category.isTypicallyNecessary
            
            // Create expense object
            let expense = transaction.toExpense(
                userId: userId,
                category: category,
                isNecessary: isNecessary
            )
            
            // Save to Firebase
            viewModel.addExpense(
                title: expense.title,
                amount: expense.amount,
                date: expense.date,
                category: expense.category,
                isNecessary: expense.isNecessary,
                notes: expense.notes
            )
            
            successCount += 1
        }
        
        // Update progress
        DispatchQueue.main.async {
            let progress = Double(successCount) / Double(self.importedTransactions.count)
            self.importProgress = progress
        }
        
        completion(true)
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
