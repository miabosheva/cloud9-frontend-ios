import Foundation
import FirebaseFirestore
import FirebaseAuth

actor FirebaseManager {
    private let db = Firestore.firestore()
    private var cachedMetadata: [String: SleepData] = [:]
    private var pendingSyncIds: Set<String> = []
    private var isLoaded = false
    
    private var userId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    private var sleepCollection: CollectionReference? {
        guard let userId = userId else { return nil }
        return db.collection("users").document(userId).collection("sleep_data")
    }
    
    // MARK: - Save Methods
    
    func saveMetadata(_ sleepData: SleepData) async throws {
        // Update in-memory cache
        cachedMetadata[sleepData.id] = sleepData
        
        // Mark for sync if has metadata
        if sleepData.hasMetadata {
            pendingSyncIds.insert(sleepData.id)
        }
        
        // Attempt to sync to Firebase immediately
        try await syncToFirebase(sleepData)
    }
    
    private func syncToFirebase(_ sleepData: SleepData) async throws {
        guard let collection = sleepCollection else {
            throw SleepServiceError.userNotAuthenticated
        }
        
        do {
            var updatedSleepData = sleepData
            updatedSleepData.lastSyncedAt = Date()
            updatedSleepData.needsSync = false
            
            let documentData = try sleepDataToFirestoreData(updatedSleepData)
            
            try await collection.document(sleepData.id).setData(documentData)
            
            // Update cache with sync status
            cachedMetadata[sleepData.id] = updatedSleepData
            
            // Remove from pending sync
            pendingSyncIds.remove(sleepData.id)
            
            print("Successfully synced sleep data to Firebase: \(sleepData.id)")
            
        } catch {
            print("Failed to sync to Firebase: \(error)")
            // Keep in pending sync for retry
            pendingSyncIds.insert(sleepData.id)
            throw SleepServiceError.syncFailed(error)
        }
    }
    
    // MARK: - Load Methods
    
    func loadAllMetadata() -> [String: SleepData] {
        return cachedMetadata
    }
    
    func loadMetadataFromFirebase() async throws -> [String: SleepData] {
        guard let collection = sleepCollection else {
            throw SleepServiceError.userNotAuthenticated
        }
        
        do {
            let snapshot = try await collection.getDocuments()
            var metadata: [String: SleepData] = [:]
            
            for document in snapshot.documents {
                if let sleepData = try? firestoreDataToSleepData(document.data(), id: document.documentID) {
                    metadata[sleepData.id] = sleepData
                }
            }
            
            // Update cache
            cachedMetadata = metadata
            isLoaded = true
            
            return metadata
        } catch {
            throw SleepServiceError.loadFailed(error)
        }
    }
    
    func ensureDataLoaded() async throws {
        if !isLoaded {
            _ = try await loadMetadataFromFirebase()
        }
    }
    
    // MARK: - Sync Methods
    
    func syncPendingMetadata() async throws {
        for id in pendingSyncIds {
            if let sleepData = cachedMetadata[id] {
                try await syncToFirebase(sleepData)
            }
        }
    }
    
    func refreshFromFirebase() async throws {
        let remoteMetadata = try await loadMetadataFromFirebase()
        
        // Merge with any unsaved local changes
        for (id, localSleepData) in cachedMetadata {
            if localSleepData.needsSync || pendingSyncIds.contains(id) {
                // Keep local changes that haven't been synced
                continue
            }
            
            if let remoteSleepData = remoteMetadata[id] {
                // Remote version exists, check which is newer
                if let remoteSync = remoteSleepData.lastSyncedAt,
                   let localSync = localSleepData.lastSyncedAt,
                   remoteSync > localSync {
                    cachedMetadata[id] = remoteSleepData
                }
            }
        }
        
        // Add any new remote data
        for (id, remoteSleepData) in remoteMetadata {
            if cachedMetadata[id] == nil {
                cachedMetadata[id] = remoteSleepData
            }
        }
    }
    
    // MARK: - Delete Methods
    
    func deleteMetadata(for sleepDataId: String) async throws {
        // Delete from Firebase
        if let collection = sleepCollection {
            try await collection.document(sleepDataId).delete()
        }
        
        // Remove from cache
        cachedMetadata.removeValue(forKey: sleepDataId)
        pendingSyncIds.remove(sleepDataId)
        
        print("Deleted metadata for sleep ID: \(sleepDataId)")
    }
    
    // MARK: - Batch Operations
    
    func batchSave(_ sleepDataArray: [SleepData]) async throws {
        guard let collection = sleepCollection else {
            throw SleepServiceError.userNotAuthenticated
        }
        
        let batch = db.batch()
        
        for sleepData in sleepDataArray {
            var updatedSleepData = sleepData
            updatedSleepData.lastSyncedAt = Date()
            updatedSleepData.needsSync = false
            
            let documentData = try sleepDataToFirestoreData(updatedSleepData)
            let docRef = collection.document(sleepData.id)
            
            batch.setData(documentData, forDocument: docRef)
            
            // Update cache
            cachedMetadata[sleepData.id] = updatedSleepData
            pendingSyncIds.remove(sleepData.id)
        }
        
        try await batch.commit()
        print("Successfully batch saved \(sleepDataArray.count) sleep data records")
    }
    
    // MARK: - Query Methods
    
    func loadMetadataForDateRange(from startDate: Date, to endDate: Date) async throws -> [SleepData] {
        guard let collection = sleepCollection else {
            throw SleepServiceError.userNotAuthenticated
        }
        
        let snapshot = try await collection
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("date", isLessThanOrEqualTo: Timestamp(date: endDate))
            .getDocuments()
        
        var sleepDataArray: [SleepData] = []
        
        for document in snapshot.documents {
            if let sleepData = try? firestoreDataToSleepData(document.data(), id: document.documentID) {
                sleepDataArray.append(sleepData)
                // Update cache
                cachedMetadata[sleepData.id] = sleepData
            }
        }
        
        return sleepDataArray
    }
    
    func loadMetadataWithQuality(_ quality: SleepQuality) async throws -> [SleepData] {
        guard let collection = sleepCollection else {
            throw SleepServiceError.userNotAuthenticated
        }
        
        let snapshot = try await collection
            .whereField("sleepQuality", isEqualTo: quality.rawValue)
            .getDocuments()
        
        var sleepDataArray: [SleepData] = []
        
        for document in snapshot.documents {
            if let sleepData = try? firestoreDataToSleepData(document.data(), id: document.documentID) {
                sleepDataArray.append(sleepData)
                // Update cache
                cachedMetadata[sleepData.id] = sleepData
            }
        }
        
        return sleepDataArray
    }
    // MARK: - Cache Management
    
    func clearCache() {
        cachedMetadata.removeAll()
        pendingSyncIds.removeAll()
        isLoaded = false
    }
    
    func getCacheStatus() -> (totalRecords: Int, pendingSync: Int, isLoaded: Bool) {
        return (cachedMetadata.count, pendingSyncIds.count, isLoaded)
    }
    
    // MARK: - Helper Methods
    
    private func sleepDataToFirestoreData(_ sleepData: SleepData) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        
        let data = try encoder.encode(sleepData)
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SleepServiceError.encodingFailed
        }
        
        return dictionary
    }
    
    private func firestoreDataToSleepData(_ data: [String: Any], id: String) throws -> SleepData {
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        
        var sleepData = try decoder.decode(SleepData.self, from: jsonData)
        sleepData.id = id // Ensure the ID matches the document ID
        
        return sleepData
    }
}
