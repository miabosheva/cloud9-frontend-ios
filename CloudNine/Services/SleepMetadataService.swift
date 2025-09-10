import Foundation

protocol SleepMetadataService {
    func saveMetadata(_ sleepData: SleepData) async throws
    func syncPendingMetadata() async throws
    func loadAllMetadata() -> [String: SleepData]
    func deleteAllMetadata() async throws
    func deleteMetadata(for sleepDataId: String) async throws
}
