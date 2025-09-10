import SwiftUI
import SwiftData
import HealthKit

@main
struct CloudNineApp: App {
//    var sharedModelContainer: ModelContainer = {
//        let schema = Schema([
//            Item.self,
//        ])
//        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
//        
//        do {
//            return try ModelContainer(for: schema, configurations: [modelConfiguration])
//        } catch {
//            fatalError("Could not create ModelContainer: \(error)")
//        }
//    }()
    @State var errorManager = ErrorManager()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(errorManager)
        }
//        .modelContainer(sharedModelContainer)
    }
}
