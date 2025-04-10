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
enum ImportCategory: String {
    case housing, utilities, food, dining, transportation, entertainment, healthcare, insurance, shopping, education, travel, subscription, fitness, books, electronics, gaming, other
    
    // Add icon property
    var icon: String {
        switch self {
        case .food, .dining: return "fork.knife"
        case .housing: return "house"
        case .transportation: return "car"
        case .entertainment: return "film"
        case .utilities: return "bolt"
        case .healthcare, .fitness: return "heart"
        case .shopping, .books, .electronics: return "bag"
        case .education: return "book"
        case .travel: return "airplane"
        case .insurance: return "lock.shield"
        case .subscription: return "repeat"
        case .gaming: return "gamecontroller"
        case .other: return "ellipsis.circle"
        }
    }

    // Add isTypicallyNecessary property
    var isTypicallyNecessary: Bool {
        switch self {
        case .food, .housing, .transportation, .utilities, .healthcare, .insurance, .education:
            return true
        case .dining, .entertainment, .shopping, .travel, .subscription, .fitness, .books, .electronics, .gaming, .other:
            return false
        }
    }
    

    // Convert to the app's ExpenseCategory type
    func toExpenseCategory() -> ExpenseCategory {
        // Use the string value to create the actual ExpenseCategory
        return ExpenseCategory(rawValue: self.rawValue) ?? .other
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
    
    // MARK: Modified CSV parsing without SwiftCSV dependency
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
    
    // MARK: - Updated category suggestion function
    
    private func suggestCategory(for description: String) -> ImportCategory {
        let desc = description.lowercased()
        
        if desc.contains("rent") || desc.contains("mortgage") || desc.contains("housing") {
            return .housing
        } else if desc.contains("electricity") || desc.contains("water") ||
                    desc.contains("gas bill") || desc.contains("internet") ||
                    desc.contains("phone") || desc.contains("utilities") {
            return .utilities
        } else if desc.contains("grocery") || desc.contains("supermarket") || desc.contains("food") {
            return .food
        } else if desc.contains("restaurant") || desc.contains("dining") || desc.contains("cafe") || desc.contains("coffee") {
            return .dining
        } else if desc.contains("uber") || desc.contains("lyft") || desc.contains("taxi") ||
                    desc.contains("cab") || desc.contains("bus") || desc.contains("metro") ||
                    desc.contains("transport") {
            return .transportation
        } else if desc.contains("movie") || desc.contains("netflix") || desc.contains("hulu") ||
                    desc.contains("entertainment") || desc.contains("spotify") || desc.contains("music") {
            return .entertainment
        } else if desc.contains("doctor") || desc.contains("hospital") || desc.contains("medical") ||
                    desc.contains("health") || desc.contains("pharmacy") {
            return .healthcare
        } else if desc.contains("insurance") {
            return .insurance
        } else if desc.contains("amazon") || desc.contains("shop") || desc.contains("store") ||
                    desc.contains("mall") {
            return .shopping
        } else if desc.contains("tuition") || desc.contains("school") || desc.contains("education") ||
                    desc.contains("college") || desc.contains("university") {
            return .education
        } else if desc.contains("hotel") || desc.contains("flight") || desc.contains("airbnb") ||
                    desc.contains("travel") {
            return .travel
        } else if desc.contains("subscription") || desc.contains("membership") {
            return .subscription
        } else if desc.contains("gym") || desc.contains("fitness") {
            return .fitness
        } else if desc.contains("book") || desc.contains("magazine") {
            return .books
        } else if desc.contains("electronics") || desc.contains("gadget") {
            return .electronics
        } else if desc.contains("game") || desc.contains("gaming") {
            return .gaming
        }
        
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
