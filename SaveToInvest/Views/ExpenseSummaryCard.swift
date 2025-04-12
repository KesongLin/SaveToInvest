//
//  ExpenseSummaryCard.swift
//  SaveToInvest
//
//  Created on 4/2/25.
//

import SwiftUI

struct ExpenseSummaryCard: View {
    let categorySummaries: [CategorySummary]
    
    var body: some View {
        VStack {
            ForEach(categorySummaries.prefix(5)) { summary in
                HStack {
                    Image(systemName: summary.category.icon)
                        .frame(width: 30)
                    
                    Text(summary.category.rawValue)
                    
                    Spacer()
                    
                    Text("$\(summary.totalAmount, specifier: "%.2f")")
                        .fontWeight(.medium)
                }
                .padding(.vertical, 5)
                
                if summary.id != categorySummaries.prefix(5).last?.id {
                    Divider()
                }
            }
            
            if categorySummaries.count > 5 {
                Button(action: {}) {
                    Text("View All")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.top, 5)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// Preview provider for SwiftUI canvas
struct ExpenseSummaryCard_Previews: PreviewProvider {
    static var previews: some View {
        ExpenseSummaryCard(
            categorySummaries: [
                CategorySummary(
                    category: .food,
                    totalAmount: 250.0,
                    isNecessary: true
                ),
                CategorySummary(
                    category: .entertainment,
                    totalAmount: 150.0,
                    isNecessary: false
                ),
                CategorySummary(
                    category: .transportation,
                    totalAmount: 200.0,
                    isNecessary: true
                )
            ]
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
