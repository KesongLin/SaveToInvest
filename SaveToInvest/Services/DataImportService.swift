//
//  DataImportService.swift
//  SaveToInvest
//
//  Created by Kesong Lin on 4/2/25.
//

import Foundation
import UIKit
import PDFKit

// 定义导入错误类型
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

// 导入的交易记录数据模型
struct ImportedTransaction: Identifiable {
    var id = UUID()
    var date: Date
    var description: String
    var amount: Double
    var rawText: String
    var confidence: Double = 0.5
    var suggestedCategory: ExpenseCategory?
    var isNecessary: Bool?
    
    // 转换为Expense对象
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
    
    // 处理PDF文件导入
    func importPDF(url: URL, completion: @escaping (Result<[ImportedTransaction], ImportError>) -> Void) {
        // Use native iOS PDF reading
        guard let pdfDocument = PDFDocument(url: url) else {
            completion(.failure(.fileReadError))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var extractedText = ""
            
            // Extract text from PDF
            for i in 0..<pdfDocument.pageCount {
                guard let page = pdfDocument.page(at: i) else { continue }
                extractedText += page.string ?? ""
            }
            
            if extractedText.isEmpty {
                DispatchQueue.main.async {
                    completion(.failure(.emptyData))
                }
                return
            }
            
            // Parse the text
            let transactions = self.parseTransactionsFromText(extractedText)
            
            DispatchQueue.main.async {
                if transactions.isEmpty {
                    completion(.failure(.parsingError))
                } else {
                    completion(.success(transactions))
                }
            }
        }
    }

