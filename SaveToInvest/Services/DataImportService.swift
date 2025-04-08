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
        
        // Identify required column indices
        guard let dateColumnIndex = headerLowercased.firstIndex(where: { $0.contains("date") }),
              let descColumnIndex = headerLowercased.firstIndex(where: { $0.contains("descr") ||
                                                                $0.contains("memo") ||
                                                                $0.contains("narration") ||
                                                                $0.contains("transaction") }),
              let amountColumnIndex = headerLowercased.firstIndex(where: { $0.contains("amount") ||
                                                                  $0.contains("sum") ||
                                                                  $0.contains("value") ||
                                                                  $0.contains("payment") })
        else {
            print("Missing required columns in CSV")
            return []
        }
        
        let categoryColumnIndex = headerLowercased.firstIndex(where: { $0.contains("category") })
        
        // Gather data about amount signs to determine card type
        var positiveCount = 0
        var negativeCount = 0
        var rows: [[String]] = []
        
        for i in 1..<lines.count {
            let row = parseCSVRow(lines[i])
            if row.count >= max(dateColumnIndex, descColumnIndex, amountColumnIndex) + 1 {
                rows.append(row)
                
                if let amountString = row.indices.contains(amountColumnIndex) ? row[amountColumnIndex] : nil {
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
        print("Determined card type: \(isCreditCard ? "Credit Card" : "Debit Card") (positive: \(positiveCount), negative: \(negativeCount))")
        
        // Parse date formats
        let dateFormatter = DateFormatter()
        let possibleDateFormats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy/MM/dd", "M/d/yyyy", "d/M/yyyy"]
        
        // Process each row
        for row in rows {
            guard let dateString = row.indices.contains(dateColumnIndex) ? row[dateColumnIndex] : nil,
                  let desc = row.indices.contains(descColumnIndex) ? row[descColumnIndex] : nil,
                  let amountString = row.indices.contains(amountColumnIndex) ? row[amountColumnIndex] : nil
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
            if date == nil { continue }
            
            // Parse amount
            let cleanAmountStr = amountString
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: "")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard let rawAmount = Double(cleanAmountStr) else { continue }
            
            // Apply card type filter
            if isCreditCard && rawAmount < 0 { continue }
            if !isCreditCard && rawAmount > 0 { continue }
            
            // Parse or suggest category
            var finalCategory: ImportCategory?
            if let catIndex = categoryColumnIndex,
               let csvCategory = row.indices.contains(catIndex) ? row[catIndex] : nil {
                finalCategory = parseImportCategory(from: csvCategory) ?? suggestCategory(for: desc)
            } else {
                finalCategory = suggestCategory(for: desc)
            }
            
            // Create transaction
            let transaction = ImportedTransaction(
                date: date!,
                description: desc,
                amount: abs(rawAmount),
                rawText: row.joined(separator: ","),
                suggestedCategory: finalCategory,
                isNecessary: nil
            )
            transactions.append(transaction)
        }
        
        print("Successfully parsed \(transactions.count) transactions from CSV")
        return transactions
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
