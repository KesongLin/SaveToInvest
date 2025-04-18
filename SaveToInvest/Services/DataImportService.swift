//
//  DataImportService.swift
//  SaveToInvest
//
//  Created by Kesong Lin on 4/2/25.
//

import Foundation
import UIKit
import PDFKit
import SwiftCSV
import FirebaseFirestore 

// Define import error types
enum ImportError: Error {
    case fileNotSupported
    case fileReadError
    case parsingError
    case emptyData
    
    var description: String {
        switch self {
        case .fileNotSupported:
            return "Unsupported file format. Please upload a PDF or CSV file."
        case .fileReadError:
            return "Unable to read file. Please ensure the file is complete and not corrupted."
        case .parsingError:
            return "Error parsing data. Please check file format and try again."
        case .emptyData:
            return "No data extracted from the file. Please check file contents and try again."
        }
    }
}

// Since ExpenseCategory likely exists elsewhere in your project,
// use an internal enum for the import service and then map to your app's type
enum ImportCategory: String, CaseIterable {
    case housing = "Housing"
    case utilities = "Utilities"
    case food = "Food"
    case dining = "Dining"
    case transportation = "Transportation"
    case entertainment = "Entertainment"
    case healthcare = "Healthcare"
    case insurance = "Insurance"
    case shopping = "Shopping"
    case education = "Education"
    case travel = "Travel"
    case subscription = "Subscription"
    case fitness = "Fitness"
    case books = "Books"
    case electronics = "Electronics"
    case gaming = "Gaming"
    case other = "Other"
    
    // Add icon property
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .dining: return "cup.and.saucer"
        case .housing: return "house"
        case .transportation: return "car"
        case .entertainment: return "film"
        case .utilities: return "bolt"
        case .healthcare, .fitness: return "heart"
        case .insurance: return "lock.shield"
        case .shopping, .books, .electronics: return "bag"
        case .education: return "book"
        case .travel: return "airplane"
        case .subscription: return "repeat"
        case .gaming: return "gamecontroller"
        case .other: return "ellipsis.circle"
        }
    }

    // More nuanced isTypicallyNecessary property
    var isTypicallyNecessary: Bool {
        switch self {
        case .food, .housing, .transportation, .utilities, .healthcare, .insurance, .education:
            return true
        case .dining, .entertainment, .shopping, .travel, .subscription, .fitness, .books, .electronics, .gaming, .other:
            return false
        }
    }
    
    // Improved mapping to ExpenseCategory
    func toExpenseCategory() -> ExpenseCategory {
        switch self {
        case .housing:
            return .housing
        case .food, .dining:
            return .food
        case .transportation:
            return .transportation
        case .utilities:
            return .utilities
        case .healthcare, .fitness, .insurance:
            return .healthcare
        case .shopping, .electronics:
            return .shopping
        case .education, .books:
            return .education
        case .entertainment, .gaming, .subscription:
            return .entertainment
        case .travel:
            return .travel
        case .other:
            return .other
        }
    }
    
    // Helper to determine confidence in classification
    var classificationConfidence: Double {
        switch self {
        case .housing, .utilities, .healthcare, .insurance:
            return 0.9 // High confidence categories
        case .food, .transportation, .education:
            return 0.8 // Medium-high confidence
        case .dining, .entertainment, .travel:
            return 0.7 // Medium confidence
        case .shopping, .subscription, .electronics, .gaming, .books, .fitness:
            return 0.6 // Medium-low confidence
        case .other:
            return 0.5 // Low confidence
        }
    }
}

// Imported transaction data model
struct ImportedTransaction: Identifiable {
    var id = UUID()
    var date: Date
    var description: String
    var amount: Double
    var rawText: String
    var confidence: Double = 0.5
    var suggestedCategory: ImportCategory?
    var isNecessary: Bool?
    
    // Convert to Expense object (Expense type must be defined elsewhere)
    func toExpense(userId: String, category: ExpenseCategory, isNecessary: Bool) -> Expense {
        return Expense(
            title: description,
            amount: abs(amount),
            date: date,
            category: category,
            isNecessary: isNecessary,
            notes: "Imported from: \(rawText)",
            userId: userId
        )
    }
}

class DataImportService {
    static let shared = DataImportService()
    
    private init() {}
    
    func importPDF(url: URL, completion: @escaping (Result<[ImportedTransaction], ImportError>) -> Void) {
        // Important: Start accessing the security-scoped resource
        let hasAccess = url.startAccessingSecurityScopedResource()
        
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Use PDFKit to read PDF
        guard let pdfDocument = PDFDocument(url: url) else {
            completion(.failure(.fileReadError))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var extractedText = ""
            for i in 0..<pdfDocument.pageCount {
                if let page = pdfDocument.page(at: i) {
                    extractedText += page.string ?? ""
                }
            }
            
            if extractedText.isEmpty {
                DispatchQueue.main.async {
                    completion(.failure(.emptyData))
                }
                return
            }
            
            // Call PDF parsing function
            let transactions = self.parseTransactionsFromText(extractedText, accountType: .credit)
            
            DispatchQueue.main.async {
                if transactions.isEmpty {
                    completion(.failure(.parsingError))
                } else {
                    completion(.success(transactions))
                }
            }
        }
    }
    
