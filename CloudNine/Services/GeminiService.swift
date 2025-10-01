import Foundation
import GoogleGenerativeAI

enum API {
    static var apiKey = Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String
}

struct GeminiRequest: Codable {
    let contents: [Content]
    
    struct Content: Codable {
        let parts: [Part]
    }
    
    struct Part: Codable {
        let text: String
    }
}

struct GeminiResponse: Codable {
    let candidates: [Candidate]
    
    struct Candidate: Codable {
        let content: Content
    }
    
    struct Content: Codable {
        let parts: [Part]
    }
    
    struct Part: Codable {
        let text: String
    }
}

enum GeminiError: Error {
    case invalidURL
    case noResponse
    case decodingError
    case apiError(String)
}

class GeminiService {
    
    func analyzeDream(
        userInfo: UserInfo,
        sleepData: SleepData
    ) async throws -> String {
        let model = GenerativeModel(name: "gemini-2.5-flash-lite", apiKey: API.apiKey ?? "")
        var output: String = ""
        let prompt = try buildPrompt(userInfo: userInfo, sleepData: sleepData)
        let response = try await model.generateContent(prompt)
        if let text = response.text {
            output = text
        }
        return output
    }
    
    private func buildPrompt(userInfo: UserInfo, sleepData: SleepData) throws -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        
        let bedtimeString = dateFormatter.string(from: userInfo.bedtime)
        let wakeTimeString = dateFormatter.string(from: userInfo.wakeTime)
        
        let conditionsString = userInfo.sleepConditions.isEmpty
        ? "None reported"
        : userInfo.sleepConditions.map { "\($0)" }.joined(separator: ", ")
        
        guard let description = sleepData.description else { throw HealthError.failedToCreateType }
        guard let sleepQuality = sleepData.sleepQuality?.numericValue else { throw HealthError.failedToCreateType }
        
        return """
        As a sleep analyst, provide personalized sleep insights based on the following dream and user information.
        
        **Dream Description:**
        \(description)
        
        **User Sleep Profile:**
        - Name: \(userInfo.firstName) \(userInfo.lastName)
        - Bedtime for that day: \(sleepData.wakeTime)
        - Wake Time for that day: \(sleepData.bedtime)
        - Quality rank for that dream (1-5): \(sleepQuality)
        - Target Sleep Duration: \(userInfo.sleepDuration) hours
        - Tracking Goal: \(userInfo.trackingGoal)
        - Sleep Conditions: \(conditionsString)
        - Height: \(userInfo.height) cm
        - Weight: \(userInfo.weight) kg
        
        Provide a comprehensive sleep insight that:
        1. Analyzes potential connections between the dream content and sleep quality
        2. Considers the user's sleep schedule and conditions
        3. Offers personalized recommendations for better sleep
        4. Identifies any potential sleep-related concerns from the dream
        5. Suggests lifestyle adjustments based on their tracking goal
        
        Keep the insight concise (200-300 words), actionable, and empathetic.
        """
    }
}