    // Similarly, update the importCSV method:
    func importCSV(url: URL, completion: @escaping (Result<[ImportedTransaction], ImportError>) -> Void) {
        do {
            // Use Swift's native file reading
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
    
    // 解析文本提取交易数据的简单实现
    private func parseTransactionsFromText(_ text: String) -> [ImportedTransaction] {
        var transactions: [ImportedTransaction] = []
        
        // 按行分割文本
        let lines = text.components(separatedBy: .newlines)
        
        // 日期正则表达式模式 (支持多种日期格式)
        let datePatterns = [
            "\\d{2}/\\d{2}/\\d{4}", // MM/DD/YYYY
            "\\d{2}-\\d{2}-\\d{4}", // MM-DD-YYYY
            "\\d{4}/\\d{2}/\\d{2}", // YYYY/MM/DD
            "\\d{4}-\\d{2}-\\d{2}"  // YYYY-MM-DD
        ]
        
        // 金额正则表达式模式
        let amountPattern = "\\$?\\s*\\d+,?\\d*\\.?\\d+"
        
        for line in lines {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            // 尝试提取日期
            var foundDate: Date?
            var dateString = ""
            
            for pattern in datePatterns {
                if let range = line.range(of: pattern, options: .regularExpression) {
                    dateString = String(line[range])
                    
                    let dateFormatter = DateFormatter()
                    // 尝试不同的日期格式
                    for format in ["MM/dd/yyyy", "MM-dd-yyyy", "yyyy/MM/dd", "yyyy-MM-dd"] {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: dateString) {
                            foundDate = date
                            break
                        }
                    }
                    
                    if foundDate != nil {
                        break
                    }
                }
            }
            
            // 如果找不到日期，跳过此行
            guard let transactionDate = foundDate else { continue }
            
            // 尝试提取金额
            var amount: Double?
            if let range = line.range(of: amountPattern, options: .regularExpression) {
                let amountString = String(line[range])
                    .replacingOccurrences(of: "$", with: "")
                    .replacingOccurrences(of: ",", with: "")
                    .replacingOccurrences(of: " ", with: "")
                
                amount = Double(amountString)
            }
            
            // 如果找不到金额，跳过此行
            guard let transactionAmount = amount else { continue }
            
            // 提取描述 (删除日期和金额后的文本，简化处理)
            var description = line
                .replacingOccurrences(of: dateString, with: "")
            
            if let range = line.range(of: amountPattern, options: .regularExpression) {
                let amountStr = String(line[range])
                description = description.replacingOccurrences(of: amountStr, with: "")
            }
            
            description = description.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 创建交易记录
            let transaction = ImportedTransaction(
                date: transactionDate,
                description: description,
                amount: transactionAmount,
                rawText: line,
                suggestedCategory: suggestCategory(for: description),
                isNecessary: nil // 在分类阶段确定
            )
            
            transactions.append(transaction)
        }
        
        return transactions
    }
    
    // 解析CSV文件
    private func parseCSV(_ csvString: String) -> [ImportedTransaction] {
        var transactions: [ImportedTransaction] = []
        
        // 分割行
        let rows = csvString.components(separatedBy: .newlines)
        
        // 确保有数据
        guard rows.count > 1 else { return [] }
        
        // 提取标题行
        let headers = rows[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // 查找关键列索引
        var dateIndex = -1
        var descriptionIndex = -1
        var amountIndex = -1
        
        for (i, header) in headers.enumerated() {
            let headerLower = header.lowercased()
            if headerLower.contains("date") {
                dateIndex = i
            } else if headerLower.contains("descr") || headerLower.contains("memo") || headerLower.contains("narration") {
                descriptionIndex = i
            } else if headerLower.contains("amount") || headerLower.contains("sum") || headerLower.contains("value") {
                amountIndex = i
            }
        }
        
        // 确保找到了必要的列
        guard dateIndex >= 0, descriptionIndex >= 0, amountIndex >= 0 else { return [] }
        
        // 处理数据行
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd" // 默认格式，根据实际调整
        
        for i in 1..<rows.count {
            let row = rows[i]
            if row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            let columns = row.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            // 确保有足够的列
            guard columns.count > max(dateIndex, descriptionIndex, amountIndex) else { continue }
            
            // 提取日期
            let dateString = columns[dateIndex]
            guard let date = dateFormatter.date(from: dateString) else {
                // 尝试其他日期格式
                for format in ["MM/dd/yyyy", "dd/MM/yyyy", "yyyy/MM/dd"] {
                    dateFormatter.dateFormat = format
                    if let parsedDate = dateFormatter.date(from: dateString) {
                        dateFormatter.dateFormat = "yyyy-MM-dd" // 重置为默认格式
                        break
                    }
                }
                continue // 如果所有格式都不匹配，跳过此行
            }
            
            // 提取描述和金额
            let description = columns[descriptionIndex]
            let amountString = columns[amountIndex].replacingOccurrences(of: "\"", with: "")
                                                  .replacingOccurrences(of: "$", with: "")
                                                  .replacingOccurrences(of: ",", with: "")
            
            guard let amount = Double(amountString) else { continue }
            
            // 创建交易记录
            let transaction = ImportedTransaction(
                date: date,
                description: description,
                amount: amount,
                rawText: row,
                suggestedCategory: suggestCategory(for: description),
                isNecessary: nil // 在分类阶段确定
            )
            
            transactions.append(transaction)
        }
        
        return transactions
    }
    
    // 简单的类别建议函数
    private func suggestCategory(for description: String) -> ExpenseCategory {
        let desc = description.lowercased()
        
        if desc.contains("rent") || desc.contains("mortgage") || desc.contains("housing") {
            return .housing
        } else if desc.contains("grocery") || desc.contains("food") || desc.contains("restaurant") {
            return .food
        } else if desc.contains("uber") || desc.contains("lyft") || desc.contains("gas") || desc.contains("transport") {
            return .transportation
        } else if desc.contains("movie") || desc.contains("netflix") || desc.contains("entertainment") {
            return .entertainment
        } else if desc.contains("electric") || desc.contains("water") || desc.contains("utilities") {
            return .utilities
        } else if desc.contains("doctor") || desc.contains("medical") || desc.contains("health") {
            return .healthcare
        } else if desc.contains("amazon") || desc.contains("shop") || desc.contains("store") {
            return .shopping
        } else if desc.contains("tuition") || desc.contains("school") || desc.contains("education") {
            return .education
        } else if desc.contains("hotel") || desc.contains("flight") || desc.contains("travel") {
            return .travel
        }
        
        return .other
    }
    
    // 增量处理大数据集
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

