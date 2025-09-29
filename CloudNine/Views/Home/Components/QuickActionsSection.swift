import SwiftUI

// MARK: - Quick Actions Section
struct QuickActionsSection: View {
    @Binding var showingAddSleep: Bool
    let watchConnector: WatchConnector
    let navigationManager: NavigationManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    QuickActionCard(
                        title: "Add Sleep",
                        icon: "bed.double.fill",
                        color: .purple,
                        action: { showingAddSleep = true }
                    )
                    
                    QuickActionCard(
                        title: "Start Workout",
                        icon: "figure.run",
                        color: .green,
                        action: { watchConnector.startWorkout() }
                    )
                    
                    QuickActionCard(
                        title: "View Trends",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .blue,
                        action: { /* Navigate to trends */ }
                    )
                    
                    QuickActionCard(
                        title: "Settings",
                        icon: "gearshape.fill",
                        color: .gray,
                        action: { navigationManager.navigate(to: .profile) }
                    )
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
