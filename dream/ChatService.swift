import Foundation
import SwiftData

// MARK: - Chat Response Models

/// Response from the AI chat API
struct ChatResponse {
    /// The raw text response from AI
    let text: String

    /// Extracted JSON data if present (from markdown code blocks)
    let extractedJSON: [String: Any]?

    /// Created Goal object if AI response contained a goal blueprint
    let createdGoal: Goal?

    /// Whether the response contains structured JSON data
    var hasJSON: Bool { extractedJSON != nil }

    /// Whether a new goal was created from this response
    var hasCreatedGoal: Bool { createdGoal != nil }

    init(text: String, extractedJSON: [String: Any]? = nil, createdGoal: Goal? = nil) {
        self.text = text
        self.extractedJSON = extractedJSON
        self.createdGoal = createdGoal
    }
}

/// API error types
enum ChatServiceError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case decodingError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "API service not configured. Please check Supabase Edge Function setup."
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let message):
            return "HTTP Error \(code): \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - API Response Models (OpenAI Compatible)

private struct APIResponse: Codable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Codable {
        let index: Int
        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }

    struct Message: Codable {
        let role: String
        let content: String
    }

    struct Usage: Codable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

private struct APIErrorResponse: Codable {
    let error: APIError

    struct APIError: Codable {
        let message: String
        let type: String?
        let code: String?
    }
}

// MARK: - Chat Service

/// Network layer for communicating with AI via Supabase Edge Function
final class ChatService {

    // MARK: - Singleton
    static let shared = ChatService()
    private init() {}

    // MARK: - Properties
    private let session = URLSession.shared
    private let promptManager = PromptManager.shared

    /// Maximum number of messages to fetch for history context
    private let maxHistoryCount = 10

    // MARK: - Supabase Configuration

    /// Supabase project URL
    private let supabaseURL = "https://fvvxpizfqoeknubjjcpr.supabase.co"

    /// Supabase anon key for authentication
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ2dnhwaXpmcW9la251YmpqY3ByIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwODU2NzEsImV4cCI6MjA4MjY2MTY3MX0.m7iIvF1BGe5XEvvWIDqbqzJ-F_UWeXUbRIx78z3Hl4g"

    /// Edge Function endpoint
    private var edgeFunctionURL: String {
        "\(supabaseURL)/functions/v1/chat-lumi"
    }

    // MARK: - Public Methods

    /// Send a message to the AI and get a response
    /// - Parameters:
    ///   - userText: The user's message
    ///   - phase: Current app phase for prompt selection
    ///   - goalName: Current goal/vision name (used in Phase 2 & 3)
    ///   - todayTask: Today's task label (used in Phase 2)
    ///   - streakDays: Number of consecutive completion days (used in Phase 2 & 3)
    ///   - context: Additional freeform context
    ///   - modelContext: SwiftData model context for persisting messages
    /// - Returns: ChatResponse with text, optional extracted JSON, and optional created Goal
    func sendMessage(
        userText: String,
        phase: AppPhase,
        goalName: String? = nil,
        todayTask: String? = nil,
        streakDays: Int = 0,
        context: String = "",
        modelContext: ModelContext
    ) async throws -> ChatResponse {
        // Get system prompt for current phase with dynamic context
        let systemPrompt = promptManager.getSystemPrompt(
            phase: phase,
            goalName: goalName,
            todayTask: todayTask,
            streakDays: streakDays,
            context: context
        )

        // Save user message to SwiftData
        let userMessage = ChatMessage(content: userText, isUser: true)
        modelContext.insert(userMessage)

        // Fetch conversation history from SwiftData
        let conversationHistory = fetchChatHistory(from: modelContext)

        // Build messages array
        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        messages.append(contentsOf: conversationHistory)
        messages.append(["role": "user", "content": userText])

        // Make API request
        let responseText = try await makeAPIRequest(messages: messages)

        // Save AI response to SwiftData
        let aiMessage = ChatMessage(content: responseText, isUser: false)
        modelContext.insert(aiMessage)

        // Try to save context
        try? modelContext.save()

        // Extract JSON if present (for onboarding and companion phases)
        let extractedJSON = extractJSON(from: responseText)

        // Try to parse and create Goal if JSON contains a goal blueprint
        var createdGoal: Goal? = nil
        if let blueprint = JSONParser.extractGoalBlueprint(from: responseText) {
            createdGoal = JSONParser.createGoal(from: blueprint, in: modelContext)

            // Link the AI message to the created goal
            aiMessage.linkedGoalID = createdGoal?.id

            // Save again with goal link
            try? modelContext.save()

            print("ChatService: Created new Goal '\(blueprint.goalTitle)' from AI response")
        }

        return ChatResponse(
            text: responseText,
            extractedJSON: extractedJSON,
            createdGoal: createdGoal
        )
    }

