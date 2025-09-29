import SwiftUI

struct SleepDebtCard: View {
    let sleepDebtResult: AutomatedSleepDebtResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(severityColor.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: severityIcon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(severityColor)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(sleepDebtResult.dataQuality.grade)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(dataQualityColor)
                        
                        Text("\(sleepDebtResult.confidenceLevel)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sleep Debt")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .bottom) {
                        Text(sleepDebtResult.baseResult.formattedTotalDebt)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(sleepDebtResult.baseResult.severity.rawValue.lowercased())
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(severityColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Efficiency")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(sleepDebtResult.baseResult.efficiency))%")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: sleepDebtResult.baseResult.efficiency / 100.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: efficiencyColor))
                        .scaleEffect(y: 0.6)
                }
                
                if !sleepDebtResult.baseResult.missingDays.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        
                        Text("\(sleepDebtResult.baseResult.missingDays.count) missing days")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .frame(width: 180, alignment: .leading)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Computed Properties
    private var severityColor: Color {
        switch sleepDebtResult.baseResult.severity {
        case .minimal: return .green
        case .moderate: return .yellow
        case .significant: return .orange
        case .severe: return .red
        }
    }
    
    private var severityIcon: String {
        switch sleepDebtResult.baseResult.severity {
        case .minimal: return "checkmark.circle.fill"
        case .moderate: return "exclamationmark.circle.fill"
        case .significant: return "exclamationmark.triangle.fill"
        case .severe: return "xmark.circle.fill"
        }
    }
    
    private var dataQualityColor: Color {
        switch sleepDebtResult.dataQuality.grade {
        case "A": return .green
        case "B": return .blue
        case "C": return .orange
        case "D": return .red
        default: return .gray
        }
    }
    
    private var efficiencyColor: Color {
        let efficiency = sleepDebtResult.baseResult.efficiency
        switch efficiency {
        case 90...: return .green
        case 70..<90: return .blue
        case 50..<70: return .orange
        default: return .red
        }
    }
}
