//
//  Extensions.swift
//  SaveToInvest
//
//  Created on 4/17/25.
//

import Foundation

extension String {
    func sanitizedForFirestore() -> String {
        // Create a safe string for use as a Firestore document ID or path
        let sanitized = self
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "*", with: "-")
            .replacingOccurrences(of: "[", with: "(")
            .replacingOccurrences(of: "]", with: ")")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "#", with: "-")
        
        // Ensure it's not empty and not too long for Firestore
        if sanitized.isEmpty {
            return "unnamed-" + UUID().uuidString
        }
        
        // Limit length for Firestore document IDs
        if sanitized.count > 1500 {
            return String(sanitized.prefix(1500))
        }
        
        return sanitized
    }
}