    func importCSV(url: URL, completion: @escaping (Result<[ImportedTransaction], ImportError>) -> Void) {
        // Important: Start accessing the security-scoped resource
        let hasAccess = url.startAccessingSecurityScopedResource()
        
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: url)
            guard let csvString = String(data: data, encoding: .utf8) else {
                completion(.failure(.fileReadError))
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                let transactions = self.parseCSV(csvString)
                DispatchQueue.main.async {
                    if transactions.isEmpty {
                        completion(.failure(.parsingError))
                    } else {
                        completion(.success(transactions))
                    }
                }
            }
        } catch {
            completion(.failure(.fileReadError))
        }
    }
    
    enum CardType {
        case credit
        case debit
    }
    
    private func parseTransactionsFromText(_ text: String, accountType: CardType) -> [ImportedTransaction] {
        var transactions: [ImportedTransaction] = []
        
        // 1. Split text by lines
        let rawLines = text.components(separatedBy: .newlines)
        let lines = rawLines
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        print("Text length: \(text.count) characters")
        print("Text sample: \(text.prefix(200))")
        print("Total \(lines.count) lines")
        
        // 2. Extract context year from text
        func extractContextYear(from text: String) -> Int? {
            let patterns = [
                "Statement Date[:]?\\s*(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})",
                "Payment Due Date[:]?\\s*(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})"
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(text.startIndex..<text.endIndex, in: text)
                    if let match = regex.firstMatch(in: text, options: [], range: range),
                       match.numberOfRanges >= 2,
                       let dateRange = Range(match.range(at: 1), in: text) {
                        let dateStr = String(text[dateRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let dateFormatter = DateFormatter()
                        let formats = ["MM/dd/yyyy", "MM-dd-yyyy", "M/d/yyyy", "M/d/yy", "MM/dd/yy"]
                        for format in formats {
                            dateFormatter.dateFormat = format
                            if let date = dateFormatter.date(from: dateStr) {
                                return Calendar.current.component(.year, from: date)
                            }
                        }
                    }
                }
            }
            return nil
        }
        
        let contextYear: Int = extractContextYear(from: text) ?? Calendar.current.component(.year, from: Date())
        print("Using statement context year: \(contextYear)")
        
        // 3. Exclude header keywords
        let ignoreKeywords = [
            "MERCHANT NAME",
            "TRANSACTION DESCRIPTION",
            "DATE OF TRANSACTION",
            "PAYMENT DUE DATE",
            "ACCOUNT SUMMARY",
            "ACCOUNT ACTIVITY",
            "STATEMENT DATE",
            "MINIMUM PAYMENT",
            "BALANCE",
            "AMOUNT ENCLOSED"
        ]
        
        func shouldIgnoreLine(_ line: String) -> Bool {
            for keyword in ignoreKeywords {
                if line.uppercased().contains(keyword.uppercased()) {
                    return true
                }
            }
            return false
        }
        
        // 4. Use regex to split transaction records
        let pattern = #"^(?<date>\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?)\s+(?<desc>.+?)\s+(?<amount>-?\$?\s*\d{1,3}(?:,\d{3})*(?:\.\d{2})?)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            print("Regex compilation failed")
            return []
        }
        
        // 5. Helper function: Parse date string
        func parseDate(_ dateStr: String) -> Date? {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            if dateStr.contains("/") || dateStr.contains("-") {
                let separator: Character = dateStr.contains("/") ? "/" : "-"
                let components = dateStr.split(separator: separator)
                if components.count == 3 {
                    let normalized = dateStr.replacingOccurrences(of: "-", with: "/")
                    dateFormatter.dateFormat = "MM/dd/yyyy"
                    return dateFormatter.date(from: normalized)
                } else if components.count == 2 {
                    let fullDateString = "\(dateStr)\(separator)\(contextYear)".replacingOccurrences(of: "-", with: "/")
                    dateFormatter.dateFormat = "MM/dd/yyyy"
                    if let date = dateFormatter.date(from: fullDateString) {
                        if date > Date() {
                            let adjustedDateString = "\(dateStr)\(separator)\(contextYear - 1)".replacingOccurrences(of: "-", with: "/")
                            return dateFormatter.date(from: adjustedDateString) ?? date
                        }
                        return date
                    }
                }
            }
            return nil
        }
        
        // 6. Parse single line record
        func parseLine(_ line: String) -> ImportedTransaction? {
            if shouldIgnoreLine(line) { return nil }
            
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = regex.firstMatch(in: line, options: [], range: nsRange) else {
                return nil
            }
            
            guard let dateRange = Range(match.range(withName: "date"), in: line),
                  let descRange = Range(match.range(withName: "desc"), in: line),
                  let amountRange = Range(match.range(withName: "amount"), in: line)
            else {
                return nil
            }
            
            let dateStr = String(line[dateRange]).trimmingCharacters(in: .whitespaces)
            var desc = String(line[descRange]).trimmingCharacters(in: .whitespaces)
            var amountStr = String(line[amountRange]).trimmingCharacters(in: .whitespaces)
            
            if shouldIgnoreLine(desc) {
                return nil
            }
            
            guard let date = parseDate(dateStr) else { return nil }
            
            amountStr = amountStr.replacingOccurrences(of: "$", with: "")
                                 .replacingOccurrences(of: ",", with: "")
            guard let rawAmount = Double(amountStr) else { return nil }
            
            // Filter based on account type
            switch accountType {
            case .credit:
                if rawAmount < 0 { return nil }
            case .debit:
                if rawAmount > 0 { return nil }
            }
            
            if desc.count < 2 {
                desc = "Transaction on \(dateStr)"
            }
            
            let transaction = ImportedTransaction(
                date: date,
                description: desc,
                amount: abs(rawAmount),
                rawText: line,
                suggestedCategory: suggestCategory(for: desc),
                isNecessary: nil
            )
            
            return transaction
        }
        
        for line in lines {
            if let tx = parseLine(line) {
                transactions.append(tx)
            }
        }
        
        print("Successfully parsed \(transactions.count) transactions")
        return transactions
    }
    

    private func parseCSV(_ csvString: String) -> [ImportedTransaction] {
        var transactions: [ImportedTransaction] = []
        
        print("CSV Import: Starting CSV analysis")
        print("CSV length: \(csvString.count) characters")
        print("Sample of CSV content: \(csvString.prefix(200))")
        
        // Manual CSV parsing to avoid SwiftCSV compatibility issues
        let lines = csvString.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty }
        
        guard lines.count > 1 else {
            print("CSV contains insufficient data")
            return []
        }
        
        // Parse header
        let header = parseCSVRow(lines[0])
        let headerLowercased = header.map { $0.lowercased() }
        
        print("CSV Headers: \(header.joined(separator: ", "))")
        
        // Check if this is a Chase CSV (which has a specific format)
        let isChaseCSV = headerLowercased.contains("transaction date") &&
                         headerLowercased.contains("post date") &&
                         headerLowercased.contains("description") &&
                         headerLowercased.contains("category")
        
        if isChaseCSV {
            print("Detected Chase CSV format - using direct column mapping")
            return parseChaseCSV(lines: lines, header: header, headerLowercased: headerLowercased)
        }
        
        // For non-Chase CSV files, continue with the standard parsing logic
        // Identify required column indices with detailed logging
        let dateColumnIndex = headerLowercased.firstIndex(where: {
            $0.contains("date") || $0.contains("time")
        })
        
        let amountColumnIndex = headerLowercased.firstIndex(where: {
            $0.contains("amount") || $0.contains("sum") || $0.contains("value") ||
            $0.contains("payment") || $0.contains("price") || $0.contains("debit") ||
            $0.contains("credit") || $0.contains("transaction")
        })
        
        guard let dateCol = dateColumnIndex, let amountCol = amountColumnIndex else {
            print("Missing required columns in CSV")
            if dateColumnIndex == nil { print("- Missing date column") }
            if amountColumnIndex == nil { print("- Missing amount column") }
            return []
        }
        
        // Find description column with comprehensive options
        let descColumnIndex = headerLowercased.firstIndex(where: {
            $0 == "description" || $0 == "desc" || $0 == "memo" || $0 == "narration" ||
            $0 == "name" || $0 == "payee" || $0 == "merchant" || $0 == "transaction description" ||
            ($0.contains("descr") && !$0.contains("date")) ||
            ($0.contains("memo") && !$0.contains("date")) ||
            ($0.contains("narra") && !$0.contains("date")) ||
            ($0.contains("name") && !$0.contains("date")) ||
            ($0.contains("payee") && !$0.contains("date")) ||
            ($0.contains("merch") && !$0.contains("date"))
        })
        
        // Log column identification results
        print("Date column at index: \(dateCol), header: \(header[dateCol])")
        print("Amount column at index: \(amountCol), header: \(header[amountCol])")
        
        if let descIndex = descColumnIndex {
            print("Description column at index: \(descIndex), header: \(header[descIndex])")
        } else {
            print("No description column found - will look for alternative columns")
            
            // Try to find any column that might contain description data
            for (i, columnName) in headerLowercased.enumerated() {
                if i != dateCol && i != amountCol &&
                   !columnName.contains("date") &&
                   !columnName.contains("amount") &&
                   !columnName.contains("balance") {
                    print("Potential description column at index: \(i), header: \(header[i])")
                }
            }
        }
        
        // Look for category column
        let categoryColumnIndex = headerLowercased.firstIndex(where: {
            $0.contains("category") || $0.contains("type") || $0.contains("classification")
        })
        
        // Process each row
        for (rowIndex, row) in lines.enumerated().dropFirst() { // Skip header row
            guard row.count > max(dateCol, amountCol) else { continue }
            
            let columns = parseCSVRow(row)
            guard columns.count > max(dateCol, amountCol) else { continue }
            
            let dateString = columns[dateCol]
            guard let date = parseDate(dateString) else { continue }
            
            let amountString = columns[amountCol]
            guard let amount = parseAmount(amountString) else { continue }
            
            // CRITICAL PART: Find a meaningful description
            var description = "Transaction \(rowIndex)"
            
            // First try: look in the description column
            if let descCol = descColumnIndex, columns.count > descCol, !columns[descCol].isEmpty {
                description = columns[descCol].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            // Second try: look for a column that has text but isn't a date or amount
            else {
                for (colIndex, value) in columns.enumerated() {
                    // Skip already known columns
                    if colIndex == dateCol || colIndex == amountCol ||
                       (descColumnIndex != nil && colIndex == descColumnIndex) ||
                       (categoryColumnIndex != nil && colIndex == categoryColumnIndex) {
                        continue
                    }
                    
                    let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty && !isDateString(text) && !isAmountString(text) {
                        description = text
                        print("Found description in column \(colIndex): '\(description)'")
                        break
                    }
                }
            }
            
            // Clean up description
            description = cleanupTransactionDescription(description)
            
            // Make sure it's not a date
            if isDateString(description) {
                description = "Transaction \(rowIndex)"
            }
            
            // Parse or suggest category
            var category: ImportCategory?
            if let catCol = categoryColumnIndex, columns.count > catCol, !columns[catCol].isEmpty {
                category = parseImportCategory(from: columns[catCol]) ?? suggestCategory(for: description)
            } else {
                category = suggestCategory(for: description)
            }
            
            // Create transaction
            let transaction = ImportedTransaction(
                date: date,
                description: description,
                amount: abs(amount),
                rawText: row,
                confidence: 0.7,
                suggestedCategory: category,
                isNecessary: category?.isTypicallyNecessary
            )
            
            transactions.append(transaction)
        }
        
        // Log transaction summary
        if !transactions.isEmpty {
            print("Successfully parsed \(transactions.count) transactions")
            print("Sample transactions:")
            
            for (i, tx) in transactions.prefix(3).enumerated() {
                print("\(i+1): Date: \(tx.date), Description: '\(tx.description)', Amount: \(tx.amount)")
            }
        } else {
            print("No transactions could be parsed from the CSV")
        }
        
        return transactions
    }

    // Special parser for Chase CSV format
    private func parseChaseCSV(lines: [String], header: [String], headerLowercased: [String]) -> [ImportedTransaction] {
        var transactions: [ImportedTransaction] = []
        
        // Map Chase CSV columns directly
        let transactionDateIndex = headerLowercased.firstIndex(of: "transaction date")
        let descriptionIndex = headerLowercased.firstIndex(of: "description")
        let categoryIndex = headerLowercased.firstIndex(of: "category")
        let amountIndex = headerLowercased.firstIndex(of: "amount")
        
        guard let dateCol = transactionDateIndex, let descCol = descriptionIndex, let amountCol = amountIndex else {
            print("Missing required columns in Chase CSV")
            return []
        }
        
        print("Chase CSV columns mapped: Date(\(dateCol)), Description(\(descCol)), Amount(\(amountCol))")
        
        // Process each transaction
        for (rowIndex, line) in lines.enumerated().dropFirst() { // Skip header
            let columns = parseCSVRow(line)
            guard columns.count > max(dateCol, descCol, amountCol) else { continue }
            
            // Parse date
            let dateString = columns[dateCol]
            guard let date = parseDate(dateString) else { continue }
            
            // Get description directly
            var description = columns[descCol].trimmingCharacters(in: .whitespacesAndNewlines)
            if description.isEmpty {
                description = "Chase Transaction \(rowIndex)"
            }
            
            // Parse amount
            let amountString = columns[amountCol]
            guard let amount = parseAmount(amountString) else { continue }
            
            // Get category if available
            var category: ImportCategory?
            if let catCol = categoryIndex, columns.count > catCol, !columns[catCol].isEmpty {
                category = parseImportCategory(from: columns[catCol])
            }
            
            // If no category or couldn't parse it, suggest one
            if category == nil {
                category = suggestCategory(for: description)
            }
            
            // Create the transaction
            let transaction = ImportedTransaction(
                date: date,
                description: description, // Direct from Chase description field
                amount: abs(amount),
                rawText: line,
                confidence: 0.9, // Higher confidence for direct Chase mapping
                suggestedCategory: category,
                isNecessary: category?.isTypicallyNecessary
            )
            
            transactions.append(transaction)
        }
        
        // Log Chase transactions summary
        if !transactions.isEmpty {
            print("Successfully parsed \(transactions.count) Chase transactions")
            print("Sample Chase transactions:")
            
            for (i, tx) in transactions.prefix(3).enumerated() {
                print("\(i+1): '\(tx.description)' - \(tx.date) - $\(tx.amount)")
            }
        }
        
        return transactions
    }

    // Improved date parsing with more formats
    private func parseDate(_ dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Try various date formats
        let dateFormats = [
            "MM/dd/yyyy", "MM/dd/yy",
            "yyyy-MM-dd", "yyyy/MM/dd",
            "dd/MM/yyyy", "dd-MM-yyyy",
            "M/d/yyyy", "M/d/yy",
            "MM-dd-yyyy"
        ]
        
        for format in dateFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return date
            }
        }
        
        return nil
    }

    // Improved amount parsing for different formats
    private func parseAmount(_ amountString: String) -> Double? {
        // Handle various amount formats
        var cleanString = amountString
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle negative amounts with parentheses: (123.45)
        if cleanString.hasPrefix("(") && cleanString.hasSuffix(")") {
            cleanString = cleanString.dropFirst().dropLast().description
            cleanString = "-" + cleanString
        }
        
        return Double(cleanString)
    }

    // Helper to check if a string looks like an amount
    private func isAmountString(_ str: String) -> Bool {
        let cleanStr = str
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it's a number with optional decimal point
        let pattern = "^\\(?(\\d+(\\.\\d+)?)\\)?$"
        return str.range(of: pattern, options: .regularExpression) != nil || Double(cleanStr) != nil
    }

    // Helper function to clean up transaction descriptions
    private func cleanupTransactionDescription(_ raw: String) -> String {
        var desc = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common transaction prefixes
        let prefixes = [
            "PURCHASE AT ", "PURCHASE FROM ", "POS PURCHASE ", "DEBIT CARD PURCHASE ",
            "PAYMENT TO ", "WITHDRAWAL AT ", "TRANSACTION - ", "POS DEBIT ", "ACH DEBIT - ",
            "ONLINE PAYMENT TO ", "CHECK CARD PURCHASE ", "ELECTRONIC PAYMENT ", "POS "
        ]
        
        for prefix in prefixes {
            if desc.uppercased().hasPrefix(prefix) {
                desc = String(desc.dropFirst(prefix.count))
                break
            }
        }
        
        // Handle descriptions with multiple parts (often separated by "-" or "*")
        if desc.contains("-") || desc.contains("*") {
            let separators = ["-", "*", "–", "—"] // Include various dash types
            for separator in separators {
                let components = desc.components(separatedBy: separator)
                if components.count > 1 {
                    // Usually, the merchant name is the last component (but make sure it's not empty)
                    if let lastPart = components.last?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !lastPart.isEmpty {
                        desc = lastPart
                        break
                    }
                }
            }
        }
        
        // Remove any trailing transaction numbers or references in parentheses
        if let range = desc.range(of: #"\s*\(.*\)\s*$"#, options: .regularExpression) {
            desc = String(desc[..<range.lowerBound])
        }
        
        // Remove trailing spaces, punctuation
        desc = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        desc = desc.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
        
        // Make sure we still have a valid description
        if desc.isEmpty {
            desc = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return desc
    }

    // Helper function to check if a string looks like a date
    private func isDateString(_ str: String) -> Bool {
        // Check for common date patterns
        let dateRegexPatterns = [
            "^\\d{1,2}/\\d{1,2}/\\d{2,4}$", // MM/DD/YYYY or DD/MM/YYYY
            "^\\d{1,2}-\\d{1,2}-\\d{2,4}$", // MM-DD-YYYY or DD-MM-YYYY
            "^\\d{4}-\\d{1,2}-\\d{1,2}$",   // YYYY-MM-DD
            "^\\d{4}/\\d{1,2}/\\d{1,2}$"    // YYYY/MM/DD
        ]
        
        for pattern in dateRegexPatterns {
            if str.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    // Helper function to parse a CSV row accounting for quoted values
    private func parseCSVRow(_ line: String) -> [String] {
        var result: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes = !insideQuotes
            } else if char == "," && !insideQuotes {
                result.append(currentField.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        
        // Add the last field
        result.append(currentField.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
        return result
    }
    
    // MARK: - Improved category suggestion function
    
    private func suggestCategory(for description: String) -> ImportCategory {
        let desc = description.lowercased()
        
        // Housing
        if desc.contains("rent") || desc.contains("mortgage") ||
           desc.contains("apartment") || desc.contains("home") ||
           desc.contains("property") || desc.contains("housing") ||
           desc.contains("real estate") {
            return .housing
        }
        
        // Utilities
        if desc.contains("electric") || desc.contains("water") ||
           desc.contains("gas bill") || desc.contains("internet") ||
           desc.contains("phone") || desc.contains("utilities") ||
           desc.contains("sewage") || desc.contains("cable") ||
           desc.contains("broadband") || desc.contains("cellular") ||
           desc.contains("wi-fi") || desc.contains("utility") {
            return .utilities
        }
        
        // Food (groceries)
        if desc.contains("grocery") || desc.contains("supermarket") ||
           desc.contains("food") || desc.contains("market") ||
           desc.contains("safeway") || desc.contains("kroger") ||
           desc.contains("trader joe") || desc.contains("whole foods") ||
           desc.contains("aldi") || desc.contains("wegmans") ||
           desc.contains("walmart supercenter") {
            return .food
        }
        
        // Dining (restaurants)
        if desc.contains("restaurant") || desc.contains("dining") ||
           desc.contains("cafe") || desc.contains("coffee") ||
           desc.contains("starbucks") || desc.contains("mcdonald") ||
           desc.contains("burger") || desc.contains("pizza") ||
           desc.contains("taco") || desc.contains("grubhub") ||
           desc.contains("doordash") || desc.contains("ubereats") ||
           desc.contains("deli") || desc.contains("bakery") {
            return .dining
        }
        
        // Transportation
        if desc.contains("uber") || desc.contains("lyft") ||
           desc.contains("taxi") || desc.contains("cab") ||
           desc.contains("bus") || desc.contains("metro") ||
           desc.contains("subway") || desc.contains("train") ||
           desc.contains("transport") || desc.contains("gas station") ||
           desc.contains("fuel") || desc.contains("exxon") ||
           desc.contains("shell") || desc.contains("chevron") ||
           desc.contains("parkn") || desc.contains("parking") ||
           desc.contains("toll") || desc.contains("transit") {
            return .transportation
        }
        
        // Entertainment
        if desc.contains("movie") || desc.contains("netflix") ||
           desc.contains("hulu") || desc.contains("entertainment") ||
           desc.contains("spotify") || desc.contains("music") ||
           desc.contains("theater") || desc.contains("concert") ||
           desc.contains("cinema") || desc.contains("ticket") ||
           desc.contains("disney+") || desc.contains("prime video") ||
           desc.contains("hbo") || desc.contains("apple tv") {
            return .entertainment
        }
        
        // Healthcare
        if desc.contains("doctor") || desc.contains("hospital") ||
           desc.contains("medical") || desc.contains("health") ||
           desc.contains("pharmacy") || desc.contains("dental") ||
           desc.contains("vision") || desc.contains("clinic") ||
           desc.contains("walgreens") || desc.contains("cvs") ||
           desc.contains("therapy") || desc.contains("prescription") {
            return .healthcare
        }
        
        // Insurance
        if desc.contains("insurance") || desc.contains("state farm") ||
           desc.contains("geico") || desc.contains("allstate") ||
           desc.contains("progressive") || desc.contains("covered") ||
           desc.contains("policy") {
            return .insurance
        }
        
        // Shopping
        if desc.contains("amazon") || desc.contains("target") ||
           desc.contains("walmart") || desc.contains("costco") ||
           desc.contains("best buy") || desc.contains("mall") ||
           desc.contains("macy") || desc.contains("nordstrom") ||
           desc.contains("marshalls") || desc.contains("tjmaxx") ||
           desc.contains("kohl") || desc.contains("shopping") ||
           desc.contains("store") {
            return .shopping
        }
        
        // Education
        if desc.contains("tuition") || desc.contains("school") ||
           desc.contains("education") || desc.contains("college") ||
           desc.contains("university") || desc.contains("class") ||
           desc.contains("course") || desc.contains("student loan") ||
           desc.contains("textbook") || desc.contains("educational") {
            return .education
        }
        
        // Travel
        if desc.contains("hotel") || desc.contains("flight") ||
           desc.contains("airbnb") || desc.contains("travel") ||
           desc.contains("airline") || desc.contains("delta") ||
           desc.contains("southwest") || desc.contains("united") ||
           desc.contains("american airlines") || desc.contains("vacation") ||
           desc.contains("resort") || desc.contains("booking.com") ||
           desc.contains("expedia") || desc.contains("trip") {
            return .travel
        }
        
        // Subscription services
        if desc.contains("subscription") || desc.contains("membership") ||
           desc.contains("monthly") || desc.contains("annual fee") ||
           desc.contains("renew") || desc.contains("plan") {
            return .subscription
        }
        
        // Fitness
        if desc.contains("gym") || desc.contains("fitness") ||
           desc.contains("peloton") || desc.contains("workout") ||
           desc.contains("exercise") || desc.contains("athletic") ||
           desc.contains("yoga") || desc.contains("sport") {
            return .fitness
        }
        
        // Books
        if desc.contains("book") || desc.contains("barnes") ||
           desc.contains("magazine") || desc.contains("publication") ||
           desc.contains("kindle") || desc.contains("audible") {
            return .books
        }
        
        // Electronics
        if desc.contains("electronics") || desc.contains("tech") ||
           desc.contains("gadget") || desc.contains("computer") ||
           desc.contains("laptop") || desc.contains("phone") ||
           desc.contains("camera") || desc.contains("apple") ||
           desc.contains("samsung") || desc.contains("device") {
            return .electronics
        }
        
        // Gaming
        if desc.contains("game") || desc.contains("gaming") ||
           desc.contains("playstation") || desc.contains("xbox") ||
           desc.contains("nintendo") || desc.contains("steam") ||
           desc.contains("twitch") {
            return .gaming
        }
        
        // Default to "other" if no category is matched
        return .other
    }
    
    private func parseImportCategory(from str: String) -> ImportCategory? {
        let lower = str.lowercased()
        
        if lower.contains("rent") || lower.contains("mortgage") || lower.contains("housing") {
            return .housing
        } else if lower.contains("electricity") || lower.contains("water") ||
                    lower.contains("gas bill") || lower.contains("internet") ||
                    lower.contains("phone") || lower.contains("utilities") {
            return .utilities
        } else if lower.contains("grocery") || lower.contains("supermarket") || lower.contains("food") {
            return .food
        } else if lower.contains("restaurant") || lower.contains("dining") || lower.contains("cafe") || lower.contains("coffee") {
            return .dining
        } else if lower.contains("uber") || lower.contains("lyft") || lower.contains("taxi") ||
                    lower.contains("cab") || lower.contains("bus") || lower.contains("metro") ||
                    lower.contains("transport") {
            return .transportation
        } else if lower.contains("movie") || lower.contains("netflix") || lower.contains("hulu") ||
                    lower.contains("entertainment") || lower.contains("spotify") || lower.contains("music") {
            return .entertainment
        } else if lower.contains("doctor") || lower.contains("hospital") || lower.contains("medical") ||
                    lower.contains("health") || lower.contains("pharmacy") {
            return .healthcare
        } else if lower.contains("insurance") {
            return .insurance
        } else if lower.contains("amazon") || lower.contains("shop") || lower.contains("store") ||
                    lower.contains("mall") {
            return .shopping
        } else if lower.contains("tuition") || lower.contains("school") || lower.contains("education") ||
                    lower.contains("college") || lower.contains("university") {
            return .education
        } else if lower.contains("hotel") || lower.contains("flight") || lower.contains("airbnb") ||
                    lower.contains("travel") {
            return .travel
        } else if lower.contains("subscription") || lower.contains("membership") {
            return .subscription
        } else if lower.contains("gym") || lower.contains("fitness") {
            return .fitness
        } else if lower.contains("book") || lower.contains("magazine") {
            return .books
        } else if lower.contains("electronics") || lower.contains("gadget") {
            return .electronics
        } else if lower.contains("game") || lower.contains("gaming") {
            return .gaming
        }
        return nil
    }
    
    // Batch processing for large datasets
    func processInBatches<T>(items: [T], batchSize: Int = 10,
                          process: @escaping ([T], @escaping (Bool) -> Void) -> Void,
                          completion: @escaping (Bool) -> Void) {
        var currentIndex = 0
        
        func processNextBatch() {
            guard currentIndex < items.count else {
                completion(true)
                return
            }
            
            let endIndex = min(currentIndex + batchSize, items.count)
            let batch = Array(items[currentIndex..<endIndex])
            
            process(batch) { success in
                if success {
                    currentIndex = endIndex
                    DispatchQueue.main.async {
                        processNextBatch()
                    }
                } else {
                    completion(false)
                }
            }
        }
        
        processNextBatch()
    }
}

// Extension to add the improved classification functionality
extension DataImportService {
    
    // Main function to improve necessity classification of imported transactions
    func improveNecessityClassification(_ transactions: [ImportedTransaction]) -> [ImportedTransaction] {
        var improvedTransactions = transactions
        
        // Access the classifier service
        let classifier = ExpenseClassifierService.shared
        
        for i in 0..<improvedTransactions.count {
            // Start with category-based classification
            let category = improvedTransactions[i].suggestedCategory ?? .other
            let initialNecessity = category.isTypicallyNecessary
            
            // Get transaction details
            let title = improvedTransactions[i].description
            let amount = improvedTransactions[i].amount
            
            // Use ML-based classification from the existing ExpenseClassifierService
            // Convert ImportCategory to ExpenseCategory for classification
            let expenseCategory = category.toExpenseCategory()
            let predictedNecessity = classifier.predictIsNecessary(
                title: title,
                amount: amount,
                category: expenseCategory
            )
            
            // Apply additional heuristics for specific transactions
            let necessityFromHeuristics = analyzeTransactionWithHeuristics(
                title: title,
                amount: amount,
                category: category
            )
            
            // Determine final classification (prioritize heuristics over ML prediction)
            let finalNecessity: Bool
            
            if let necessityFromHeuristics = necessityFromHeuristics {
                // If our heuristics are confident, use that result
                finalNecessity = necessityFromHeuristics
            } else {
                // Otherwise use ML prediction
                finalNecessity = predictedNecessity
            }
            
            // Update the transaction
            improvedTransactions[i].isNecessary = finalNecessity
        }
        
        return improvedTransactions
    }
    
    // Apply specific heuristics for common transaction patterns
    private func analyzeTransactionWithHeuristics(
        title: String,
        amount: Double,
        category: ImportCategory
    ) -> Bool? {
        // Normalize the title for better matching
        let normalizedTitle = title.lowercased()
        
        // DEFINITE NECESSARY EXPENSES
        
        // Housing/Utilities (always necessary)
        if category == .housing || category == .utilities {
            // Very high amounts might be luxury upgrades or renovation
            if amount > 3000 && !normalizedTitle.contains("rent") && !normalizedTitle.contains("mortgage") {
                return false // Possibly a home improvement/renovation
            }
            return true
        }
        
        // Medical expenses (mostly necessary)
        if normalizedTitle.contains("pharmacy") ||
           normalizedTitle.contains("doctor") ||
           normalizedTitle.contains("hospital") ||
           normalizedTitle.contains("clinic") ||
           normalizedTitle.contains("medical") {
            // High cost elective procedures might be non-necessary
            if amount > 1000 && (normalizedTitle.contains("cosmetic") || normalizedTitle.contains("elective")) {
                return false
            }
            return true
        }
        
        // Insurance payments (necessary)
        if normalizedTitle.contains("insurance") {
            return true
        }
        
        // Education essentials (necessary)
        if category == .education && (
            normalizedTitle.contains("tuition") ||
            normalizedTitle.contains("textbook") ||
            normalizedTitle.contains("school fee")
        ) {
            return true
        }
        
        // Transportation necessities
        if category == .transportation && (
            normalizedTitle.contains("gas") ||
            normalizedTitle.contains("fuel") ||
            normalizedTitle.contains("transit") ||
            normalizedTitle.contains("bus") ||
            normalizedTitle.contains("train") ||
            normalizedTitle.contains("subway") ||
            normalizedTitle.contains("commute")
        ) {
            return true
        }
        
        // DEFINITE NON-NECESSARY EXPENSES
        
        // Entertainment is generally non-necessary
        if category == .entertainment {
            return false
        }
        
        // Restaurants and dining out
        if normalizedTitle.contains("restaurant") ||
           normalizedTitle.contains("cafe") ||
           normalizedTitle.contains("coffee") ||
           normalizedTitle.contains("starbucks") ||
           normalizedTitle.contains("mcdonalds") ||
           normalizedTitle.contains("burger") ||
           normalizedTitle.contains("pizza") {
            // Fast food and coffee shops are almost always discretionary
            return false
        }
        
        // Shopping typically non-necessary
        if category == .shopping && amount > 100 {
            // High value shopping is likely discretionary
            return false
        }
        
        // Travel is non-necessary
        if category == .travel {
            return false
        }
        
        // Subscription services
        if normalizedTitle.contains("netflix") ||
           normalizedTitle.contains("spotify") ||
           normalizedTitle.contains("hulu") ||
           normalizedTitle.contains("disney+") ||
           normalizedTitle.contains("prime") ||
           normalizedTitle.contains("subscription") {
            return false
        }
        
        // AMBIGUOUS CASES - return nil to let ML classifier decide
        
        // Grocery stores could be necessary (food) or unnecessary (snacks, alcohol)
        if normalizedTitle.contains("grocery") ||
           normalizedTitle.contains("supermarket") ||
           normalizedTitle.contains("walmart") ||
           normalizedTitle.contains("target") {
            // High grocery bills might include more discretionary items
            if amount > 200 {
                return false
            }
            if amount < 100 {
                return true
            }
            return nil // Let ML decide moderate grocery bills
        }
        
        // Payments/transfers may need more context
        if normalizedTitle.contains("payment") ||
           normalizedTitle.contains("transfer") ||
           normalizedTitle.contains("zelle") ||
           normalizedTitle.contains("venmo") ||
           normalizedTitle.contains("paypal") {
            return nil // Need more context to decide
        }
        
        // Return nil for ambiguous cases to let the ML classifier decide
        return nil
    }
}