    /// Send a silent event (Mode B) - does not affect visible chat history
    /// - Parameters:
    ///   - trigger: Event trigger type (bubble_popped, streak_achieved, etc.)
    ///   - goalName: Current goal/vision name
    ///   - todayTask: Today's task label
    ///   - streakDays: Number of consecutive completion days
    ///   - context: Additional freeform context about the event
    /// - Returns: Short encouragement string
    func sendSilentEvent(
        trigger: String,
        goalName: String? = nil,
        todayTask: String? = nil,
        streakDays: Int = 0,
        context: String = ""
    ) async throws -> String {
        // Get silent event prompt with dynamic context
        let systemPrompt = promptManager.getSilentEventPrompt(
            trigger: trigger,
            goalName: goalName,
            todayTask: todayTask,
            streakDays: streakDays,
            context: context
        )

        // Build messages (no history for silent events)
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": "请根据事件生成一条简短的鼓励语。"]
        ]

        // Make API request
        let responseText = try await makeAPIRequest(messages: messages)

        // Return clean text (remove any quotes or extra whitespace)
        return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
    }

    /// Clear conversation history from SwiftData
    func clearHistory(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<ChatMessage>()
        if let messages = try? modelContext.fetch(descriptor) {
            for message in messages {
                modelContext.delete(message)
            }
            try? modelContext.save()
        }
    }

    // MARK: - Private Helper Methods

    /// Fetch recent chat history from SwiftData
    /// - Parameter modelContext: SwiftData model context
    /// - Returns: Array of message dictionaries in API format
    private func fetchChatHistory(from modelContext: ModelContext) -> [[String: String]] {
        // Create fetch descriptor for recent messages
        var descriptor = FetchDescriptor<ChatMessage>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = maxHistoryCount

        // Fetch messages
        guard let messages = try? modelContext.fetch(descriptor) else {
            return []
        }

        // Convert to API format and reverse to chronological order
        return messages.reversed().map { $0.apiFormat }
    }

    // MARK: - Private Methods

    /// Make the actual API request with streaming support
    private func makeAPIRequest(messages: [[String: String]]) async throws -> String {
        guard let url = URL(string: edgeFunctionURL) else {
            throw ChatServiceError.invalidURL
        }

        // Build request body
        let requestBody: [String: Any] = [
            "model": "qwen-plus",
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 1024,
            "stream": true
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        // Create request with Supabase authentication
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        print("ChatService: 📤 Sending request to Edge Function")
        print("ChatService: URL: \(edgeFunctionURL)")
        print("ChatService: Messages count: \(messages.count)")

        // Make streaming request
        let (bytes, response) = try await session.bytes(for: request)

        print("ChatService: ✅ Connection established, receiving stream...")

        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            print("ChatService: ❌ Invalid HTTP response")
            throw ChatServiceError.invalidResponse
        }

        print("ChatService: HTTP Status: \(httpResponse.statusCode)")

        // Handle errors
        if httpResponse.statusCode != 200 {
            print("ChatService: ❌ HTTP Error \(httpResponse.statusCode)")
            // Try to read error message from stream
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }

            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: errorData) {
                throw ChatServiceError.httpError(
                    statusCode: httpResponse.statusCode,
                    message: errorResponse.error.message
                )
            }

            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ChatServiceError.httpError(
                statusCode: httpResponse.statusCode,
                message: errorMessage
            )
        }

        // Process SSE stream
        var fullContent = ""
        var buffer = ""

        for try await byte in bytes {
            guard let char = String(data: Data([byte]), encoding: .utf8) else {
                continue
            }

            buffer.append(char)

            // Process complete lines
            if char == "\n" {
                let line = buffer.trimmingCharacters(in: .whitespaces)
                buffer = ""

                // Skip empty lines and comments
                if line.isEmpty || line.hasPrefix(":") {
                    continue
                }

                // Parse SSE data line
                if line.hasPrefix("data: ") {
                    let dataContent = String(line.dropFirst(6))

                    // Check for stream end
                    if dataContent == "[DONE]" {
                        print("ChatService: Stream completed with [DONE]")
                        break
                    }

                    // Parse JSON chunk
                    if let chunkData = dataContent.data(using: .utf8) {
                        do {
                            let chunk = try JSONDecoder().decode(StreamChunk.self, from: chunkData)
                            if let delta = chunk.choices.first?.delta.content, !delta.isEmpty {
                                fullContent.append(delta)
                                print("ChatService: Stream chunk received: \(delta)")
                            }
                        } catch {
                            print("ChatService: Failed to decode chunk: \(error.localizedDescription)")
                            print("ChatService: Raw chunk data: \(dataContent)")
                        }
                    }
                }
            }
        }

        print("ChatService: Stream finished. Total content length: \(fullContent.count)")

        if fullContent.isEmpty {
            print("ChatService: ERROR - Stream completed but no content received")
            throw ChatServiceError.invalidResponse
        }

        return fullContent
    }

    /// SSE Stream chunk model
    private struct StreamChunk: Codable {
        let choices: [StreamChoice]

        struct StreamChoice: Codable {
            let delta: Delta
            let finishReason: String?
            let index: Int?

            enum CodingKeys: String, CodingKey {
                case delta
                case finishReason = "finish_reason"
                case index
            }

            struct Delta: Codable {
                let content: String?
                let role: String?
            }
        }
    }

    /// Extract JSON from markdown code blocks in the response
    /// - Parameter text: The response text that may contain JSON
    /// - Returns: Parsed JSON dictionary if found, nil otherwise
    private func extractJSON(from text: String) -> [String: Any]? {
        // Pattern 1: ```json ... ``` (most reliable)
        if let jsonString = extractCodeBlock(from: text, language: "json") {
            if let result = parseJSON(jsonString, silent: false) {
                return result
            }
        }

        // Pattern 2: ``` ... ``` with JSON-like content
        if let jsonString = extractCodeBlock(from: text, language: nil) {
            // Only try parsing if it looks like JSON (starts with {)
            let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("{") {
                if let result = parseJSON(jsonString, silent: true) {
                    return result
                }
            }
        }

        // Pattern 3: Detect standalone JSON object on its own line
        // More strict pattern: must start with { on a line and end with } on a line
        let strictJSONPattern = "(?:^|\\n)\\s*(\\{[^{}]*(?:\\{[^{}]*\\}[^{}]*)*\\})\\s*(?:\\n|$)"
        if let regex = try? NSRegularExpression(pattern: strictJSONPattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
           match.numberOfRanges > 1 {
            let range = match.range(at: 1)
            if let swiftRange = Range(range, in: text) {
                let jsonString = String(text[swiftRange])
                if let result = parseJSON(jsonString, silent: true) {
                    return result
                }
            }
        }

        return nil
    }

    /// Extract content from a markdown code block
    private func extractCodeBlock(from text: String, language: String?) -> String? {
        let pattern: String
        if let lang = language {
            // Match ```json or ```JSON etc.
            pattern = "```\(lang)\\s*\\n([\\s\\S]*?)\\n\\s*```"
        } else {
            // Match ``` without language specifier
            pattern = "```\\s*\\n([\\s\\S]*?)\\n\\s*```"
        }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let nsString = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        if let match = results.first, match.numberOfRanges > 1 {
            let range = match.range(at: 1)
            return nsString.substring(with: range)
        }

        return nil
    }

    /// Parse JSON string into dictionary
    /// - Parameters:
    ///   - jsonString: The JSON string to parse
    ///   - silent: If true, don't log parsing errors (for speculative parsing)
    private func parseJSON(_ jsonString: String, silent: Bool = false) -> [String: Any]? {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Quick validation: must start with { and end with }
        guard trimmed.hasPrefix("{") && trimmed.hasSuffix("}") else {
            return nil
        }

        guard let data = trimmed.data(using: .utf8) else {
            return nil
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                return json
            }
        } catch {
            if !silent {
                print("ChatService: JSON parsing error - \(error.localizedDescription)")
            }
        }

        return nil
    }
}

// MARK: - Convenience Extensions

extension ChatResponse {
    /// Get the display text (removes JSON code blocks for cleaner display)
    var displayText: String {
        // Use JSONParser's robust stripping method
        return JSONParser.stripJSON(from: text)
    }

    /// Try to get bubbles array from extracted JSON
    var bubbles: [[String: Any]]? {
        return extractedJSON?["bubbles"] as? [[String: Any]]
    }

    /// Try to get crystal data from extracted JSON
    var crystal: [String: Any]? {
        return extractedJSON?["crystal"] as? [String: Any]
    }

    /// Try to get action type from extracted JSON
    var action: String? {
        return extractedJSON?["action"] as? String
    }

    /// Try to get encouragement from extracted JSON
    var encouragement: String? {
        return extractedJSON?["encouragement"] as? String
    }
}
