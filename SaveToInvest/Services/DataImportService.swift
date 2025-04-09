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
    // Add this function to your DataImportService.swift file to enhance the CSV preview

    // Modify parseCSV function to include preview information
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
        
        // Log header information for debugging
        print("CSV Headers: \(header.joined(separator: ", "))")
        
        // Identify required column indices with detailed logging
        let dateColumnIndex = headerLowercased.firstIndex(where: { $0.contains("date") })
        let amountColumnIndex = headerLowercased.firstIndex(where: {
            $0.contains("amount") || $0.contains("sum") || $0.contains("value") ||
            $0.contains("payment") || $0.contains("price") || $0.contains("debit") || $0.contains("credit")
        })
        
        guard let dateCol = dateColumnIndex, let amountCol = amountColumnIndex else {
            print("Missing required columns in CSV")
            if dateColumnIndex == nil { print("- Missing date column") }
            if amountColumnIndex == nil { print("- Missing amount column") }
            return []
        }
        
        // Find description column with comprehensive options
        let descColumnIndex = headerLowercased.firstIndex(where: {
            $0.contains("descr") || $0.contains("memo") || $0.contains("narration") ||
            $0.contains("transaction") || $0.contains("name") || $0.contains("payee") ||
            $0.contains("merchant") || $0.contains("detail") || $0.contains("particulars")
        })
        
        // Find alternate text columns if no description column is found
        let merchantColumnIndex = descColumnIndex == nil ? headerLowercased.firstIndex(where: {
            $0.contains("merchant") || $0.contains("vendor") || $0.contains("store") ||
            $0.contains("shop") || $0.contains("payee") || $0.contains("recipient")
        }) : nil
        
        // Try to find any text column that might contain transaction details
        let noteColumnIndex = (descColumnIndex == nil && merchantColumnIndex == nil) ?
            headerLowercased.firstIndex(where: {
                $0.contains("note") || $0.contains("detail") || $0.contains("text") ||
                $0.contains("info") || $0.contains("reference") || $0.contains("desc")
            }) : nil
        
        // Log column identification results
        print("Date column at index: \(dateCol), header: \(header[dateCol])")
        print("Amount column at index: \(amountCol), header: \(header[amountCol])")
        
        if let descIndex = descColumnIndex {
            print("Description column at index: \(descIndex), header: \(header[descIndex])")
        } else if let merchIndex = merchantColumnIndex {
            print("Using merchant column at index: \(merchIndex), header: \(header[merchIndex])")
        } else if let noteIndex = noteColumnIndex {
            print("Using note column at index: \(noteIndex), header: \(header[noteIndex])")
        } else {
            print("No description column found - will use placeholder descriptions")
        }
        
        // Look for category column
        let categoryColumnIndex = headerLowercased.firstIndex(where: {
            $0.contains("category") || $0.contains("type") || $0.contains("classification")
        })
        if let catIndex = categoryColumnIndex {
            print("Category column at index: \(catIndex), header: \(header[catIndex])")
        }
        
        // Gather data about amount signs to determine card type
        var positiveCount = 0
        var negativeCount = 0
        var rows: [[String]] = []
        
        for i in 1..<lines.count {
            let row = parseCSVRow(lines[i])
            if row.count >= max(dateCol, amountCol) + 1 {
                rows.append(row)
                
                if let amountString = row.indices.contains(amountCol) ? row[amountCol] : nil {
                    let cleanAmountStr = amountString
                        .replacingOccurrences(of: "$", with: "")
                        .replacingOccurrences(of: ",", with: "")
                        .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if let amount = Double(cleanAmountStr) {
                        if amount > 0 {
                            positiveCount += 1
                        } else if amount < 0 {
                            negativeCount += 1
                        }
                    }
                }
            }
        }
        
        let isCreditCard = positiveCount >= negativeCount
        print("Account Type: \(isCreditCard ? "Credit Card" : "Debit Card") (positive: \(positiveCount), negative: \(negativeCount))")
        
        // Parse date formats
        let dateFormatter = DateFormatter()
        let possibleDateFormats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy/MM/dd", "M/d/yyyy", "d/M/yyyy", "MM-dd-yyyy", "dd-MM-yyyy"]
        
        // Store transaction dates for range calculation
        var earliestDate: Date?
        var latestDate: Date?
        var totalAmount: Double = 0
        var categoryDistribution: [String: Int] = [:]
        
        // Process each row
        for (rowIndex, row) in rows.enumerated() {
            guard let dateString = row.indices.contains(dateCol) ? row[dateCol] : nil,
                  let amountString = row.indices.contains(amountCol) ? row[amountCol] : nil
            else { continue }
            
            // Parse date
            var date: Date? = nil
            for format in possibleDateFormats {
                dateFormatter.dateFormat = format
                if let d = dateFormatter.date(from: dateString) {
                    date = d
                    break
                }
            }
            if date == nil {
                print("Warning: Could not parse date '\(dateString)' - skipping row")
                continue
            }
            
            // Update date range
            if let validDate = date {
                if earliestDate == nil || validDate < earliestDate! {
                    earliestDate = validDate
                }
                if latestDate == nil || validDate > latestDate! {
                    latestDate = validDate
                }
            }
            
            // Parse amount
            let cleanAmountStr = amountString
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: "")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard let rawAmount = Double(cleanAmountStr) else {
                print("Warning: Could not parse amount '\(amountString)' - skipping row")
                continue
            }
            
            // Update total amount
            totalAmount += abs(rawAmount)
            
            // Apply card type filter if needed
            // Uncomment these if you want to filter transactions based on detected card type
            // if isCreditCard && rawAmount < 0 { continue }
            // if !isCreditCard && rawAmount > 0 { continue }
            
            // CRITICAL PART: Create meaningful description using multiple sources
            var transactionDescription = ""
            
            // Try to get description from description column
            if let descIndex = descColumnIndex,
               let desc = row.indices.contains(descIndex) ? row[descIndex] : nil,
               !desc.isEmpty && desc != dateString { // Make sure we're not using the date as the description
                transactionDescription = desc.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            // If no description found, try merchant column
            else if let merchIndex = merchantColumnIndex,
                    let merchant = row.indices.contains(merchIndex) ? row[merchIndex] : nil,
                    !merchant.isEmpty && merchant != dateString {
                transactionDescription = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            // If still no description, try note column
            else if let noteIndex = noteColumnIndex,
                    let note = row.indices.contains(noteIndex) ? row[noteIndex] : nil,
                    !note.isEmpty && note != dateString {
                transactionDescription = note.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            // Last resort: create a default description
            else {
                transactionDescription = "Transaction \(rowIndex + 1)"
            }
            
            // Clean up the description
            transactionDescription = cleanupTransactionDescription(transactionDescription)
            
            // Make sure we're not using date as description
            if isDateString(transactionDescription) {
                transactionDescription = "Transaction on \(dateString)"
            }
            
            // Debug the first few rows
            if rowIndex < 3 {
                print("Row \(rowIndex + 1): Date=\(dateString), Amount=\(amountString), Description='\(transactionDescription)'")
            }
            
            // Parse or suggest category
            var finalCategory: ImportCategory?
            if let catIndex = categoryColumnIndex,
               let csvCategory = row.indices.contains(catIndex) ? row[catIndex] : nil,
               !csvCategory.isEmpty {
                finalCategory = parseImportCategory(from: csvCategory) ?? suggestCategory(for: transactionDescription)
            } else {
                finalCategory = suggestCategory(for: transactionDescription)
            }
            
            // Update category distribution
            if let category = finalCategory {
                let categoryName = category.rawValue
                categoryDistribution[categoryName] = (categoryDistribution[categoryName] ?? 0) + 1
            }
            
            // Determine confidence based on presence of description and category
            let confidence: Double = {
                if !transactionDescription.isEmpty && transactionDescription != "Transaction \(rowIndex + 1)" {
                    return finalCategory != nil ? 0.9 : 0.7 // Higher confidence with both description and category
                } else {
                    return finalCategory != nil ? 0.6 : 0.4 // Lower confidence without proper description
                }
            }()
            
            // Determine if necessary based on category and description
            let isNecessary: Bool? = finalCategory?.toExpenseCategory().isTypicallyNecessary
            
            // Create transaction
            let transaction = ImportedTransaction(
                date: date!,
                description: transactionDescription,
                amount: abs(rawAmount),
                rawText: row.joined(separator: ","),
                confidence: confidence,
                suggestedCategory: finalCategory,
                isNecessary: isNecessary
            )
            
            transactions.append(transaction)
        }
        
        // Log summary information
        print("CSV Import Summary:")
        print("- Successfully parsed \(transactions.count) transactions")
        if let early = earliestDate, let late = latestDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            print("- Date range: \(formatter.string(from: early)) to \(formatter.string(from: late))")
        }
        print("- Total amount: $\(String(format: "%.2f", totalAmount))")
        
        // Log category distribution
        if !categoryDistribution.isEmpty {
            print("- Category distribution:")
            for (category, count) in categoryDistribution.sorted(by: { $0.value > $1.value }) {
                print("  • \(category): \(count) transactions")
            }
        }
        
        // Log sample transactions
        if !transactions.isEmpty {
            print("Sample transaction descriptions:")
            for i in 0..<min(5, transactions.count) {
                print("\(i+1): '\(transactions[i].description)' - $\(String(format: "%.2f", transactions[i].amount))")
            }
        }
        
        return transactions
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
