//
//  ImportDataView.swift
//  SaveToInvest
//
//  Created by Kesong Lin on 4/2/25.
//

import SwiftUI
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
    
    enum ImportFileType: String, CaseIterable, Identifiable {
        case pdf = "PDF File"
        case csv = "CSV/Excel File"
        
        var id: String { self.rawValue }
        
        var fileTypes: [UTType] {
            switch self {
            case .pdf:
                return [.pdf]
            case .csv:
                return [.commaSeparatedText, .spreadsheet]
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
        VStack {
            // 顶部标题
            HStack {
                Text(currentStep == 1 ? "Import Bank Statement" : "Preview Imported Data")
                    .font(.headline)
                    .padding()
                
                Spacer()
                
                if currentStep == 2 {
                    Button("Back") {
                        withAnimation {
                            currentStep = 1
                            importedTransactions = []
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            if currentStep == 1 {
                fileSelectionView
            } else {
                transactionPreviewView
            }
        }
        .navigationTitle("Import Data")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Import Error"),
                message: Text(errorMessage ?? "An unknown error occurred during import."),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $isImporting) {
            DocumentPicker(
                fileTypes: selectedFileType.fileTypes,
                onPicked: handleFileSelection
            )
        }
    }
    
    // 文件选择视图
    private var fileSelectionView: some View {
        VStack(spacing: 20) {
            // 文件类型选择
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
            
            // 导入说明
            VStack(alignment: .leading, spacing: 10) {
                Text("Import Instructions")
                    .font(.headline)
                
                Text("• Supports most bank statement formats")
                Text("• The system will automatically attempt to identify transaction categories")
                Text("• You can preview and modify categories after import")
                Text("• Sensitive data is processed locally and not uploaded")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding()
            
            Spacer()
            
            // 选择文件按钮
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
    
    // 交易预览视图
    private var transactionPreviewView: some View {
        VStack(spacing: 0) {
            // Navigation bar replacement
            HStack {
                Text("Preview Imported Data")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Back") {
                    withAnimation {
                        currentStep = 1
                    }
                }
            }
            .padding()
            
            if importedTransactions.isEmpty {
                Spacer()
                Text("No recognizable transactions found")
                    .padding()
                Spacer()
            } else {
                // List of transactions with your desired format
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(importedTransactions) { transaction in
                            VStack(alignment: .leading, spacing: 4) {
                                // Top row: date and amount
                                HStack {
                                    // Format date as MM/DD/YYYY
                                    Text(formatDate(transaction.date, format: "MM/dd/yyyy"))
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    // Amount
                                    Text("$\(String(format: "%.2f", transaction.amount))")
                                        .font(.headline)
                                }
                                
                                // Second row: formatted date and description
                                HStack {
                                    // Full month name date
                                    Text(formatDate(transaction.date, format: "MMM d, yyyy"))
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    
                                    Spacer()
                                    
                                    // Category with icon
                                    if let category = transaction.suggestedCategory {
                                        HStack(spacing: 4) {
                                            Image(systemName: category.icon)
                                                .foregroundColor(.blue)
                                            
                                            Text(category.rawValue)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                
                                // Add the actual description/name of the transaction
                                Text(transaction.description)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                    .padding(.top, 8)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                    }
                }
                .background(Color(.systemGray6))
                
                // Import button - match the style in your screenshot
                Button(action: importTransactions) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import \(importedTransactions.count) transactions")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding()
                }
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

    // Helper function for date formatting
    private func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    // 处理文件选择
    private func handleFileSelection(_ urls: [URL]) {
        guard let url = urls.first else { return }
        
        isLoading = true
        
        // 根据文件类型处理
        switch selectedFileType {
        case .pdf:
            DataImportService.shared.importPDF(url: url) { result in
                handleImportResult(result)
            }
        case .csv:
            DataImportService.shared.importCSV(url: url) { result in
                handleImportResult(result)
            }
        }
    }
    
    // 处理导入结果
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
    
    // Helper function to convert ImportCategory to ExpenseCategory
    private func convertToExpenseCategory(_ importCategory: ImportCategory?) -> ExpenseCategory {
        guard let importCategory = importCategory else {
            return .other
        }
        
        switch importCategory {
        case .food:
            return .food
        case .dining:
            return .food  // Map dining to food category
        case .housing:
            return .housing
        case .transportation:
            return .transportation
        case .entertainment:
            return .entertainment
        case .utilities:
            return .utilities
        case .healthcare:
            return .healthcare
        case .insurance:
            return .healthcare  // Map insurance to healthcare
        case .shopping:
            return .shopping
        case .education:
            return .education
        case .travel:
            return .travel
        case .subscription:
            return .entertainment  // Map subscription to entertainment
        case .fitness:
            return .healthcare  // Map fitness to healthcare
        case .books:
            return .education  // Map books to education
        case .electronics:
            return .shopping  // Map electronics to shopping
        case .gaming:
            return .entertainment  // Map gaming to entertainment
        case .other:
            return .other
        }
    }
    
    // 执行交易导入
    private func importTransactions() {
        guard !importedTransactions.isEmpty, let userId = viewModel.firebaseService.currentUser?.id else {
            return
        }
        
        isLoading = true
        importProgress = 0.0
        
        // 使用批处理导入
        DataImportService.shared.processInBatches(
            items: importedTransactions,
            batchSize: 10
        ) { batch, completion in
            // 将ImportedTransaction转换为Expense并保存
            var successCount = 0
            
            for transaction in batch {
                // Get the import category
                let importCategory = transaction.suggestedCategory ?? .other
                
                // Convert to expense category
                let expenseCategory = convertToExpenseCategory(importCategory)
                
                // Use the converted category
                let expense = transaction.toExpense(
                    userId: userId,
                    category: expenseCategory,
                    isNecessary: importCategory.isTypicallyNecessary
                )
                
                // 保存到Firebase
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
            
            // 更新进度
            DispatchQueue.main.async {
                let progress = Double(successCount) / Double(importedTransactions.count)
                importProgress = progress
            }
            
            completion(true)
        } completion: { success in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    // 导入完成，返回上一页
                    self.presentationMode.wrappedValue.dismiss()
                } else {
                    errorMessage = "Some transactions failed to import."
                    showError = true
                }
            }
        }
    }
}


struct TransactionPreviewRow: View {
    let transaction: ImportedTransaction
    
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
        VStack(alignment: .leading, spacing: 4) {
            // Main row with description and amount
            HStack {
                // Left side: Description as primary focus
                VStack(alignment: .leading, spacing: 4) {
                    // Main transaction description
                    Text(transaction.description)
                        .font(.headline)
                        .lineLimit(1)
                    
                    // Date below in smaller text
                    Text(dateFormatter.string(from: transaction.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Right side: Amount and category
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(String(format: "%.2f", abs(transaction.amount)))")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let category = transaction.suggestedCategory {
                        HStack {
                            Text(category.rawValue)
                                .font(.caption)
                            
                            Image(systemName: category.icon)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let fileTypes: [UTType]
    let onPicked: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: fileTypes)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPicked(urls)
        }
    }
}

