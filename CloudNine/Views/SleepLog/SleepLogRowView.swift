import SwiftUI

struct SleepLogRowView: View {
    let sleepData: SleepData
    let onDelete: () -> Void
    let onSave: () -> Void
    
    @State var showDeleteAlert: Bool = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(sleepData.date, style: .date)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("Duration: \(sleepData.formattedDuration)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                HStack(spacing: 15) {
                    Label {
                        Text(sleepData.formattedBedtime)
                            .font(.caption)
                    } icon: {
                        Image(systemName: "bed.double.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Label {
                        Text(sleepData.formattedWakeTime)
                            .font(.caption)
                    } icon: {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    if let sleepQuality = sleepData.quality {
                        Text(sleepQuality.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(sleepData.qualityColor.opacity(0.2))
                            .foregroundColor(sleepData.qualityColor)
                            .cornerRadius(4)
                    }
                }
            }
            
            if sleepData.savedFlag {
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: {
                    onSave()
                }) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
        }
        .padding()
        .background(sleepData.savedFlag ? .green : Color.white.opacity(0.8))
        .cornerRadius(10)
        .shadow(radius: 1)
        .alert("Delete Sleep Log", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this sleep log entry? This action cannot be undone.")
        }
    }
}
