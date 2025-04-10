//
//  ImportDataView.swift
//  SaveToInvest
//
//  Created by Kesong Lin on 4/2/25.
//

import SwiftUI
import UIKit
// Note: No UniformTypeIdentifiers import

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
    
    // New state for transaction editing
    @State private var editingTransaction: ImportedTransaction? = nil
    @State private var showCategoryPicker = false
    
    // Use your existing enum with proper declaration
    enum ImportFileType: String, CaseIterable, Identifiable {
        case pdf = "PDF File"
        case csv = "CSV/Excel File"
        
        var id: String { self.rawValue }
        
        // Use string-based file type identifiers instead of UTType
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
            // Single header instead of duplicates
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
            // Use your existing document picker implementation
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
                        // Update the transaction category
                        if let index = importedTransactions.firstIndex(where: { $0.id == transaction.id }) {
                            importedTransactions[index].suggestedCategory = category
                            importedTransactions[index].isNecessary = isNecessary
                        }
                        showCategoryPicker = false
                    },
                    onCancel: {
                        showCategoryPicker = false
                    }
                )
            }
        }
    }
    
    // File selection view
    private var fileSelectionView: some View {
        VStack(spacing: 20) {
            // File type selection
            VStack(alignment: .leading, spacing: 10) {
                Text("Select Import File Type")
                    .font(.headline)
                
                ForEach(ImportFileType.allCases) { fileType in
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
            }
            .padding()
            
            Spacer()
            
            // Import instructions
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
            
            Spacer()
            
            // Select file button
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
            
            if isLoading {
                ProgressView("Processing file...")
                    .padding()
            }
        }
    }
    
    // Transaction preview view
    private var transactionPreviewView: some View {
        VStack(spacing: 0) {
            if importedTransactions.isEmpty {
                Spacer()
                Text("No recognizable transactions found")
                    .padding()
                Spacer()
            } else {
                // Transaction list with editing controls
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
                
                // Import button
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
    }
    
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
                    .foregroundColor(.white)
                
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
        
        init(transaction: ImportedTransaction, onSelect: @escaping (ImportCategory, Bool) -> Void, onCancel: @escaping () -> Void) {
            self.transaction = transaction
            self.onSelect = onSelect
            self.onCancel = onCancel
            
            // Initialize with current values
            _selectedCategory = State(initialValue: transaction.suggestedCategory ?? .other)
            _isNecessary = State(initialValue: transaction.isNecessary ?? selectedCategory.isTypicallyNecessary)
        }
        
        var body: some View {
            NavigationView {
                List {
                    Section(header: Text("Transaction")) {
                        Text(transaction.description)
                            .font(.headline)
                        
                        Text("$\(String(format: "%.2f", transaction.amount))")
                            .font(.subheadline)
                    }
                    
                    Section(header: Text("Is this a necessary expense?")) {
                        Toggle("Necessary Expense", isOn: $isNecessary)
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                    }
                    
                    Section(header: Text("Category")) {
                        ForEach(ImportCategory.allCases, id: \.self) { category in
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
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .navigationTitle("Edit Category")
                .navigationBarItems(
                    leading: Button("Cancel", action: onCancel),
                    trailing: Button("Save") {
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
            DataImportService.shared.importPDF(url: url) { result in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    switch result {
                    case .success(let transactions):
                        if transactions.isEmpty {
                            self.errorMessage = "No transaction data could be extracted from the file."
                            self.showError = true
                        } else {
                            self.importedTransactions = transactions
                            withAnimation {
                                self.currentStep = 2
                            }
                        }
                    case .failure(let error):
                        self.errorMessage = error.description
                        self.showError = true
                    }
                }
            }
        case .csv:
            DataImportService.shared.importCSV(url: url) { result in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    switch result {
                    case .success(let transactions):
                        if transactions.isEmpty {
                            self.errorMessage = "No transaction data could be extracted from the file."
                            self.showError = true
                        } else {
                            self.importedTransactions = transactions
                            withAnimation {
                                self.currentStep = 2
                            }
                        }
                    case .failure(let error):
                        self.errorMessage = error.description
                        self.showError = true
                    }
                }
            }
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
        }
    }
    
    // Import transactions
    private func importTransactions() {
        guard !importedTransactions.isEmpty, let userId = viewModel.firebaseService.currentUser?.id else {
            return
        }
        
        isLoading = true
        importProgress = 0.0
        
        // Use batch processing
        DataImportService.shared.processInBatches(
            items: importedTransactions,
            batchSize: 10
        ) { batch, completion in
            // Convert ImportedTransaction to Expense and save
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
                let progress = Double(successCount) / Double(importedTransactions.count)
                importProgress = progress
            }
            
            completion(true)
        } completion: { success in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    // Import complete, return to previous screen
                    presentationMode.wrappedValue.dismiss()
                } else {
                    errorMessage = "Some transactions failed to import."
                    showError = true
                }
            }
        }
    }
}

// MARK: - DocumentPickerView to replace missing DocumentPicker
struct DocumentPickerView: UIViewControllerRepresentable {
    let fileTypes: [String]
    let onPicked: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(documentTypes: fileTypes, in: .import)
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
