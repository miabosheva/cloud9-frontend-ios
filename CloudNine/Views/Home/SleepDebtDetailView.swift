import SwiftUI

struct SleepDebtDetailView: View {
    let sleepDebtResult: AutomatedSleepDebtResult?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let result = sleepDebtResult {
                    VStack(spacing: 24) {
                        // Summary Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Sleep Debt Summary")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            // Add detailed breakdown here
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Total Debt: \(result.baseResult.formattedTotalDebt)")
                                Text("Severity: \(result.baseResult.severity.rawValue)")
                                Text("Efficiency: \(Int(result.baseResult.efficiency))%")
                                Text("Confidence: \(result.confidenceLevel)")
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Recommendations
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recommendations")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            ForEach(result.recommendations.indices, id: \.self) { index in
                                let recommendation = result.recommendations[index]
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recommendation.title)
                                        .font(.headline)
                                    Text(recommendation.description)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                } else {
                    Text("No sleep debt data available")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Sleep Debt Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SleepDebtDetailView(sleepDebtResult: nil)
}
