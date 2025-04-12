//
//  SavingsBreakdownComponents.swift
//  SaveToInvest
//
//  Created by Kesong Lin on 4/2/25.
//



import SwiftUI

struct ExpenseBreakdownCard: View {
    let expenseTitle: String
    let monthlyAmount: Double
    let reductionPercentages: [Int] = [25, 50, 75]
    let onSelect: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with expense name and amount
            HStack {
                Text(expenseTitle)
                    .font(.headline)
                
                Spacer()
                
                Text("$\(String(format: "%.2f", monthlyAmount))/mo")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            // Divider
            Divider()
            
            // Reduction options
            HStack {
                Text("Reduce by:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Reduction buttons
            HStack {
                ForEach(reductionPercentages, id: \.self) { percentage in
                    Button(action: {
                        onSelect(percentage)
                    }) {
                        VStack(spacing: 2) {
                            Text("\(percentage)%")
                                .font(.caption)
                                .fontWeight(.bold)
                            
                            Text("$\(String(format: "%.2f", monthlyAmount * Double(percentage) / 100.0))")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.primary)
                        .cornerRadius(5)
                    }
                    
                    if percentage != reductionPercentages.last {
                        Spacer()
                    }
                }
            }
            
            // Savings impact
            VStack(alignment: .leading, spacing: 4) {
                Text("Annual savings potential:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    ForEach(reductionPercentages, id: \.self) { percentage in
                        VStack {
                            Text("\(percentage)%:")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            
                            Text("$\(String(format: "%.0f", monthlyAmount * Double(percentage) / 100.0 * 12))")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                        }
                        
                        if percentage != reductionPercentages.last {
                            Spacer()
                        }
                    }
                }
            }
            .padding(.top, 5)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct SavingsGoalProgress: View {
    let currentSavings: Double
    let targetSavings: Double
    let timeframe: String
    
    var progress: Double {
        if targetSavings <= 0 {
            return 0
        }
        return min(currentSavings / targetSavings, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("Savings Goal Progress")
                    .font(.headline)
                
                Spacer()
                
                Text(timeframe)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 10)
                        .cornerRadius(5)
                    
                    // Progress
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * CGFloat(progress), height: 10)
                        .cornerRadius(5)
                }
            }
            .frame(height: 10)
            
            // Progress text
            HStack {
                Text("$\(String(format: "%.2f", currentSavings))")
                    .font(.subheadline)
                    .foregroundColor(.green)
                
                Spacer()
                
                Text("Goal: $\(String(format: "%.2f", targetSavings))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Progress percentage
            Text("\(Int(progress * 100))% complete")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct InvestmentComparisonCard: View {
    let investments: [Investment]
    let selectedTimeframe: Int
    let monthlySavings: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            Text("Investment Comparison")
                .font(.headline)
            
            // Description
            Text("Projected value of $\(String(format: "%.2f", monthlySavings))/mo after \(selectedTimeframe) years")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Divider
            Divider()
            
            // Investment comparison
            VStack(spacing: 15) {
                ForEach(investments.prefix(3), id: \.id) { investment in
                    investmentComparisonRow(investment: investment)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func investmentComparisonRow(investment: Investment) -> some View {
        // Calculate projected value
        let rate = investment.annualizedReturn / 100 / 12 // Monthly rate
        let months = Double(selectedTimeframe * 12)
        let futureValue = monthlySavings * ((pow(1 + rate, months) - 1) / rate)
        
        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(investment.name)
                    .font(.subheadline)
                
                HStack {
                    Text("Avg: \(String(format: "%.1f", investment.annualizedReturn))%")
                        .font(.caption)
                    
                    Text("Risk: \(investment.riskLevel.rawValue)")
                        .font(.caption)
                        .foregroundColor(riskLevelColor(investment.riskLevel))
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("$\(String(format: "%.0f", futureValue))")
                .font(.headline)
                .foregroundColor(.green)
        }
        .padding(.vertical, 5)
    }
    
    private func riskLevelColor(_ riskLevel: RiskLevel) -> Color {
        switch riskLevel {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}

struct DailyHabitSavingsCard: View {
    struct HabitSaving {
        let name: String
        let icon: String
        let dailyCost: Double
        let frequency: Int // times per week
    }
    
    let habits: [HabitSaving] = [
        HabitSaving(name: "Coffee Shop", icon: "cup.and.saucer.fill", dailyCost: 5.0, frequency: 5),
        HabitSaving(name: "Lunch Out", icon: "takeoutbag.and.cup.and.straw.fill", dailyCost: 15.0, frequency: 5),
        HabitSaving(name: "Rideshare", icon: "car.fill", dailyCost: 20.0, frequency: 3),
        HabitSaving(name: "Impulse Buy", icon: "bag.fill", dailyCost: 10.0, frequency: 2)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            Text("Daily Habit Savings")
                .font(.headline)
            
            // Description
            Text("Small changes can lead to big savings")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Divider
            Divider()
            
            // Habits
            VStack(spacing: 12) {
                ForEach(habits, id: \.name) { habit in
                    habitRow(habit: habit)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func habitRow(habit: HabitSaving) -> some View {
        // Calculate savings
        let weeklyCost = habit.dailyCost * Double(habit.frequency)
        let monthlyCost = weeklyCost * 4.3
        let yearlyCost = monthlyCost * 12
        
        // Calculate reduced frequencies
        let reducedFrequency1 = max(0, habit.frequency - 1)
        let reducedFrequency2 = max(0, habit.frequency - 2)
        
        // Calculate savings
        let reducedWeeklyCost1 = habit.dailyCost * Double(reducedFrequency1)
        let reducedWeeklyCost2 = habit.dailyCost * Double(reducedFrequency2)
        
        let weeklySavings1 = weeklyCost - reducedWeeklyCost1
        let weeklySavings2 = weeklyCost - reducedWeeklyCost2
        
        let yearlySavings1 = weeklySavings1 * 52
        let yearlySavings2 = weeklySavings2 * 52
        
        return VStack(alignment: .leading, spacing: 8) {
            // Habit header
            HStack {
                Image(systemName: habit.icon)
                    .foregroundColor(.blue)
                
                Text(habit.name)
                    .font(.subheadline)
                
                Spacer()
                
                Text("$\(String(format: "%.0f", yearlyCost))/yr")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
            
            // Savings options
            HStack {
                if habit.frequency > 0 {
                    VStack {
                        Text("\(habit.frequency)→\(reducedFrequency1)x/wk")
                            .font(.caption)
                        
                        Text("Save $\(String(format: "%.0f", yearlySavings1))/yr")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(5)
                }
                
                if habit.frequency > 1 {
                    Spacer()
                    
                    VStack {
                        Text("\(habit.frequency)→\(reducedFrequency2)x/wk")
                            .font(.caption)
                        
                        Text("Save $\(String(format: "%.0f", yearlySavings2))/yr")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(5)
                }
            }
        }
    }
}

// MARK: - Preview

struct SavingsBreakdownComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ExpenseBreakdownCard(
                expenseTitle: "Coffee Shop",
                monthlyAmount: 100.0,
                onSelect: { _ in }
            )
            
            SavingsGoalProgress(
                currentSavings: 500,
                targetSavings: 1000,
                timeframe: "Monthly"
            )
            
            InvestmentComparisonCard(
                investments: Investment.defaultOptions,
                selectedTimeframe: 10,
                monthlySavings: 200
            )
            
            DailyHabitSavingsCard()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
