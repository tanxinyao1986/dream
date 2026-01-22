//
//  DataModels.swift
//  dream
//
//  SwiftData models for persisting Goals, Phases, Tasks, and Chat History
//

import Foundation
import SwiftData

// MARK: - Goal Model

/// Represents a user's vision/goal with multiple phases
@Model
final class Goal {
    /// Unique identifier
    var id: UUID

    /// Goal title/name (e.g., "成为健康的人")
    var title: String

    /// Total duration in days across all phases
    var totalDays: Int

    /// Current phase index (0-based)
    var currentPhaseIndex: Int

    /// Whether the goal is completed
    var isCompleted: Bool

    /// Creation timestamp
    var createdAt: Date

    /// Phases belonging to this goal
    @Relationship(deleteRule: .cascade, inverse: \Phase.goal)
    var phases: [Phase]

    /// Daily tasks linked to this goal
    @Relationship(deleteRule: .cascade, inverse: \DailyTask.goal)
    var dailyTasks: [DailyTask]

    init(
        id: UUID = UUID(),
        title: String,
        totalDays: Int,
        currentPhaseIndex: Int = 0,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        phases: [Phase] = [],
        dailyTasks: [DailyTask] = []
    ) {
        self.id = id
        self.title = title
        self.totalDays = totalDays
        self.currentPhaseIndex = currentPhaseIndex
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.phases = phases
        self.dailyTasks = dailyTasks
    }
}

// MARK: - Phase Model

/// Represents a phase within a goal (e.g., "习惯养成期")
@Model
final class Phase {
    /// Unique identifier
    var id: UUID

    /// Phase name (e.g., "习惯养成期")
    var name: String

    /// Duration of this phase in days
    var durationDays: Int

    /// Daily task label (e.g., "今日修行")
    var dailyTaskLabel: String

    /// Daily task detail/description
    var dailyTaskDetail: String

    /// Bubble color hex (e.g., "FFD700")
    var bubbleColorHex: String

    /// Order index within the goal
    var orderIndex: Int

    /// Parent goal
    var goal: Goal?

    init(
        id: UUID = UUID(),
        name: String,
        durationDays: Int,
        dailyTaskLabel: String,
        dailyTaskDetail: String,
        bubbleColorHex: String,
        orderIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.durationDays = durationDays
        self.dailyTaskLabel = dailyTaskLabel
        self.dailyTaskDetail = dailyTaskDetail
        self.bubbleColorHex = bubbleColorHex
        self.orderIndex = orderIndex
    }
}

// MARK: - DailyTask Model

/// Represents a daily task instance for a specific date
@Model
final class DailyTask {
    /// Unique identifier
    var id: UUID

    /// Date for this task (normalized to start of day)
    var date: Date

    /// Whether the task is completed
    var isCompleted: Bool

    /// Task label (e.g., "今日修行")
    var label: String

    /// Task detail/description
    var detail: String

    /// Bubble color hex
    var bubbleColorHex: String

    /// Phase this task belongs to
    var phaseIndex: Int

    /// Parent goal
    var goal: Goal?

    init(
        id: UUID = UUID(),
        date: Date,
        isCompleted: Bool = false,
        label: String,
        detail: String,
        bubbleColorHex: String,
        phaseIndex: Int = 0
    ) {
        self.id = id
        self.date = date
        self.isCompleted = isCompleted
        self.label = label
        self.detail = detail
        self.bubbleColorHex = bubbleColorHex
        self.phaseIndex = phaseIndex
    }
}

// MARK: - ChatMessage Model

/// Represents a chat message in conversation history
@Model
final class ChatMessage {
    /// Unique identifier
    var id: UUID

    /// Message content/text
    var content: String

    /// Whether this is a user message (false = AI message)
    var isUser: Bool

    /// Timestamp when message was created
    var timestamp: Date

    /// Optional: Link to goal if message resulted in goal creation
    var linkedGoalID: UUID?

    init(
        id: UUID = UUID(),
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        linkedGoalID: UUID? = nil
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.linkedGoalID = linkedGoalID
    }
}

// MARK: - Helper Extensions

extension Goal {
    /// Get the current active phase
    var currentPhase: Phase? {
        guard currentPhaseIndex < phases.count else { return nil }
        return phases.sorted(by: { $0.orderIndex < $1.orderIndex })[currentPhaseIndex]
    }

    /// Get today's task
    func getTaskForDate(_ date: Date) -> DailyTask? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return dailyTasks.first { calendar.isDate($0.date, inSameDayAs: startOfDay) }
    }

    /// Calculate current day number (1-based)
    var currentDayNumber: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
        return min(days + 1, totalDays)
    }

    /// Calculate streak days (consecutive completed tasks)
    func calculateStreak() -> Int {
        let calendar = Calendar.current
        let today = Date()
        var streak = 0

        // Check backwards from yesterday (don't count today as it's in progress)
        for dayOffset in 1...totalDays {
            guard let checkDate = calendar.date(byAdding: .day, value: -dayOffset, to: today),
                  let task = getTaskForDate(checkDate) else {
                break
            }

            if task.isCompleted {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }

    /// Check if all tasks are completed
    var isFullyCompleted: Bool {
        let completedCount = dailyTasks.filter { $0.isCompleted }.count
        return completedCount == dailyTasks.count && dailyTasks.count > 0
    }

    /// Get remaining incomplete tasks
    var incompleteTasks: [DailyTask] {
        return dailyTasks.filter { !$0.isCompleted }
    }

    /// Check if this is the last incomplete task
    func isLastIncompleteTask(_ task: DailyTask) -> Bool {
        let incomplete = incompleteTasks
        return incomplete.count == 1 && incomplete.first?.id == task.id
    }
}

extension ChatMessage {
    /// Convert to API message format
    var apiFormat: [String: String] {
        return [
            "role": isUser ? "user" : "assistant",
            "content": content
        ]
    }
}
