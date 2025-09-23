import Foundation
import FirebaseFirestore
import FirebaseAuth

actor UserManager {
    private let db = Firestore.firestore()
    
    private var userId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    private var userDocumentRef: DocumentReference? {
        guard let userId = userId else { return nil }
        return db.collection("users").document(userId)
    }
    
    // MARK: - Fetch UserInfo
    
    func fetchUserInfo() async throws -> UserInfo {
        guard let documentRef = userDocumentRef else {
            throw UserManagerError.userNotAuthenticated
        }
        
        do {
            let document = try await documentRef.getDocument()
            
            guard document.exists else {
                throw UserManagerError.userInfoNotFound
            }
            
            guard let data = document.data(),
                  let userInfoData = data["userInfo"] as? [String: Any] else {
                throw UserManagerError.invalidUserInfoData
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: userInfoData)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            
            let userInfo = try decoder.decode(UserInfo.self, from: jsonData)
            return userInfo
            
        } catch {
            if error is UserManagerError {
                throw error
            }
            throw UserManagerError.fetchFailed(error)
        }
    }
    
    // MARK: - Save UserInfo
    
    func saveUserInfo(_ userInfo: UserInfo) async throws {
        guard let documentRef = userDocumentRef else {
            throw UserManagerError.userNotAuthenticated
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            
            let data = try encoder.encode(userInfo)
            guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw UserManagerError.encodingFailed
            }
            
            try await documentRef.updateData([
                "userInfo": dictionary,
                "lastUpdated": Timestamp(date: Date())
            ])
            
        } catch {
            if error is UserManagerError {
                throw error
            }
            throw UserManagerError.saveFailed(error)
        }
    }
    
    // MARK: - Update Partial UserInfo
    
    func updateUserInfo(_ updates: [String: Any]) async throws {
        guard let documentRef = userDocumentRef else {
            throw UserManagerError.userNotAuthenticated
        }
        
        do {
            // Create update dictionary with userInfo prefix
            var updateData: [String: Any] = [:]
            for (key, value) in updates {
                updateData["userInfo.\(key)"] = value
            }
            updateData["lastUpdated"] = Timestamp(date: Date())
            
            try await documentRef.updateData(updateData)
            
        } catch {
            throw UserManagerError.updateFailed(error)
        }
    }
    
    // MARK: - Check if UserInfo exists
    
    func userInfoExists() async throws -> Bool {
        guard let documentRef = userDocumentRef else {
            throw UserManagerError.userNotAuthenticated
        }
        
        do {
            let document = try await documentRef.getDocument()
            guard document.exists, let data = document.data() else {
                return false
            }
            
            return data["userInfo"] != nil
            
        } catch {
            throw UserManagerError.fetchFailed(error)
        }
    }
    
    // MARK: - Create User Document (for new users)
    
    func createUserDocument(email: String, userInfo: UserInfo? = nil) async throws {
        guard let documentRef = userDocumentRef else {
            throw UserManagerError.userNotAuthenticated
        }
        
        do {
            var userData: [String: Any] = [
                "email": email,
                "createdAt": Timestamp(date: Date()),
                "hasCompletedOnboarding": userInfo != nil
            ]
            
            if let userInfo = userInfo {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .millisecondsSince1970
                
                let data = try encoder.encode(userInfo)
                guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw UserManagerError.encodingFailed
                }
                
                userData["userInfo"] = dictionary
            }
            
            try await documentRef.setData(userData)
            
        } catch {
            if error is UserManagerError {
                throw error
            }
            throw UserManagerError.createUserFailed(error)
        }
    }
}
