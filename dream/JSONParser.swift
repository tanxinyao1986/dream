//
//  JSONParser.swift
//  dream
//
//  JSON Parser for AI response - extracts goal blueprints, detects actions, and strips JSON for display
//

import Foundation
import SwiftData

// MARK: - Goal Blueprint (Codable struct matching AI JSON output)

/// Codable structure matching the AI's JSON response format
/// Handles multiple key variations from AI output (goal_title/vision_title, etc.)
struct GoalBlueprint: Codable {
    /// Goal title (accepts both "goal_title" and "vision_title")
    let goalTitle: String

    /// Total duration in days (optional, can be calculated from phases)
    let totalDuration: Int?

    /// Array of phases
    let phases: [PhaseBlueprint]

    // Custom coding keys to handle multiple variations
    enum CodingKeys: String, CodingKey {
        case goalTitle = "goal_title"
        case visionTitle = "vision_title"
        case title = "title"  // Fuzzy fallback
        case totalDuration = "total_duration"
        case totalDurationDays = "total_duration_days"
        case phases
    }

    // Custom decoder to handle multiple title variations (FUZZY MATCH)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Fuzzy match: try goal_title → vision_title → title
        if let title = try? container.decode(String.self, forKey: .goalTitle) {
            self.goalTitle = title
            print("JSONParser: ✅ Decoded title via 'goal_title': \(title)")
        } else if let title = try? container.decode(String.self, forKey: .visionTitle) {
            self.goalTitle = title
            print("JSONParser: ⚠️ Decoded title via 'vision_title' (fallback): \(title)")
        } else if let title = try? container.decode(String.self, forKey: .title) {
            self.goalTitle = title
            print("JSONParser: ⚠️ Decoded title via 'title' (fuzzy fallback): \(title)")
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.goalTitle,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "No title field found (tried: goal_title, vision_title, title)"
                )
            )
        }

        // Try total_duration first, then total_duration_days
        if let duration = try? container.decode(Int.self, forKey: .totalDuration) {
            self.totalDuration = duration
        } else if let duration = try? container.decode(Int.self, forKey: .totalDurationDays) {
            self.totalDuration = duration
        } else {
            self.totalDuration = nil // Will be calculated from phases
        }

        // Decode phases (required)
        self.phases = try container.decode([PhaseBlueprint].self, forKey: .phases)
    }

    // Custom encoder for consistency
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(goalTitle, forKey: .goalTitle)
        try container.encodeIfPresent(totalDuration, forKey: .totalDuration)
        try container.encode(phases, forKey: .phases)
    }

    /// Calculate total days from phases
    var calculatedTotalDays: Int {
        totalDuration ?? phases.reduce(0) { $0 + $1.durationDays }
    }

    struct PhaseBlueprint: Codable {
        /// Phase name (e.g., "习惯养成期")
        let phaseName: String

        /// Duration in days
        let durationDays: Int

        /// Daily task label (e.g., "今日修行")
        let dailyTaskLabel: String

        /// Daily task detail/description
        let dailyTaskDetail: String

        /// Bubble color hex code (e.g., "FFD700")
        let bubbleColor: String

        // Custom coding keys to handle variations
        enum CodingKeys: String, CodingKey {
            case phaseName = "phase_name"
            case durationDays = "duration_days"
            case durationDaysAlt = "days"
            case dailyTaskLabel = "daily_task_label"
            case dailyTaskLabelAlt = "task_label"
            case dailyTaskDetail = "daily_task_detail"
            case dailyTaskDetailAlt = "task_detail"
            case bubbleColor = "bubble_color"
            case bubbleColorAlt = "color"
        }

        // Custom decoder to handle multiple key variations
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Phase name (required)
            self.phaseName = try container.decode(String.self, forKey: .phaseName)

            // Duration: try duration_days first, then days
            if let days = try? container.decode(Int.self, forKey: .durationDays) {
                self.durationDays = days
            } else if let days = try? container.decode(Int.self, forKey: .durationDaysAlt) {
                self.durationDays = days
            } else {
                throw DecodingError.keyNotFound(
                    CodingKeys.durationDays,
                    DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Neither 'duration_days' nor 'days' found"
                    )
                )
            }

            // Daily task label: try daily_task_label first, then task_label
            if let label = try? container.decode(String.self, forKey: .dailyTaskLabel) {
                self.dailyTaskLabel = label
            } else if let label = try? container.decode(String.self, forKey: .dailyTaskLabelAlt) {
                self.dailyTaskLabel = label
            } else {
                self.dailyTaskLabel = "今日任务" // Default fallback
            }

            // Daily task detail: try daily_task_detail first, then task_detail
            if let detail = try? container.decode(String.self, forKey: .dailyTaskDetail) {
                self.dailyTaskDetail = detail
            } else if let detail = try? container.decode(String.self, forKey: .dailyTaskDetailAlt) {
                self.dailyTaskDetail = detail
            } else {
                self.dailyTaskDetail = "" // Default fallback
            }

            // Bubble color: try bubble_color first, then color
            if let color = try? container.decode(String.self, forKey: .bubbleColor) {
                self.bubbleColor = color
            } else if let color = try? container.decode(String.self, forKey: .bubbleColorAlt) {
                self.bubbleColor = color
            } else {
                self.bubbleColor = "FFD700" // Default gold color
            }
        }

        // Custom encoder for consistency
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(phaseName, forKey: .phaseName)
            try container.encode(durationDays, forKey: .durationDays)
            try container.encode(dailyTaskLabel, forKey: .dailyTaskLabel)
            try container.encode(dailyTaskDetail, forKey: .dailyTaskDetail)
            try container.encode(bubbleColor, forKey: .bubbleColor)
        }
    }
}

