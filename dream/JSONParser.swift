//
//  JSONParser.swift
//  dream
//
//  JSON Parser for AI response - extracts goal blueprints and creates SwiftData objects
//

import Foundation
import SwiftData

// MARK: - Goal Blueprint (Codable struct matching AI JSON output)

/// Codable structure matching the AI's JSON response format
struct GoalBlueprint: Codable {
    /// Goal title
    let goalTitle: String

    /// Array of phases
    let phases: [PhaseBlueprint]

    enum CodingKeys: String, CodingKey {
        case goalTitle = "goal_title"
        case phases
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

        enum CodingKeys: String, CodingKey {
            case phaseName = "phase_name"
            case durationDays = "duration_days"
            case dailyTaskLabel = "daily_task_label"
            case dailyTaskDetail = "daily_task_detail"
            case bubbleColor = "bubble_color"
        }
    }
}

// MARK: - JSON Parser

/// Parser for extracting and processing AI JSON responses
final class JSONParser {

    // MARK: - Static Methods

    /// Extract and parse JSON from AI response text
    /// - Parameter text: The AI response text that may contain JSON
    /// - Returns: Parsed GoalBlueprint if found and valid, nil otherwise
    static func extractGoalBlueprint(from text: String) -> GoalBlueprint? {
        // Try to extract JSON from markdown code blocks
        guard let jsonString = extractJSONString(from: text) else {
            print("JSONParser: No JSON code block found in response")
            return nil
        }

        // Parse the JSON string
        guard let blueprint = parseGoalBlueprint(from: jsonString) else {
            print("JSONParser: Failed to parse JSON into GoalBlueprint")
            return nil
        }

        print("JSONParser: Successfully extracted GoalBlueprint - \(blueprint.goalTitle)")
        return blueprint
    }

    /// Create Goal and related objects in SwiftData from a blueprint
    /// - Parameters:
    ///   - blueprint: The parsed goal blueprint
    ///   - modelContext: SwiftData model context
    /// - Returns: The created Goal object
    @discardableResult
    static func createGoal(from blueprint: GoalBlueprint, in modelContext: ModelContext) -> Goal {
        print("JSONParser: 🎯 Creating Goal from blueprint: '\(blueprint.goalTitle)'")

        // Calculate total days
        let totalDays = blueprint.phases.reduce(0) { $0 + $1.durationDays }
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
            for dayInPhase in 0..<phaseBlueprint.durationDays {
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
        } catch {
            print("JSONParser: ❌ Failed to save ModelContext: \(error)")
        }

        print("JSONParser: ✅ Created Goal '\(goal.title)' with \(goal.phases.count) phases and \(goal.dailyTasks.count) daily tasks")

        return goal
    }

    // MARK: - Private Helper Methods

    /// Extract JSON string from markdown code blocks
    private static func extractJSONString(from text: String) -> String? {
        print("JSONParser: Searching for JSON in text (length: \(text.count))")

        // Pattern 1: ```json ... ``` (case insensitive, flexible whitespace)
        if let jsonString = extractCodeBlock(from: text, language: "json") {
            print("JSONParser: ✅ JSON FOUND via ```json code block (length: \(jsonString.count))")
            return jsonString
        }

        // Pattern 2: ``` ... ``` with JSON-like content
        if let jsonString = extractCodeBlock(from: text, language: nil) {
            let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
                print("JSONParser: ✅ JSON FOUND via ``` code block (length: \(trimmed.count))")
                return trimmed
            }
        }

        // Pattern 3: Standalone JSON object (no code blocks)
        let pattern = "\\{[\\s\\S]*?\"goal_title\"[\\s\\S]*?\"phases\"[\\s\\S]*?\\}"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
            let range = match.range
            if let swiftRange = Range(range, in: text) {
                let jsonString = String(text[swiftRange])
                print("JSONParser: ✅ JSON FOUND via standalone pattern (length: \(jsonString.count))")
                return jsonString
            }
        }

        print("JSONParser: ❌ No JSON found in text")
        return nil
    }

    /// Extract content from markdown code block
    private static func extractCodeBlock(from text: String, language: String?) -> String? {
        let pattern: String
        if let lang = language {
            // More flexible pattern: handles various whitespace scenarios
            // ```json\n{...}\n``` or ```json{...}``` or ```JSON\n{...}\n```
            pattern = "```(?i)\(lang)\\s*([\\s\\S]*?)```"
        } else {
            // Generic code block: ```\n{...}\n``` or ```{...}```
            pattern = "```\\s*([\\s\\S]*?)```"
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

    /// Parse JSON string into GoalBlueprint
    private static func parseGoalBlueprint(from jsonString: String) -> GoalBlueprint? {
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }

        let decoder = JSONDecoder()
        do {
            let blueprint = try decoder.decode(GoalBlueprint.self, from: data)
            return blueprint
        } catch {
            print("JSONParser: Decoding error - \(error)")
            return nil
        }
    }
}
