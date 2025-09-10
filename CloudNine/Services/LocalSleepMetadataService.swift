import Foundation

class LocalSleepMetadataService: SleepMetadataService {
    private let userDefaults = UserDefaults.standard
    private let metadataKey = "sleep_metadata"
    
    func saveMetadata(_ sleepData: SleepData) async throws {
        var metadata = loadAllMetadata()
        metadata[sleepData.id] = sleepData
        
        let data = try JSONEncoder().encode(metadata)
        userDefaults.set(data, forKey: metadataKey)
    }
    
    func syncPendingMetadata() async throws {
        // Implement backend sync logic here
        print("Syncing pending metadata to backend...")
    }
    
    func loadAllMetadata() -> [String: SleepData] {
        guard let data = userDefaults.data(forKey: metadataKey),
              let metadata = try? JSONDecoder().decode([String: SleepData].self, from: data) else {
            return [:]
        }
        return metadata
    }
    
    func deleteAllMetadata() async throws {
        UserDefaults.standard.removeObject(forKey: metadataKey)
    }
    
    func deleteMetadata(for sleepDataId: String) async throws {
        var metadata = loadAllMetadata()
        metadata.removeValue(forKey: sleepDataId)
        
        let data = try JSONEncoder().encode(metadata)
        userDefaults.set(data, forKey: metadataKey)
        
        print("Deleted metadata for sleep ID: \(sleepDataId)")
    }
}
