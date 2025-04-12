//
//  SavingsInsightsView.swift
//  SaveToInvest
//
//  Created by Kesong Lin on 4/2/25.
//



import SwiftUI

struct SavingsInsightsView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @EnvironmentObject private var expenseAnalyzer: ExpenseAnalyzer
    
    @State private var riskTolerance: RiskTolerance = .moderate
    @State private var savingsTarget: Double?
    @State private var savingsPlan: SavingsAndInvestmentPlan?
    @State private var specificSavings: [SpecificSaving] = []
    @State private var isGeneratingPlan = false
    @State private var showSavingTargetInput = false
    @State private var customSavingsTargetText = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Savings potential header
                savingsPotentialHeader
                
                // Savings scenarios
                savingsScenariosSection
                
                // Risk tolerance selection
                riskToleranceSection
                
                // Specific savings opportunities
                specificSavingsSection
                
                // Recommended investment plan
                if let plan = savingsPlan {
                    recommendedInvestmentSection(plan: plan)
                }
                
                // Future value projections
                if let plan = savingsPlan, !plan.totalProjections.isEmpty {
                    futureValueProjectionsSection(projections: plan.totalProjections)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .navigationTitle("Savings Insights")
        .onAppear {
            loadSavingsInsights()
        }
        .alert("Enter Monthly Savings Target", isPresented: $showSavingTargetInput) {
            TextField("Amount", text: $customSavingsTargetText)
                .keyboardType(.decimalPad)
            
            Button("Cancel", role: .cancel) {
                showSavingTargetInput = false
            }
            
            Button("OK") {
                if let amount = Double(customSavingsTargetText) {
                    savingsTarget = amount
                    generateSavingsPlan()
                }
                showSavingTargetInput = false
            }
        }
    }
    
    // MARK: - View Components
    
    private var savingsPotentialHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Savings Potential")
                .font(.title2)
                .fontWeight(.bold)
            
            if expenseAnalyzer.unnecessaryExpenses.isEmpty {
                Text("Add expenses to see your savings potential")
                    .foregroundColor(.secondary)
            } else {
                Text("Based on your current spending habits, you could save:")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var savingsScenariosSection: some View {
        VStack(spacing: 15) {
            if let plan = savingsPlan {
                savingsScenarioCard(
                    percentage: "20%",
                    amount: plan.savingsPotential.savingsAt20Percent,
                    description: "Conservative goal",
                    isSelected: savingsTarget == plan.savingsPotential.savingsAt20Percent
                )
                .onTapGesture {
                    savingsTarget = plan.savingsPotential.savingsAt20Percent
                    generateSavingsPlan()
                }
                
                savingsScenarioCard(
                    percentage: "50%",
                    amount: plan.savingsPotential.savingsAt50Percent,
                    description: "Moderate goal",
                    isSelected: savingsTarget == plan.savingsPotential.savingsAt50Percent || savingsTarget == nil
                )
                .onTapGesture {
                    savingsTarget = plan.savingsPotential.savingsAt50Percent
                    generateSavingsPlan()
                }
                
                savingsScenarioCard(
                    percentage: "70%",
                    amount: plan.savingsPotential.savingsAt70Percent,
                    description: "Ambitious goal",
                    isSelected: savingsTarget == plan.savingsPotential.savingsAt70Percent
                )
                .onTapGesture {
                    savingsTarget = plan.savingsPotential.savingsAt70Percent
                    generateSavingsPlan()
                }
                
                Button(action: {
                    showSavingTargetInput = true
                }) {
                    Text("Set Custom Savings Target")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.vertical, 5)
                }
            } else if isGeneratingPlan {
                ProgressView("Calculating savings potential...")
            } else {
                Button(action: {
                    generateSavingsPlan()
                }) {
                    Text("Generate Savings Plan")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
        }
    }
    
    private func savingsScenarioCard(percentage: String, amount: Double, description: String, isSelected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("Save \(percentage)")
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 5) {
                Text("$\(String(format: "%.2f", amount))/mo")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Text("$\(String(format: "%.2f", amount * 12))/yr")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .padding(.leading, 5)
            }
        }
        .padding()
        .background(isSelected ? Color.green.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.green : Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var riskToleranceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Investment Risk Tolerance")
                .font(.headline)
            
            Picker("Risk Tolerance", selection: $riskTolerance) {
                ForEach(RiskTolerance.allCases, id: \.self) { tolerance in
                    Text(tolerance.rawValue).tag(tolerance)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: riskTolerance) { _ in
                generateSavingsPlan()
            }
            
            Text(riskTolerance.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var specificSavingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Specific Savings Opportunities")
                .font(.headline)
            
            if specificSavings.isEmpty {
                Text("No specific savings opportunities identified")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(specificSavings, id: \.name) { saving in
                    specificSavingRow(saving: saving)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func specificSavingRow(saving: SpecificSaving) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: saving.icon)
                    .foregroundColor(.blue)
                
                Text(saving.name)
                    .font(.headline)
                
                Spacer()
                
                Text("$\(String(format: "%.2f", saving.currentMonthlyCost))/mo")
                    .font(.subheadline)
            }
            
            Divider()
            
            HStack {
                ForEach(saving.reductionOptions, id: \.percentage) { option in
                    VStack {
                        Text("\(option.percentage)%")
                            .font(.caption)
                            .fontWeight(.bold)
                        
                        Text("$\(String(format: "%.2f", option.savings))")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(5)
                    
                    if option.percentage != saving.reductionOptions.last?.percentage {
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 5)
    }
    
    private func recommendedInvestmentSection(plan: SavingsAndInvestmentPlan) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Recommended Investment Allocation")
                .font(.headline)
            
            Text("Based on your risk tolerance and savings goal")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if plan.recommendedInvestments.isEmpty {
                Text("No investment recommendations available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 15) {
                    ForEach(plan.recommendedInvestments, id: \.investment.id) { recommended in
                        recommendedInvestmentRow(recommended: recommended)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func recommendedInvestmentRow(recommended: RecommendedInvestment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recommended.investment.name)
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(recommended.allocationPercentage))%")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Risk: \(recommended.investment.riskLevel.rawValue)")
                        .font(.caption)
                    
                    Text("Return: \(String(format: "%.2f", recommended.investment.annualizedReturn))%")
                        .font(.caption)
                }
                
                Spacer()
                
                Text("$\(String(format: "%.2f", recommended.monthlyAmount))/mo")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 5)
        .background(Color(.systemBackground))
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func futureValueProjectionsSection(projections: [InvestmentProjection]) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Future Value Projections")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(projections.sorted(by: { $0.years < $1.years }), id: \.years) { projection in
                        futureValueCard(projection: projection)
                    }
                }
                .padding(.horizontal, 5)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func futureValueCard(projection: InvestmentProjection) -> some View {
        VStack(spacing: 10) {
            Text("\(projection.years) \(projection.years == 1 ? "Year" : "Years")")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color.blue)
                .cornerRadius(5)
            
            Text("$\(String(format: "%.2f", projection.futureValue))")
                .font(.title3)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Contributions:")
                        .font(.caption)
                    Spacer()
                    Text("$\(String(format: "%.2f", projection.totalContributions))")
                        .font(.caption)
                }
                
                HStack {
                    Text("Interest Earned:")
                        .font(.caption)
                    Spacer()
                    Text("$\(String(format: "%.2f", projection.interestEarned))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Growth:")
                        .font(.caption)
                    Spacer()
                    if projection.totalContributions > 0 {
                        Text("\(String(format: "%.1f", (projection.futureValue / projection.totalContributions - 1) * 100))%")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("N/A")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 5)
        }
        .padding()
        .frame(width: 170)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Methods
    
    private func loadSavingsInsights() {
        generateSavingsPlan()
        specificSavings = viewModel.calculateSpecificSavings()
    }
    
    private func generateSavingsPlan() {
        isGeneratingPlan = true
        
        DispatchQueue.main.async {
            self.savingsPlan = self.viewModel.generateSavingsAndInvestmentPlan(
                riskTolerance: self.riskTolerance,
                savingsTarget: self.savingsTarget
            )
            self.isGeneratingPlan = false
        }
    }
}

struct SavingsInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        SavingsInsightsView()
            .environmentObject(MainViewModel())
            .environmentObject(ExpenseAnalyzer(firebaseService: FirebaseService()))
    }
}
