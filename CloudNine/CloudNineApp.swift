import SwiftUI
import SwiftData
import FirebaseCore

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
    
    init() {
        guard let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: filePath) else {
            fatalError("Failed to setup firebase")
        }
        
        FirebaseApp.configure(options: options)
    }
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
//        .modelContainer(sharedModelContainer)
    }
}