// MARK: - Action Response (for trigger detection)

/// Represents an action command from AI
struct AIActionResponse: Codable {
    let action: String
    let newTaskLabel: String?

    enum CodingKeys: String, CodingKey {
        case action
        case newTaskLabel = "new_task_label"
    }
}

// MARK: - Parse Result (for feedback)

enum JSONParseResult {
    case success(GoalBlueprint)
    case failure(String)
}

// MARK: - JSON Parser

/// Parser for extracting and processing AI JSON responses
final class JSONParser {

    // MARK: - Static Methods

    /// Check if text contains any JSON code block (for interception)
    /// - Parameter text: The AI response text
    /// - Returns: True if JSON is detected
    static func containsJSON(_ text: String) -> Bool {
        // Pattern 1: ```json ... ``` (case insensitive)
        let jsonBlockPattern = "```[\\s]*(?i:json)?[\\s]*\\n?[\\s\\S]*?```"
        if let regex = try? NSRegularExpression(pattern: jsonBlockPattern, options: []),
           regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) != nil {
            return true
        }

        // Pattern 2: Standalone JSON object with common keys
        let standalonePatterns = [
            "\\{[\\s\\S]*?\"action\"[\\s\\S]*?\\}",
            "\\{[\\s\\S]*?\"goal_title\"[\\s\\S]*?\\}",
            "\\{[\\s\\S]*?\"vision_title\"[\\s\\S]*?\\}"
        ]

