import SwiftUI
import SwiftData
import HealthKit

@main
struct CloudNineApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @State private var healthKitManager = HealthKitManager()
    
    var body: some Scene {
        WindowGroup {
            if healthKitManager.healthStore != nil {
                MainTabView()
                    .environmentObject(healthKitManager)
                    .task {
                        // Request authorization when the app launches and HealthKit is available
                        do {
                            try await healthKitManager.requestAuthorization()
//                            setupDataObservationAndFetch()
                        } catch {
                            print("Initial HealthKit setup failed: \(error.localizedDescription)")
                        }
                    }
            } else {
                ErrorView(description: "This device does not support HealthKit.")
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