        for pattern in standalonePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) != nil {
                return true
            }
        }

        return false
    }

    /// Extract action command from AI response
    /// - Parameter text: The AI response text
    /// - Returns: Action string if found (e.g., "trigger_phase_3_completion", "update_today_task", "reset_goal")
    static func extractAction(from text: String) -> AIActionResponse? {
        guard let jsonString = extractJSONString(from: text) else {
            return nil
        }

        // Clean the JSON string before parsing
        let cleanedJSON = cleanJSONString(jsonString)

        guard let data = cleanedJSON.data(using: .utf8) else {
            print("JSONParser: ❌ Failed to convert cleaned JSON to data")
            return nil
        }

        // Try to decode as AIActionResponse
        let decoder = JSONDecoder()
        if let actionResponse = try? decoder.decode(AIActionResponse.self, from: data) {
            print("JSONParser: ✅ Extracted action: \(actionResponse.action)")
            return actionResponse
        }

        // Fallback: Try to extract action from generic JSON
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let action = json["action"] as? String {
            let newLabel = json["new_task_label"] as? String
            print("JSONParser: ✅ Extracted action (fallback): \(action)")
            return AIActionResponse(action: action, newTaskLabel: newLabel)
        }

        return nil
    }

    /// Clean JSON string by removing markdown markers, trailing commas, and fixing common issues
    /// - Parameter jsonString: Raw JSON string that may have markdown or formatting issues
    /// - Returns: Cleaned JSON string ready for parsing
    static func cleanJSONString(_ jsonString: String) -> String {
        var cleaned = jsonString

        // Step 1: Remove markdown code block markers
        // Handles: ```json, ```JSON, ``` json, ```
        cleaned = cleaned.replacingOccurrences(of: "```json", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "```JSON", with: "")
        cleaned = cleaned.replacingOccurrences(of: "``` json", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")

        // Step 2: Remove trailing commas before } or ]
        // This is a common JSON syntax error from LLMs
        let trailingCommaPattern = ",\\s*([\\}\\]])"
        if let regex = try? NSRegularExpression(pattern: trailingCommaPattern, options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(location: 0, length: cleaned.utf16.count),
                withTemplate: "$1"
            )
        }

        // Step 3: Remove any BOM or zero-width characters
        cleaned = cleaned.replacingOccurrences(of: "\u{FEFF}", with: "")
        cleaned = cleaned.replacingOccurrences(of: "\u{200B}", with: "")

        // Step 4: Normalize newlines and trim whitespace
        cleaned = cleaned.replacingOccurrences(of: "\r\n", with: "\n")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Step 5: Ensure the string starts with { and ends with }
        if let startIndex = cleaned.firstIndex(of: "{"),
           let endIndex = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[startIndex...endIndex])
        }

        print("JSONParser: Cleaned JSON (length: \(cleaned.count))")
        return cleaned
    }

    /// Strip all JSON from text, leaving only conversational content
    /// - Parameter text: The AI response text containing JSON
    /// - Returns: Clean text suitable for display to user
    static func stripJSON(from text: String) -> String {
        var cleanText = text

        // Pattern 1: Remove ```json ... ``` blocks (case insensitive, flexible whitespace)
        // Handles: ```json\n{...}\n```, ```JSON{...}```, ``` json \n{...}```
        let jsonBlockPatterns = [
            "```[\\s]*(?i:json)[\\s]*\\n?[\\s\\S]*?\\n?[\\s]*```",
            "```[\\s]*\\n?\\s*\\{[\\s\\S]*?\\}\\s*\\n?[\\s]*```"
        ]

        for pattern in jsonBlockPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                cleanText = regex.stringByReplacingMatches(
                    in: cleanText,
                    options: [],
                    range: NSRange(location: 0, length: cleanText.utf16.count),
                    withTemplate: ""
                )
            }
        }

        // Pattern 2: Remove standalone JSON objects that look like commands
        // Must contain "action" key to be considered a command JSON
        let actionJSONPattern = "\\{[\\s]*\"action\"[\\s]*:[\\s\\S]*?\\}"
        if let regex = try? NSRegularExpression(pattern: actionJSONPattern, options: []) {
            cleanText = regex.stringByReplacingMatches(
                in: cleanText,
                options: [],
                range: NSRange(location: 0, length: cleanText.utf16.count),
                withTemplate: ""
            )
        }

        // Pattern 3: Remove standalone goal/vision JSON
        let goalJSONPatterns = [
            "\\{[\\s]*\"goal_title\"[\\s\\S]*?\"phases\"[\\s\\S]*?\\}",
            "\\{[\\s]*\"vision_title\"[\\s\\S]*?\"phases\"[\\s\\S]*?\\}"
        ]

        for pattern in goalJSONPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                cleanText = regex.stringByReplacingMatches(
                    in: cleanText,
                    options: [],
                    range: NSRange(location: 0, length: cleanText.utf16.count),
                    withTemplate: ""
                )
            }
        }

        // Clean up excessive whitespace and newlines
        cleanText = cleanText
            .replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleanText
    }

    /// Extract and parse JSON from AI response text (with detailed result)
    /// - Parameter text: The AI response text that may contain JSON
    /// - Returns: JSONParseResult indicating success with blueprint or failure with error message
    static func extractGoalBlueprintWithResult(from text: String) -> JSONParseResult {
        // Try to extract JSON from markdown code blocks
        guard let jsonString = extractJSONString(from: text) else {
            let errorMsg = "未找到JSON数据块"
            print("JSONParser: ❌ \(errorMsg)")
            return .failure(errorMsg)
        }

        // Clean the JSON string
        let cleanedJSON = cleanJSONString(jsonString)
        print("JSONParser: Raw JSON extracted, cleaning...")

        // Try to parse
        guard let data = cleanedJSON.data(using: .utf8) else {
            let errorMsg = "JSON编码失败"
            print("JSONParser: ❌ \(errorMsg)")
            return .failure(errorMsg)
        }

        let decoder = JSONDecoder()
        do {
            let blueprint = try decoder.decode(GoalBlueprint.self, from: data)
            print("JSONParser: ✅ Successfully parsed GoalBlueprint - \(blueprint.goalTitle)")
            return .success(blueprint)
        } catch let decodingError as DecodingError {
            let errorMsg = describeDecodingError(decodingError)
            print("JSONParser: ❌ Decoding error: \(errorMsg)")
            print("JSONParser: Raw JSON was: \(cleanedJSON.prefix(500))...")
            return .failure(errorMsg)
        } catch {
            let errorMsg = "解析失败: \(error.localizedDescription)"
            print("JSONParser: ❌ \(errorMsg)")
            return .failure(errorMsg)
        }
    }

    /// Extract and parse JSON from AI response text
    /// - Parameter text: The AI response text that may contain JSON
    /// - Returns: Parsed GoalBlueprint if found and valid, nil otherwise
    static func extractGoalBlueprint(from text: String) -> GoalBlueprint? {
        let result = extractGoalBlueprintWithResult(from: text)
        switch result {
        case .success(let blueprint):
            return blueprint
        case .failure:
            return nil
        }
    }

    /// Create Goal and related objects in SwiftData from a blueprint
    /// - Parameters:
    ///   - blueprint: The parsed goal blueprint
    ///   - modelContext: SwiftData model context
    /// - Returns: The created Goal object, or nil if failed
    @discardableResult
    static func createGoal(from blueprint: GoalBlueprint, in modelContext: ModelContext) -> Goal? {
        print("JSONParser: 🎯 Creating Goal from blueprint: '\(blueprint.goalTitle)'")

        // Use calculated total days (handles both explicit total_duration and sum from phases)
        let totalDays = blueprint.calculatedTotalDays
        print("JSONParser: Total days: \(totalDays)")

        // Create Goal
        let goal = Goal(
            title: blueprint.goalTitle,
            totalDays: totalDays
        )
        print("JSONParser: Goal object created")

        // Create Phases
        print("JSONParser: Creating \(blueprint.phases.count) phases")
        for (index, phaseBlueprint) in blueprint.phases.enumerated() {
            let phase = Phase(
                name: phaseBlueprint.phaseName,
                durationDays: phaseBlueprint.durationDays,
                dailyTaskLabel: phaseBlueprint.dailyTaskLabel,
                dailyTaskDetail: phaseBlueprint.dailyTaskDetail,
                bubbleColorHex: phaseBlueprint.bubbleColor,
                orderIndex: index
            )
            phase.goal = goal
            goal.phases.append(phase)
            print("JSONParser:   Phase \(index + 1): \(phase.name) (\(phase.durationDays) days)")
        }

        // Generate DailyTask objects for all days
        print("JSONParser: Generating DailyTasks for \(totalDays) days")
        let calendar = Calendar.current
        let startDate = Date()
        var currentDate = calendar.startOfDay(for: startDate)
        var dayCounter = 0

        for (phaseIndex, phaseBlueprint) in blueprint.phases.enumerated() {
            print("JSONParser:   Generating tasks for phase \(phaseIndex + 1)...")
            for _ in 0..<phaseBlueprint.durationDays {
                guard dayCounter < totalDays else { break }

                let dailyTask = DailyTask(
                    date: currentDate,
                    label: phaseBlueprint.dailyTaskLabel,
                    detail: phaseBlueprint.dailyTaskDetail,
                    bubbleColorHex: phaseBlueprint.bubbleColor,
                    phaseIndex: phaseIndex
                )
                dailyTask.goal = goal
                goal.dailyTasks.append(dailyTask)

                // Move to next day
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                    currentDate = nextDay
                }
                dayCounter += 1
            }
            print("JSONParser:   Created \(phaseBlueprint.durationDays) tasks for phase \(phaseIndex + 1)")
        }

        // Insert into model context
        modelContext.insert(goal)
        print("JSONParser: ✅ Goal inserted into SwiftData ModelContext")

        // Save the context
        do {
            try modelContext.save()
            print("JSONParser: ✅ ModelContext saved successfully")

            // Post notification for UI refresh
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .goalDataDidChange, object: goal)
            }

            print("JSONParser: ✅ Created Goal '\(goal.title)' with \(goal.phases.count) phases and \(goal.dailyTasks.count) daily tasks")
            return goal
        } catch {
            print("JSONParser: ❌ Failed to save ModelContext: \(error)")
            return nil
        }
    }

    // MARK: - Private Helper Methods

    /// Describe a DecodingError in user-friendly Chinese
    private static func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "缺少字段: \(key.stringValue)"
        case .typeMismatch(let type, let context):
            return "类型错误: 期望\(type), 位置: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .valueNotFound(let type, let context):
            return "值缺失: \(type), 位置: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .dataCorrupted(let context):
            return "数据损坏: \(context.debugDescription)"
        @unknown default:
            return "未知解码错误"
        }
    }

    /// Extract JSON string from markdown code blocks
    private static func extractJSONString(from text: String) -> String? {
        print("JSONParser: Searching for JSON in text (length: \(text.count))")

        // Pattern 1: ```json ... ``` (case insensitive, flexible whitespace)
        // Handles variations: ```json, ```JSON, ``` json, etc.
        if let jsonString = extractCodeBlock(from: text, language: "json") {
            print("JSONParser: ✅ JSON FOUND via ```json code block (length: \(jsonString.count))")
            print("🔴 RAW JSON FROM AI:\n\(jsonString)\n")
            return jsonString
        }

        // Pattern 2: ``` ... ``` with JSON-like content
        if let jsonString = extractCodeBlock(from: text, language: nil) {
            let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
                print("JSONParser: ✅ JSON FOUND via ``` code block (length: \(trimmed.count))")
                print("🔴 RAW JSON FROM AI:\n\(trimmed)\n")
                return trimmed
            }
        }

        // Pattern 3: Standalone JSON - try FUZZY MATCH with multiple title variations
        // Try: goal_title, vision_title, title (in that order)
        let titleKeys = ["goal_title", "vision_title", "title"]
        for titleKey in titleKeys {
            if let jsonString = extractStandaloneJSON(from: text, containingKey: titleKey) {
                print("JSONParser: ✅ JSON FOUND via standalone pattern with key '\(titleKey)' (length: \(jsonString.count))")
                print("🔴 RAW JSON FROM AI:\n\(jsonString)\n")
                return jsonString
            }
        }

        // Pattern 4: Standalone JSON with "action" key
        if let jsonString = extractStandaloneJSON(from: text, containingKey: "action") {
            print("JSONParser: ✅ JSON FOUND via standalone action pattern (length: \(jsonString.count))")
            print("🔴 RAW JSON FROM AI:\n\(jsonString)\n")
            return jsonString
        }

        print("JSONParser: ❌ No JSON found in text")
        return nil
    }

    /// Extract standalone JSON object containing a specific key
    private static func extractStandaloneJSON(from text: String, containingKey key: String) -> String? {
        // Find the position of the key
        guard let keyRange = text.range(of: "\"\(key)\"") else {
            return nil
        }

        // Find the opening brace before the key
        var braceCount = 0
        var startIndex: String.Index?
        var currentIndex = keyRange.lowerBound

        while currentIndex > text.startIndex {
            currentIndex = text.index(before: currentIndex)
            let char = text[currentIndex]

            if char == "}" {
                braceCount += 1
            } else if char == "{" {
                if braceCount == 0 {
                    startIndex = currentIndex
                    break
                }
                braceCount -= 1
            }
        }

        guard let start = startIndex else {
            return nil
        }

        // Find the matching closing brace
        braceCount = 0
        currentIndex = start

        while currentIndex < text.endIndex {
            let char = text[currentIndex]

            if char == "{" {
                braceCount += 1
            } else if char == "}" {
                braceCount -= 1
                if braceCount == 0 {
                    let endIndex = text.index(after: currentIndex)
                    return String(text[start..<endIndex])
                }
            }

            currentIndex = text.index(after: currentIndex)
        }

        return nil
    }

    /// Extract content from markdown code block
    private static func extractCodeBlock(from text: String, language: String?) -> String? {
        let pattern: String
        if let lang = language {
            // More flexible pattern: handles various whitespace scenarios
            // ```json\n{...}\n``` or ```json{...}``` or ```JSON\n{...}\n``` or ``` json \n{...}```
            pattern = "```[\\s]*(?i:\(lang))[\\s]*\\n?([\\s\\S]*?)\\n?[\\s]*```"
        } else {
            // Generic code block: ```\n{...}\n``` or ```{...}```
            pattern = "```[\\s]*\\n?([\\s\\S]*?)\\n?[\\s]*```"
        }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            print("JSONParser: Failed to create regex for pattern: \(pattern)")
            return nil
        }

        let nsString = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        if let match = results.first, match.numberOfRanges > 1 {
            let range = match.range(at: 1)
            let extracted = nsString.substring(with: range)
            // Trim whitespace from extracted content
            return extracted.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }
}
