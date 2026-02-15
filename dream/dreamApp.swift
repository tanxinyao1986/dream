//
//  dreamApp.swift
//  LifeBubble 梦幻肥皂泡版本 🎨
//
//  ✨ 包含 11 项 UI/UX 升级：
//  1. 肥皂泡材质渲染系统（7层叠加）
//  2. 打字机效果文字
//  3. Splash 长按膨胀 + 破裂转场
//  4. SpriteKit 物理引擎（漂浮场 + 软碰撞）
//  5. 长按发射台创建泡泡
//  6. 推迟手势（Fling to Snooze）
//  7. 贝塞尔曲线流沙粒子
//  8. Calendar 过去/未来视觉分级
//  9. Calendar Zoom In 动画
//  10. 声音管理器
//  11. 触觉反馈系统
//

import SwiftUI
import Combine
import SpriteKit
import AVFoundation
import SwiftData

// MARK: - ========== Notification Names ==========
extension Notification.Name {
    /// Posted when goal data changes (created, updated, deleted, completed)
    static let goalDataDidChange = Notification.Name("goalDataDidChange")
}

// MARK: - ========== 应用入口 ==========
@main
struct dreamApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var supabaseManager = SupabaseManager.shared

    // Configure SwiftData ModelContainer
    let modelContainer: ModelContainer = {
        let schema = Schema([
            Goal.self,
            Phase.self,
            DailyTask.self,
            ChatMessage.self,
            ArchivedGoal.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if supabaseManager.isLoading {
                    // Show nothing or a brief loading state while restoring session
                    Color.clear
                } else if supabaseManager.isAuthenticated {
                    RootView()
                        .environmentObject(appState)
                        .preferredColorScheme(.light)
                        .modelContainer(modelContainer)
                } else {
                    LoginView()
                        .preferredColorScheme(.light)
                }
            }
            .environmentObject(supabaseManager)
            .task {
                await supabaseManager.restoreSession()
            }
        }
    }
}

// MARK: - ========== 根视图 ==========
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            if appState.showSplash {
                SplashView()
                    .zIndex(100)
                    .transition(.opacity.combined(with: .scale))
            }

            if !appState.showSplash {
                HomeView()
                    .zIndex(0)
            }

            if appState.showCalendar {
                CalendarView()
                    .transition(.move(edge: .top))
                    .zIndex(10)
            }

            // ChatView is now presented via .fullScreenCover on HomeView

            if appState.showArchive {
                ArchiveView()
                    .transition(.move(edge: .trailing))
                    .zIndex(30)
            }

            // Floating Banner (Silent Narrator) - Always on top
            FloatingBanner(
                message: appState.floatingBannerMessage,
                isVisible: appState.showFloatingBanner
            )
            .zIndex(200)
            .allowsHitTesting(false)

            // Task Detail Overlay
            if appState.showTaskDetail {
                TaskDetailOverlay(
                    goalTitle: appState.taskDetailGoalTitle,
                    phaseName: appState.taskDetailPhaseName,
                    taskDetail: appState.taskDetailDescription,
                    bubbleColor: appState.taskDetailColor,
                    onDismiss: {
                        appState.hideTaskDetailOverlay()
                    }
                )
                .zIndex(150)
            }

            // Letter Envelope Overlay (Goal Completion Ritual)
            if appState.showLetterEnvelope {
                LetterEnvelopeOverlay {
                    appState.openGraduationLetter(modelContext: modelContext)
                }
                .zIndex(350)  // Highest z-index to prevent flash
            }

            // LetterView is now presented via .fullScreenCover on HomeView

            // Confetti Celebration Overlay
            if appState.showConfetti {
                ConfettiOverlay()
                    .zIndex(300)
                    .allowsHitTesting(false)
            }

            // Mood Picker Overlay
            if appState.showMoodPicker {
                MoodPickerView { mood in
                    withAnimation {
                        appState.showMoodPicker = false
                        appState.todayMoodRecorded = true
                    }
                    // Count tasks from the active goal's today data
                    let (total, completed) = countTodayTasks()
                    SupabaseManager.shared.reportDailyReflection(
                        totalTasks: total,
                        completedTasks: completed,
                        mood: mood
                    )
                }
                .zIndex(250)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appState.showCalendar)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appState.showArchive)
        .animation(.easeInOut(duration: 0.8), value: appState.showSplash)
        .animation(.easeInOut(duration: 0.3), value: appState.showConfetti)
        .animation(.easeInOut(duration: 0.3), value: appState.showMoodPicker)
    }

    /// Count today's total and completed tasks from the active goal
    private func countTodayTasks() -> (total: Int, completed: Int) {
        var descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { !$0.isArchived && !$0.isCompleted },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let activeGoal = try? modelContext.fetch(descriptor).first else {
            return (1, 1)
        }

        let calendar = Calendar.current
        let todayTasks = activeGoal.dailyTasks.filter { calendar.isDateInToday($0.date) }
        let total = max(todayTasks.count, 1)
        let completed = todayTasks.filter { $0.isCompleted }.count
        return (total, completed)
    }
}

// MARK: - ========== 状态管理器 ==========

/// Temporal view mode for HomeView
enum TemporalMode {
    case past
    case today
    case future
}

/// Day completion type based on what bubbles were popped
enum DayCompletionType {
    case empty          // Nothing popped
    case choreOnly      // Only chore bubbles popped
    case coreCompleted  // At least one core bubble popped
}

/// Data for a specific day's completion status
struct DayCompletion: Identifiable {
    let id = UUID()
    let date: Date
    var completionType: DayCompletionType
    var bubbles: [Bubble]  // Bubbles for that day
}

class AppState: ObservableObject {
    @Published var showSplash: Bool = true
    @Published var showCalendar: Bool = false
    @Published var showChat: Bool = false
    @Published var showArchive: Bool = false

    // Calendar & temporal state
    @Published var selectedDate: Date = Date()
    @Published var currentTemporalMode: TemporalMode = .today
    @Published var displayedMonth: Date = Date()  // For calendar navigation
    @Published var isViewingDetailedDay: Bool = false  // For zoom transition

    // Day completion data (keyed by date string "yyyy-MM-dd")
    @Published var dayCompletions: [String: DayCompletion] = [:]

    @Published var bubbles: [Bubble] = []
    @Published var chatMessages: [ChatMessage] = [] // SwiftData ChatMessage models

    // MARK: - Goal/Vision Tracking (for AI context)
    /// Current active goal/vision name (set by AI in Phase 1)
    @Published var currentGoalName: String?
    /// Current app phase for AI prompts
    @Published var currentPhase: AppPhase = .onboarding
    /// Flag indicating user is restarting after completing a goal (for context-aware greetings)
    @Published var isRestartingAfterCompletion: Bool = false

    // MARK: - UI Overlays & Notifications
    /// Task detail overlay state
    @Published var showTaskDetail: Bool = false
    @Published var taskDetailGoalTitle: String = ""
    @Published var taskDetailPhaseName: String = ""
    @Published var taskDetailDescription: String = ""
    @Published var taskDetailColor: String = "FFD700"

    /// Floating banner (silent narrator) state
    @Published var showFloatingBanner: Bool = false
    @Published var floatingBannerMessage: String = ""

    /// Goal completion ritual state
    @Published var showLetterEnvelope: Bool = false
    @Published var shouldAutoRequestGraduationLetter: Bool = false
    @Published var showLetterView: Bool = false
    @Published var graduationLetterContent: String = ""
    @Published var graduationLetterTitle: String = ""
    @Published var isLoadingLetter: Bool = false  // Loading state for letter fetch

    /// Celebration animation state (confetti/sparkles)
    @Published var showConfetti: Bool = false

    /// Mood picker state
    @Published var showMoodPicker: Bool = false
    @Published var todayMoodRecorded: Bool = false

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init() {
        bubbles = [
            Bubble(text: "每天写500字", type: .core, position: CGPoint(x: 0.5, y: 0.3)),
            Bubble(text: "回复邮件", type: .small, position: CGPoint(x: 0.25, y: 0.45)),
            Bubble(text: "买菜", type: .small, position: CGPoint(x: 0.7, y: 0.4)),
            Bubble(text: "打电话给妈妈", type: .small, position: CGPoint(x: 0.35, y: 0.65)),
            Bubble(text: "整理房间", type: .small, position: CGPoint(x: 0.65, y: 0.7))
        ]

        // Chat messages will be loaded from SwiftData
        chatMessages = []

        // Initialize sample completion data for demo
        initializeSampleData()
    }

    private func initializeSampleData() {
        let today = Date()

        // Sample task texts for past days
        let coreTasks = ["完成项目报告", "健身30分钟", "学习新技能", "写作练习", "冥想20分钟"]
        let choreTasks = ["回复邮件", "买菜", "整理房间", "洗衣服", "倒垃圾", "做饭", "打电话", "缴费"]

        // Generate sample data for past days in current month
        for dayOffset in 1...10 {
            if let pastDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let key = dateFormatter.string(from: pastDate)
                let random = Double.random(in: 0...1)

                var completionType: DayCompletionType
                var dayBubbles: [Bubble] = []

                if random < 0.2 {
                    // Empty day - no bubbles
                    completionType = .empty
                } else if random < 0.5 {
                    // Chore-only day - 2-4 chore bubbles
                    completionType = .choreOnly
                    let choreCount = Int.random(in: 2...4)
                    for i in 0..<choreCount {
                        let task = choreTasks[Int.random(in: 0..<choreTasks.count)]
                        dayBubbles.append(Bubble(
                            text: task,
                            type: .small,
                            position: CGPoint(
                                x: 0.2 + Double.random(in: 0...0.6),
                                y: 0.25 + Double(i) * 0.15 + Double.random(in: -0.05...0.05)
                            )
                        ))
                    }
                } else {
                    // Core completed day - 1 core + 1-3 chores
                    completionType = .coreCompleted
                    let coreTask = coreTasks[Int.random(in: 0..<coreTasks.count)]
                    dayBubbles.append(Bubble(
                        text: coreTask,
                        type: .core,
                        position: CGPoint(x: 0.5, y: 0.35)
                    ))

                    let choreCount = Int.random(in: 1...3)
                    for i in 0..<choreCount {
                        let task = choreTasks[Int.random(in: 0..<choreTasks.count)]
                        dayBubbles.append(Bubble(
                            text: task,
                            type: .small,
                            position: CGPoint(
                                x: 0.25 + Double(i) * 0.25,
                                y: 0.55 + Double.random(in: -0.05...0.1)
                            )
                        ))
                    }
                }

                dayCompletions[key] = DayCompletion(
                    date: pastDate,
                    completionType: completionType,
                    bubbles: dayBubbles
                )
            }
        }

        // Add some AI-planned future tasks
        for dayOffset in [2, 5, 7] {
            if let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                let key = dateFormatter.string(from: futureDate)
                dayCompletions[key] = DayCompletion(
                    date: futureDate,
                    completionType: .empty,
                    bubbles: [
                        Bubble(text: "AI规划任务", type: .core, position: CGPoint(x: 0.5, y: 0.4))
                    ]
                )
            }
        }
    }

    func enterHome() { showSplash = false }
    func openCalendar() { showCalendar = true }
    func closeCalendar() {
        showCalendar = false
        isViewingDetailedDay = false
    }
    func openChat() { showChat = true }
    func closeChat() { showChat = false }
    func openArchive() { showArchive = true }
    func closeArchive() { showArchive = false }

    func completeBubble(_ bubble: Bubble) {
        if let index = bubbles.firstIndex(where: { $0.id == bubble.id }) {
            bubbles.remove(at: index)
        }

        // Update today's completion status
        let todayKey = dateFormatter.string(from: Date())
        var completion = dayCompletions[todayKey] ?? DayCompletion(date: Date(), completionType: .empty, bubbles: [])

        if bubble.type == .core {
            completion.completionType = .coreCompleted
        } else if completion.completionType == .empty {
            completion.completionType = .choreOnly
        }

        dayCompletions[todayKey] = completion
    }

    func moveBubbleToTomorrow(_ bubble: Bubble) {
        // Remove from today's list
        if let index = bubbles.firstIndex(where: { $0.id == bubble.id }) {
            bubbles.remove(at: index)
        }

        // Calculate tomorrow's date
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) else { return }
        let tomorrowKey = dateFormatter.string(from: tomorrow)

        // Add bubble to tomorrow's day completion
        var completion = dayCompletions[tomorrowKey] ?? DayCompletion(date: tomorrow, completionType: .empty, bubbles: [])
        completion.bubbles.append(bubble)
        dayCompletions[tomorrowKey] = completion
    }

    // addChatMessage is deprecated - messages are now saved directly to SwiftData

    // MARK: - Calendar Helpers

    func dateKey(for date: Date) -> String {
        return dateFormatter.string(from: date)
    }

    func getCompletionType(for date: Date) -> DayCompletionType {
        let key = dateKey(for: date)
        return dayCompletions[key]?.completionType ?? .empty
    }

    func getBubbles(for date: Date, modelContext: ModelContext? = nil) -> [Bubble] {
        // Try to fetch from SwiftData first (if modelContext provided)
        if let context = modelContext {
            // Fetch active goal (not archived)
            var descriptor = FetchDescriptor<Goal>(
                predicate: #Predicate { !$0.isArchived && !$0.isCompleted },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 1

            if let activeGoal = try? context.fetch(descriptor).first {
                // Get task for this date
                if let task = activeGoal.getTaskForDate(date) {
                    // Convert DailyTask to Bubble
                    let bubble = Bubble(
                        text: task.label,
                        type: .core,
                        position: CGPoint(x: 0.5, y: 0.4)
                    )
                    return [bubble]
                }
            }
        }

        // Fallback to dayCompletions dictionary (for sample data or if no SwiftData goal)
        let key = dateKey(for: date)
        return dayCompletions[key]?.bubbles ?? []
    }

    func isToday(_ date: Date) -> Bool {
        return calendar.isDateInToday(date)
    }

    func isPast(_ date: Date) -> Bool {
        return date < calendar.startOfDay(for: Date())
    }

    func isFuture(_ date: Date) -> Bool {
        return date > calendar.startOfDay(for: Date())
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        if isToday(date) {
            currentTemporalMode = .today
        } else if isPast(date) {
            currentTemporalMode = .past
        } else {
            currentTemporalMode = .future
        }
    }

    func navigateToNextMonth() {
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = nextMonth
        }
    }

    func navigateToPreviousMonth() {
        if let prevMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = prevMonth
        }
    }

    // MARK: - AI Context Helpers

    /// Get today's main task (first core bubble)
    func getTodayTask() -> String? {
        return bubbles.first(where: { $0.type == .core })?.text
    }

    /// Calculate current streak days (consecutive days with completed core bubbles)
    func calculateStreakDays() -> Int {
        let today = Date()
        var streak = 0

        // Count backwards from yesterday (don't count today as it's in progress)
        for dayOffset in 1...365 {
            guard let checkDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                break
            }

            let key = dateFormatter.string(from: checkDate)
            if let dayData = dayCompletions[key],
               dayData.completionType == .coreCompleted {
                streak += 1
            } else {
                // Streak broken
                break
            }
        }

        return streak
    }

    /// Reload chat messages from SwiftData
    func reloadChatMessages(from modelContext: ModelContext) {
        var descriptor = FetchDescriptor<ChatMessage>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        if let messages = try? modelContext.fetch(descriptor) {
            self.chatMessages = messages
        }
    }

    /// Initialize welcome message if chat history is empty
    func initializeWelcomeMessageIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<ChatMessage>()
        if let messages = try? modelContext.fetch(descriptor), messages.isEmpty {
            let welcomeMessage = ChatMessage(
                content: "你好呀，今天想聊点什么？或者，有什么想要实现的小愿望吗？",
                isUser: false
            )
            modelContext.insert(welcomeMessage)
            try? modelContext.save()
            reloadChatMessages(from: modelContext)
        }
    }

    // MARK: - UI Overlay Helpers

    /// Show task detail overlay (for long press on bubbles)
    func showTaskDetailOverlay(
        goalTitle: String,
        phaseName: String,
        description: String,
        color: String
    ) {
        taskDetailGoalTitle = goalTitle
        taskDetailPhaseName = phaseName
        taskDetailDescription = description
        taskDetailColor = color
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showTaskDetail = true
        }
    }

    /// Hide task detail overlay
    func hideTaskDetailOverlay() {
        withAnimation(.easeOut(duration: 0.2)) {
            showTaskDetail = false
        }
    }

    /// Show floating banner with encouragement message
    func showBanner(message: String) {
        floatingBannerMessage = message
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showFloatingBanner = true
        }

        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.showFloatingBanner = false
            }
        }
    }

    /// Show celebration animation (confetti/sparkles) for goal completion
    func showCelebration() {
        // Play haptic feedback
        SoundManager.hapticHeavy()

        // Ensure we're in witness phase
        currentPhase = .witness

        // Show confetti animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showConfetti = true
        }

        // Auto-hide confetti after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut(duration: 0.5)) {
                self.showConfetti = false
            }
        }

        // Show the letter envelope after confetti has had time to be seen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.triggerGoalCompletion()
        }
    }

    // MARK: - Goal Completion Ritual

    /// Trigger the goal completion ritual (show letter envelope)
    func triggerGoalCompletion() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showLetterEnvelope = true
        }
        // Note: Letter will be fetched when envelope is tapped (in openGraduationLetter)
    }

    /// Open the graduation letter (called when envelope is tapped)
    func openGraduationLetter(modelContext: ModelContext) {
        // Hide envelope
        withAnimation(.easeOut(duration: 0.3)) {
            showLetterEnvelope = false
        }

        // Move to witness phase
        currentPhase = .witness

        // Set loading state and show LetterView immediately
        isLoadingLetter = true

        // Show letter view immediately (data will load inside)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.showLetterView = true
        }
    }

    /// Fetch graduation letter content (called from LetterView.onAppear)
    func fetchGraduationLetter(modelContext: ModelContext) async {
        do {
            // Fetch the completed goal to get context
            var descriptor = FetchDescriptor<Goal>(
                predicate: #Predicate { $0.isArchived && $0.isCompleted },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 1

            let goalName = try? modelContext.fetch(descriptor).first?.title ?? currentGoalName

            let response = try await ChatService.shared.sendMessage(
                userText: "请为我写一封毕业信",
                phase: .witness,
                goalName: goalName,
                todayTask: nil,
                streakDays: 0,
                context: "用户完成了全部目标任务，请生成毕业信",
                modelContext: modelContext
            )

            await MainActor.run {
                // Extract letter content from response
                self.graduationLetterContent = response.text
                self.graduationLetterTitle = "致亲爱的你"
                self.isLoadingLetter = false

                // Extract identity title from letter (look for patterns like "你已成为..." or ending titles)
                let identityTitle = self.extractIdentityTitle(from: response.text)

                // Save to Archive (ArchivedGoal)
                if let completedGoal = try? modelContext.fetch(descriptor).first {
                    let archivedGoal = ArchivedGoal(
                        title: completedGoal.title,
                        completionDate: Date(),
                        identityTitle: identityTitle,
                        letterContent: response.text,
                        totalDays: completedGoal.totalDays,
                        completedDays: completedGoal.dailyTasks.filter { $0.isCompleted }.count
                    )
                    modelContext.insert(archivedGoal)
                    try? modelContext.save()
                    print("AppState: ✅ Saved ArchivedGoal '\(completedGoal.title)' with identity '\(identityTitle)'")
                }
            }
        } catch {
            print("Failed to fetch graduation letter: \(error)")
            // Fallback: show default message
            await MainActor.run {
                self.graduationLetterContent = "恭喜你完成了这段旅程！微光与你同在。"
                self.graduationLetterTitle = "致亲爱的你"
                self.isLoadingLetter = false
            }
        }
    }

    /// Extract identity title from graduation letter
    /// Looks for patterns like "你已成为...", "成为了...", or titles at the end
    private func extractIdentityTitle(from letterContent: String) -> String {
        // Pattern 1: "你已成为[title]" or "成为了[title]"
        if let range = letterContent.range(of: "你已成为|成为了|你是", options: .regularExpression) {
            let startIndex = letterContent.index(range.upperBound, offsetBy: 0)
            let remaining = String(letterContent[startIndex...])

            // Extract until punctuation or newline
            if let endRange = remaining.rangeOfCharacter(from: CharacterSet(charactersIn: "。，、！\n")) {
                let title = String(remaining[..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty && title.count < 20 {
                    return title
                }
            }
        }

        // Pattern 2: Look for Chinese title patterns at end (e.g., "——微光初燃者")
        let lines = letterContent.components(separatedBy: .newlines)
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("——") || trimmed.hasPrefix("—") {
                let title = trimmed.replacingOccurrences(of: "——", with: "")
                    .replacingOccurrences(of: "—", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !title.isEmpty && title.count < 20 {
                    return title
                }
            }
        }

        // Fallback: Generic title based on goal
        return "微光践行者"
    }

    /// Reset to onboarding phase after graduation (start new cycle)
    func resetToOnboarding(modelContext: ModelContext) {
        print("AppState: 🔄 Resetting to onboarding phase for new cycle")

        // Clear current goal name
        currentGoalName = nil

        // Reset to Phase 1
        currentPhase = .onboarding

        // Set restart flag for context-aware greeting
        isRestartingAfterCompletion = true

        // Clear chat history to start fresh
        ChatService.shared.clearHistory(modelContext: modelContext)

        // Reload empty chat messages
        reloadChatMessages(from: modelContext)

        // Initialize welcome message for new cycle
        initializeWelcomeMessageIfNeeded(modelContext: modelContext)

        print("AppState: ✅ Reset complete - ready for new journey (restart flag set)")
    }

    /// Completely reset all data and return to initial state (new user experience)
    func resetAllData(modelContext: ModelContext) {
        print("AppState: 🗑️ Resetting ALL data to initial state")

        // Delete all Goal records (cascade deletes Phase + DailyTask)
        let goalDescriptor = FetchDescriptor<Goal>()
        if let goals = try? modelContext.fetch(goalDescriptor) {
            for goal in goals {
                modelContext.delete(goal)
            }
        }

        // Delete all ArchivedGoal records
        let archivedDescriptor = FetchDescriptor<ArchivedGoal>()
        if let archived = try? modelContext.fetch(archivedDescriptor) {
            for item in archived {
                modelContext.delete(item)
            }
        }

        // Delete all ChatMessage records
        ChatService.shared.clearHistory(modelContext: modelContext)

        // Clear in-memory state
        bubbles.removeAll()
        dayCompletions.removeAll()
        currentGoalName = nil
        currentPhase = .onboarding
        isRestartingAfterCompletion = false

        // Clear graduation letter state
        graduationLetterContent = ""
        graduationLetterTitle = ""

        // Save deletions
        try? modelContext.save()

        // Reload and initialize welcome message
        reloadChatMessages(from: modelContext)
        initializeWelcomeMessageIfNeeded(modelContext: modelContext)

        // Notify UI
        NotificationCenter.default.post(name: .goalDataDidChange, object: nil)

        print("AppState: ✅ All data reset complete - back to initial state")
    }

    /// Check if completing this bubble completes the goal
    func checkGoalCompletion(modelContext: ModelContext) {
        // Fetch active goal from SwiftData (not archived, not completed)
        var descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { !$0.isArchived && !$0.isCompleted },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let activeGoal = try? modelContext.fetch(descriptor).first else {
            return
        }

        // Check if all tasks are now completed
        if activeGoal.isFullyCompleted {
            // Mark goal as completed
            activeGoal.isCompleted = true
            try? modelContext.save()

            // Trigger completion ritual
            triggerGoalCompletion()
        }
    }
}

struct Bubble: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: BubbleType
    var position: CGPoint

    enum BubbleType {
        case core, small
    }
}

// ChatMessage is now defined in DataModels.swift as a SwiftData @Model

// MARK: - ========== 肥皂泡材质组件 ==========
struct SoapBubbleView: View {
    let size: CGFloat
    let baseColors: [Color]
    let intensity: CGFloat

    @State private var rotationAngle: Double = 0
    @State private var highlightPhase: Double = 0

    init(size: CGFloat, baseColors: [Color], intensity: CGFloat = 0.8) {
        self.size = size
        self.baseColors = baseColors
        self.intensity = intensity
    }

    var body: some View {
        ZStack {
            // Layer 1: 透明基础（更清透 - 降低不透明度）
            Circle()
                .fill(baseColors.first?.opacity(0.02 * intensity) ?? Color.white.opacity(0.02))

            // Layer 2: 边缘光晕 - 柔化处理呈现立体球形
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.5 * intensity),
                            Color.white.opacity(0.15 * intensity)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 3
                )
                .blur(radius: 5)

            // Layer 3: 薄膜干涉（关键层 - 增强绚丽度）
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: baseColors + [baseColors.first!]),
                        center: .center,
                        angle: .degrees(rotationAngle)
                    )
                )
                .opacity(0.75 * intensity)
                .blendMode(.colorDodge)
                .blur(radius: 0.8)

            // Layer 4: 多色径向渐变
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            baseColors[0].opacity(0.3 * intensity),
                            baseColors[1].opacity(0.25 * intensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .blendMode(.overlay)

            // Layer 5: 高光反射
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.9 * intensity),
                            Color.white.opacity(0.4 * intensity),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.3, y: 0.25),
                        startRadius: 0,
                        endRadius: size * 0.35
                    )
                )
                .frame(width: size * 0.6, height: size * 0.6)
                .offset(x: -size * 0.15, y: -size * 0.2)
                .opacity(0.7 + 0.3 * sin(highlightPhase))

            // Layer 6: 次级高光
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.4 * intensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.15
                    )
                )
                .frame(width: size * 0.3, height: size * 0.3)
                .offset(x: -size * 0.25, y: -size * 0.25)

            // Layer 7: 底部阴影
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.1 * intensity),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.5, y: 0.85),
                        startRadius: 0,
                        endRadius: size * 0.3
                    )
                )
        }
        .frame(width: size, height: size)
        .shadow(
            color: baseColors.first?.opacity(0.2 * intensity) ?? Color.clear,
            radius: size * 0.15,
            x: 0,
            y: size * 0.08
        )
        .onAppear {
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                highlightPhase = .pi * 2
            }
        }
    }

    static func splash(size: CGFloat) -> some View {
        SoapBubbleView(
            size: size,
            baseColors: [
                Color(hex: "FFD700"), // Gold
                Color(hex: "FF6B9D"), // Rose pink - 更饱和
                Color(hex: "C77DFF"), // Bright purple - 更饱和
                Color(hex: "4CC9F0"), // Cyan blue - 更饱和
                Color(hex: "7FE3A0"), // Emerald green - 更饱和
                Color(hex: "FF9770"), // Coral orange - 更饱和
                Color(hex: "FFE66D")  // Bright yellow - 更饱和
            ],
            intensity: 3.2  // 增强强度，让颜色更鲜艳
        )
    }

    static func core(size: CGFloat) -> some View {
        SoapBubbleView(
            size: size,
            baseColors: [
                Color(hex: "FFB6C1"),
                Color(hex: "DDA0DD"),
                Color(hex: "87CEEB"),
                Color(hex: "FFD700")
            ],
            intensity: 1.0
        )
    }

    static func small(size: CGFloat) -> some View {
        SoapBubbleView(
            size: size,
            baseColors: [
                Color(hex: "E0E0E0"),
                Color(hex: "B0C4DE"),
                Color(hex: "F0E68C"),
                Color(hex: "DDA0DD")
            ],
            intensity: 0.6
        )
    }
}

// MARK: - ========== 打字机效果 ==========
struct TypewriterText: View {
    let text: String
    let font: Font
    let color: Color
    let speed: Double

    @State private var displayedText: String = ""
    @State private var currentIndex: Int = 0

    init(_ text: String, font: Font = .body, color: Color = .primary, speed: Double = 0.16) {
        self.text = text
        self.font = font
        self.color = color
        self.speed = speed
    }

    var body: some View {
        Text(displayedText)
            .font(font)
            .foregroundColor(color)
            .multilineTextAlignment(.center)
            .onAppear {
                startTyping()
            }
    }

    private func startTyping() {
        displayedText = ""
        currentIndex = 0

        Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { timer in
            if currentIndex < text.count {
                let index = text.index(text.startIndex, offsetBy: currentIndex)
                displayedText.append(text[index])
                currentIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - ========== 声音管理器 ==========
class SoundManager: ObservableObject {
    static let shared = SoundManager()
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    @Published var isSoundEnabled: Bool = true

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("音频会话设置失败: \(error)")
        }
    }

    func play(_ soundName: String, volume: Float = 1.0) {
        guard isSoundEnabled else { return }
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.prepareToPlay()
            player.play()
            audioPlayers[soundName] = player
        } catch {
            print("音效播放失败: \(error)")
        }
    }

    func playBubblePop() { play("pop", volume: 0.7) }
    func playBubbleCreate() { play("create", volume: 0.5) }
    func playTransition() { play("transition", volume: 0.6) }

    static func hapticLight() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    static func hapticMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    static func hapticHeavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
}

// MARK: - ========== 1. Splash 页面（升级版）==========
struct SplashView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLongPressing = false
    @State private var bubbleScale: CGFloat = 1.0
    @State private var showBurstEffect = false
    @State private var pulseAnimation = false
    @State private var showQuote = false

    private let dailyMessage = "点亮微小的日常。"
    private let maxBubbleScale: CGFloat = 4.5

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "FFF9E6"), Color(hex: "FDFCF8")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color(hex: "FFF9E6").opacity(0.5), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .opacity(pulseAnimation ? 0.7 : 0.3)
            .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: pulseAnimation)
            .onAppear {
                pulseAnimation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showQuote = true
                }
            }

            VStack(spacing: 60) {
                Spacer()

                // App Name: 微光计划
                Text("微光计划")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(Color(hex: "CBA972"))
                    .opacity(showQuote ? 1 : 0)

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "FFD700").opacity(0.4),
                                    Color(hex: "FFB6C1").opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 110
                            )
                        )
                        .frame(width: 220, height: 220)
                        .blur(radius: 30)
                        .scaleEffect(bubbleScale)

                    SoapBubbleView.splash(size: 220)
                        .scaleEffect(bubbleScale)
                }
                .gesture(
                    LongPressGesture(minimumDuration: 0.1)
                        .onChanged { _ in startLongPress() }
                        .onEnded { _ in endLongPress() }
                )

                Spacer()

                if showQuote {
                    TypewriterText(
                        dailyMessage,
                        font: .system(size: 20, weight: .medium),
                        color: Color(hex: "CBA972"),
                        speed: 0.24
                    )
                    .padding(.horizontal, 40)
                }

                Text("长按进入")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "6B6B6B").opacity(0.5))
                    .opacity(isLongPressing ? 0 : 1)
                    .padding(.bottom, 60)
            }
            .blur(radius: showBurstEffect ? 20 : 0)
            .opacity(showBurstEffect ? 0 : 1)

            if showBurstEffect {
                BurstTransitionView()
            }
        }
    }

    private func startLongPress() {
        guard !isLongPressing else { return }
        isLongPressing = true
        SoundManager.hapticLight()

        withAnimation(.easeInOut(duration: 2.5)) {
            bubbleScale = maxBubbleScale
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if isLongPressing {
                triggerBurst()
            }
        }
    }

    private func endLongPress() {
        guard isLongPressing else { return }

        if bubbleScale < maxBubbleScale {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                bubbleScale = 1.0
            }
            isLongPressing = false
        }
    }

    private func triggerBurst() {
        SoundManager.hapticHeavy()
        SoundManager.shared.playTransition()
        showBurstEffect = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                appState.enterHome()
            }
        }
    }
}

struct BurstTransitionView: View {
    @State private var particles: [BurstParticle] = []
    @State private var expandingRing: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "FFD700").opacity(0.8),
                            Color(hex: "FFB6C1").opacity(0.4),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 3
                )
                .scaleEffect(expandingRing)
                .opacity(1.0 - Double(expandingRing) / 5.0)
                .blur(radius: 2)

            ForEach(particles) { particle in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                particle.color.opacity(0.9),
                                particle.color.opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: particle.size * 0.5
                        )
                    )
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
                    .blur(radius: 1)
            }
        }
        .onAppear {
            generateBurstEffect()
        }
    }

    private func generateBurstEffect() {
        let center = CGPoint(
            x: UIScreen.main.bounds.width / 2,
            y: UIScreen.main.bounds.height / 2
        )

        let colors: [Color] = [
            Color(hex: "FFD700"),
            Color(hex: "FFB6C1"),
            Color(hex: "87CEEB"),
            Color(hex: "DDA0DD"),
            Color(hex: "FFA500")
        ]

        withAnimation(.easeOut(duration: 1.0)) {
            expandingRing = 5.0
        }

        for i in 0..<50 {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 150...400)
            let endX = center.x + cos(angle) * distance
            let endY = center.y + sin(angle) * distance

            var particle = BurstParticle(
                position: center,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 4...12)
            )

            let delay = Double(i) * 0.01

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.8)) {
                    particle.position = CGPoint(x: endX, y: endY)
                    particle.opacity = 0
                }
                particles.append(particle)
            }
        }
    }
}

struct BurstParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double = 1.0
}

// MARK: - ========== 2. Home 页面（SpriteKit 升级版）==========
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var bubbleScene: BubbleScene = BubbleScene(size: CGSize(width: 430, height: 932))
    @State private var pulseAnimation = false
    @State private var archivePulse = false
    @State private var showingParticles = false
    @State private var isLongPressingLaunch = false
    @State private var launchBubbleScale: CGFloat = 0
    @State private var showSnoozeHint = false
    @State private var snoozeHintText = ""
    @State private var isDraggingBubble = false  // Track when user is dragging a bubble
    @State private var showResetConfirmation = false

    // Task input state
    @State private var showTaskInput = false
    @State private var taskInputText = ""
    @FocusState private var isTaskInputFocused: Bool

    // Computed properties for temporal mode
    private var isReadOnly: Bool {
        appState.currentTemporalMode == .past
    }

    private var showLaunchpad: Bool {
        // Show launchpad for Today and Future (can add tasks)
        appState.currentTemporalMode != .past
    }

    private var isViewingNonToday: Bool {
        appState.currentTemporalMode != .today && appState.isViewingDetailedDay
    }

    private var selectedDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "zh_Hans")
        return formatter.string(from: appState.selectedDate)
    }

    private var temporalModeLabel: String {
        switch appState.currentTemporalMode {
        case .past: return "回顾"
        case .today: return "今天"
        case .future: return "计划"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background changes based on temporal mode
                backgroundView

                VStack(spacing: 0) {
                    // Header with navigation
                    headerView

                    BubbleSceneView(scene: bubbleScene)

                    Spacer()
                }

                // Launchpad Button - Only show for Today and Future
                if showLaunchpad {
                    launchpadView
                        .zIndex(100)
                }

                // AI Chat Button (bottom-right) - Only show for Today
                if appState.currentTemporalMode == .today {
                    aiChatButton
                }

                // Snooze hint
                if showSnoozeHint {
                    snoozeHintView
                }

                // Task Input Overlay
                if showTaskInput {
                    taskInputOverlay
                        .zIndex(200)
                }

                // Read-only indicator for past dates
                if isReadOnly {
                    readOnlyIndicator
                }
            }
            .onAppear {
                setupScene(geometry: geometry)
            }
            .onChange(of: appState.currentTemporalMode) { _ in
                // Reload bubbles when temporal mode changes
                reloadBubblesForCurrentMode(geometry: geometry)
            }
            .onChange(of: appState.selectedDate) { _ in
                reloadBubblesForCurrentMode(geometry: geometry)
            }
            .onReceive(NotificationCenter.default.publisher(for: .goalDataDidChange)) { notification in
                // Goal data changed (created/updated/deleted) - refresh the view
                print("HomeView: 🔄 Received goalDataDidChange notification - refreshing data")

                // Fetch updated goal data from SwiftData (not archived)
                let descriptor = FetchDescriptor<Goal>(
                    predicate: #Predicate { !$0.isArchived && !$0.isCompleted },
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )

                if let activeGoal = try? modelContext.fetch(descriptor).first {
                    print("HomeView: ✅ Found active goal: '\(activeGoal.title)'")

                    // Update app state with new goal
                    appState.currentGoalName = activeGoal.title

                    // Get today's task
                    if let todayTask = activeGoal.getTaskForDate(Date()) {
                        print("HomeView: ✅ Today's task: '\(todayTask.label)'")

                        // Create bubble for today's task if not already completed
                        if !todayTask.isCompleted {
                            // Clear existing bubbles
                            appState.bubbles.removeAll()

                            // Add core bubble for today
                            let coreBubble = Bubble(
                                text: todayTask.label,
                                type: .core,
                                position: CGPoint(x: 0.5, y: 0.4)
                            )
                            appState.bubbles.append(coreBubble)

                            // Reload bubble scene
                            reloadBubblesForCurrentMode(geometry: geometry)
                        }
                    }
                } else {
                    print("HomeView: ⚠️ No active goal found after notification")
                }
            }
            .fullScreenCover(isPresented: $appState.showChat) {
                ChatView()
                    .environmentObject(appState)
            }
            .fullScreenCover(isPresented: $appState.showLetterView) {
                LetterView(appState: appState, modelContext: modelContext)
            }
        }
    }

    // MARK: - Background View
    private var backgroundView: some View {
        ZStack {
            // Base gradient - varies by temporal mode
            LinearGradient(
                colors: backgroundGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Breathing pulse - only for Today
            if appState.currentTemporalMode == .today {
                RadialGradient(
                    colors: [Color(hex: "FFF9E6").opacity(0.5), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 400
                )
                .opacity(pulseAnimation ? 0.7 : 0.4)
                .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: pulseAnimation)
                .onAppear { pulseAnimation = true }
            }

            // Past mode: subtle frost overlay
            if appState.currentTemporalMode == .past {
                Color.white.opacity(0.05)
                    .ignoresSafeArea()
            }
        }
    }

    private var backgroundGradientColors: [Color] {
        switch appState.currentTemporalMode {
        case .today:
            return [Color(hex: "FFF9E6"), Color(hex: "FDFCF8")]
        case .past:
            // Slightly cooler/muted tones for "crystallized" past
            return [Color(hex: "F5F3EE"), Color(hex: "EBE9E4")]
        case .future:
            // Slightly cooler/hopeful tones for future
            return [Color(hex: "F8FAFF"), Color(hex: "F0F5FF")]
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            // Back button (when viewing non-today) or Calendar button
            if isViewingNonToday {
                Button(action: {
                    // Return to today
                    appState.selectDate(Date())
                    appState.isViewingDetailedDay = false
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("返回今天")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "6B6B6B"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.ultraThinMaterial))
                }
            } else {
                // Calendar button with soft glow halo and drag hint
                VStack(spacing: 8) {
                    Button(action: { appState.openCalendar() }) {
                        ZStack {
                            // Soft glow halo - enhanced when dragging
                            Circle()
                                .fill(Color.white.opacity(isDraggingBubble ? 0.6 : 0.3))
                                .frame(width: isDraggingBubble ? 60 : 50, height: isDraggingBubble ? 60 : 50)
                                .blur(radius: isDraggingBubble ? 12 : 8)
                                .animation(.easeInOut(duration: 0.3), value: isDraggingBubble)

                            Image(systemName: "calendar")
                                .font(.system(size: 20))
                                .foregroundColor(isDraggingBubble ? Color(hex: "CBA972") : Color(hex: "6B6B6B"))
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(.ultraThinMaterial))
                                .animation(.easeInOut(duration: 0.3), value: isDraggingBubble)
                        }
                    }
                    .onLongPressGesture(minimumDuration: 2) {
                        showResetConfirmation = true
                    }
                    .confirmationDialog(
                        "重置所有数据",
                        isPresented: $showResetConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("确定重置", role: .destructive) {
                            appState.resetAllData(modelContext: modelContext)
                        }
                        Button("取消", role: .cancel) {}
                    } message: {
                        Text("确定要重置所有数据吗？这将清除所有对话、目标和光球记录，回到初始状态。此操作不可撤销。")
                    }

                    // Hint text for drag-to-tomorrow feature - only visible when dragging
                    if isDraggingBubble {
                        Text("转为明日待办清单")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: "CBA972"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: Color(hex: "CBA972").opacity(0.3), radius: 4, x: 0, y: 2)
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isDraggingBubble)
            }

            Spacer()

            // Date label when viewing specific date
            if isViewingNonToday {
                VStack(spacing: 2) {
                    Text(selectedDateString)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "6B6B6B"))
                    Text(temporalModeLabel)
                        .font(.system(size: 11))
                        .foregroundColor(temporalModeLabelColor)
                }
            }

            Spacer()

            // Archive button with soft glow halo (sparkles icon)
            Button(action: { appState.openArchive() }) {
                ZStack {
                    // Soft glow halo
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .blur(radius: 8)

                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "6B6B6B"))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.ultraThinMaterial))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var temporalModeLabelColor: Color {
        switch appState.currentTemporalMode {
        case .past: return Color(hex: "8B7355")
        case .today: return Color(hex: "CBA972")
        case .future: return Color(hex: "87CEEB")
        }
    }

    // MARK: - Launchpad View
    private var launchpadView: some View {
        VStack {
            Spacer()

            VStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color(hex: "CBA972").opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(Circle().fill(.ultraThinMaterial))
                    .frame(width: 70, height: 70)
                    .shadow(color: Color(hex: "CBA972").opacity(0.3), radius: 24, x: 0, y: 8)
                    .overlay(
                        Text("+")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(Color(hex: "CBA972").opacity(0.8))
                    )
                    .scaleEffect(isLongPressingLaunch ? 0.9 : 1.0)
                    .onLongPressGesture(minimumDuration: 0.5) {
                        // Show task input when long press completes
                        SoundManager.hapticMedium()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            showTaskInput = true
                            isTaskInputFocused = true
                        }
                    } onPressingChanged: { pressing in
                        // Visual feedback during press
                        withAnimation(.easeOut(duration: 0.2)) {
                            isLongPressingLaunch = pressing
                        }
                    }

                Text("长按创建待办清单")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "6B6B6B").opacity(0.6))
                    .opacity(isLongPressingLaunch ? 0 : 1)
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: - AI Chat Button (Lumi Pet Avatar)
    private var aiChatButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()

                Button(action: { appState.openChat() }) {
                    LumiPetAvatar()
                }
                .padding(.trailing, 24)
                .padding(.bottom, 110)
            }
        }
    }

    // MARK: - Snooze Hint View
    private var snoozeHintView: some View {
        VStack {
            Spacer()
            Text(snoozeHintText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color(hex: "6B6B6B").opacity(0.9)))
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 100)
        }
    }

    // MARK: - Read-Only Indicator
    private var readOnlyIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                Text("只读模式 - 过去的光球已凝结")
                    .font(.system(size: 12))
            }
            .foregroundColor(Color(hex: "8B7355").opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.8)))
            .padding(.bottom, 30)
        }
    }

    // MARK: - Task Input Overlay
    private var taskInputOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissTaskInput()
                }

            // Input card
            VStack(spacing: 20) {
                Text(appState.currentTemporalMode == .future ? "添加未来计划" : "新建琐事")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: "6B6B6B"))

                TextField("写下你的任务...", text: $taskInputText)
                    .focused($isTaskInputFocused)
                    .font(.system(size: 16))
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "CBA972").opacity(0.3), lineWidth: 1)
                            )
                    )
                    .onSubmit {
                        createTaskBubble()
                    }

                HStack(spacing: 12) {
                    Button(action: {
                        dismissTaskInput()
                    }) {
                        Text("取消")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "6B6B6B"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.7))
                            )
                    }

                    Button(action: {
                        createTaskBubble()
                    }) {
                        Text("创建")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "CBA972"),
                                                Color(hex: "CBA972").opacity(0.8)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    }
                    .disabled(taskInputText.isEmpty)
                    .opacity(taskInputText.isEmpty ? 0.5 : 1.0)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: - Scene Setup
    private func setupScene(geometry: GeometryProxy) {
        bubbleScene.size = geometry.size
        bubbleScene.archivePosition = CGPoint(
            x: geometry.size.width - 55,
            y: geometry.size.height - 140
        )

        bubbleScene.calendarPosition = CGPoint(
            x: 30,
            y: geometry.size.height - 50
        )

        // Set read-only mode based on temporal state
        bubbleScene.isReadOnly = isReadOnly

        // Load appropriate bubbles
        loadBubblesForCurrentMode()

        // Set up interaction handlers based on temporal mode
        if appState.currentTemporalMode == .today {
            // Today: Full interactivity (tap, drag, long press)
            bubbleScene.onBubbleTapped = { bubbleId in
                popBubble(bubbleId)
            }

            bubbleScene.onBubbleFlung = { bubbleId in
                snoozeBubble(bubbleId)
            }

            bubbleScene.onBubbleLongPressed = { bubbleId in
                showBubbleDetail(bubbleId)
            }

            bubbleScene.onDragStateChanged = { isDragging in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isDraggingBubble = isDragging
                }
            }
        } else if appState.currentTemporalMode == .future {
            // Future: Long press only (view details)
            bubbleScene.onBubbleTapped = nil
            bubbleScene.onBubbleFlung = nil
            bubbleScene.onBubbleLongPressed = { bubbleId in
                showBubbleDetail(bubbleId)
            }
            bubbleScene.onDragStateChanged = nil
        } else {
            // Past (read-only): Long press only (view details)
            bubbleScene.onBubbleTapped = nil
            bubbleScene.onBubbleFlung = nil
            bubbleScene.onBubbleLongPressed = { bubbleId in
                showBubbleDetail(bubbleId)
            }
            bubbleScene.onDragStateChanged = nil
        }
    }

    private func reloadBubblesForCurrentMode(geometry: GeometryProxy) {
        // Clear existing bubbles
        bubbleScene.clearAllBubbles()

        // Update read-only mode
        bubbleScene.isReadOnly = isReadOnly

        // Load bubbles for current mode
        loadBubblesForCurrentMode()

        // Update interaction handlers based on temporal mode
        if appState.currentTemporalMode == .today {
            // Today: Full interactivity
            bubbleScene.onBubbleTapped = { bubbleId in
                popBubble(bubbleId)
            }
            bubbleScene.onBubbleFlung = { bubbleId in
                snoozeBubble(bubbleId)
            }
            bubbleScene.onBubbleLongPressed = { bubbleId in
                showBubbleDetail(bubbleId)
            }
            bubbleScene.onDragStateChanged = { isDragging in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isDraggingBubble = isDragging
                }
            }
        } else if appState.currentTemporalMode == .future {
            // Future: Long press only
            bubbleScene.onBubbleTapped = nil
            bubbleScene.onBubbleFlung = nil
            bubbleScene.onBubbleLongPressed = { bubbleId in
                showBubbleDetail(bubbleId)
            }
            bubbleScene.onDragStateChanged = nil
        } else {
            // Past: Long press only
            bubbleScene.onBubbleTapped = nil
            bubbleScene.onBubbleFlung = nil
            bubbleScene.onBubbleLongPressed = { bubbleId in
                showBubbleDetail(bubbleId)
            }
            bubbleScene.onDragStateChanged = nil
        }
    }

    private func loadBubblesForCurrentMode() {
        switch appState.currentTemporalMode {
        case .today:
            // Load today's bubbles from appState
            for bubble in appState.bubbles {
                bubbleScene.addBubble(bubble: bubble)
            }
        case .past, .future:
            // Load bubbles for the selected date from SwiftData
            let dateBubbles = appState.getBubbles(for: appState.selectedDate, modelContext: modelContext)
            for bubble in dateBubbles {
                bubbleScene.addBubble(bubble: bubble, isStatic: isReadOnly)
            }
        }
    }

    // MARK: - Task Input Functions
    private func dismissTaskInput() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showTaskInput = false
        }
        taskInputText = ""
        isTaskInputFocused = false
    }

    private func createTaskBubble() {
        guard !taskInputText.isEmpty else { return }

        SoundManager.hapticMedium()
        SoundManager.shared.playBubbleCreate()

        // Create new small bubble (chore type)
        let newBubble = Bubble(
            text: taskInputText,
            type: .small,
            position: CGPoint(x: 0.5, y: 0.5)
        )

        if appState.currentTemporalMode == .today {
            // Add to today's bubbles
            appState.bubbles.append(newBubble)
        } else if appState.currentTemporalMode == .future {
            // Add to future date's planned bubbles
            let key = appState.dateKey(for: appState.selectedDate)
            var completion = appState.dayCompletions[key] ?? DayCompletion(
                date: appState.selectedDate,
                completionType: .empty,
                bubbles: []
            )
            completion.bubbles.append(newBubble)
            appState.dayCompletions[key] = completion
        }

        // Add to SpriteKit scene
        let centerX = bubbleScene.size.width / 2 + CGFloat.random(in: -30...30)
        let centerY = bubbleScene.size.height / 2 + CGFloat.random(in: -30...30)
        bubbleScene.addBubble(bubble: newBubble, at: CGPoint(x: centerX, y: centerY))

        dismissTaskInput()
    }

    private func popBubble(_ bubbleId: UUID) {
        guard let bubble = appState.bubbles.first(where: { $0.id == bubbleId }) else { return }
        bubbleScene.popBubble(id: bubbleId)
        appState.completeBubble(bubble)

        // Mark the corresponding DailyTask as completed in SwiftData
        var descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { !$0.isArchived && !$0.isCompleted },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let activeGoal = try? modelContext.fetch(descriptor).first,
           let todayTask = activeGoal.getTaskForDate(Date()) {

            // Mark task as completed
            todayTask.isCompleted = true
            try? modelContext.save()

            // Report task completion to Supabase
            SupabaseManager.shared.reportTaskCompletion(
                title: todayTask.label,
                scheduledDate: todayTask.date
            )

            print("HomeView: ✅ Marked DailyTask '\(todayTask.label)' as completed")

            // Check if this was the last task (Trigger 2: Physical - Popping Last Bubble)
            if todayTask.isLastTaskOfGoal {
                print("HomeView: 🎉 Last bubble popped! Triggering Goal Completion Ritual")

                // Mark remaining future tasks as completed (user finished early)
                for task in activeGoal.dailyTasks where !task.isCompleted {
                    task.isCompleted = true
                }

                // Mark goal as completed AND archived
                activeGoal.isCompleted = true
                activeGoal.isArchived = true
                try? modelContext.save()

                // Update app state to witness phase
                self.appState.currentPhase = .witness

                // Trigger the ritual (confetti + letter envelope)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.appState.showCelebration()
                }
            }
        }

        // Also check for natural goal completion (all tasks done on schedule)
        appState.checkGoalCompletion(modelContext: modelContext)

        // Trigger mood picker if all today's core bubbles have been popped (removed)
        if !appState.todayMoodRecorded {
            let remainingCoreBubbles = appState.bubbles.filter { $0.type == .core }
            if remainingCoreBubbles.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.appState.showMoodPicker = true
                }
            }
        }

        // Silent Narrator: Get encouragement from AI (with guaranteed fallback)
        let fallbackMessages = [
            "微光虽小，但你把它点亮了。",
            "又一颗星尘，正在汇聚成光。",
            "做得好！保持节奏。",
            "每一步，都是向着光的方向。",
            "很棒！继续加油！",
            "坚持的你，正在发光。"
        ]

        Task {
            do {
                let goalName = appState.currentGoalName
                let todayTask = appState.getTodayTask()
                let streakDays = appState.calculateStreakDays()

                let encouragement = try await ChatService.shared.sendSilentEvent(
                    trigger: "completed",
                    goalName: goalName,
                    todayTask: todayTask,
                    streakDays: streakDays,
                    context: "用户完成了任务：\(bubble.text)"
                )

                await MainActor.run {
                    // Only show if we got a valid response
                    let message = encouragement.isEmpty ? fallbackMessages.randomElement()! : encouragement
                    appState.showBanner(message: message)
                }
            } catch {
                print("Silent event error: \(error.localizedDescription)")
                // Show fallback encouragement (always show something)
                await MainActor.run {
                    appState.showBanner(message: fallbackMessages.randomElement()!)
                }
            }
        }
    }

    private func snoozeBubble(_ bubbleId: UUID) {
        guard let bubble = appState.bubbles.first(where: { $0.id == bubbleId }) else { return }

        // Remove bubble from scene with animation
        bubbleScene.removeBubble(bubbleId, animated: true)

        // Move bubble to tomorrow's bubble sea
        appState.moveBubbleToTomorrow(bubble)

        // Haptic feedback for successful transfer
        SoundManager.hapticMedium()

        // Silent Narrator: Get encouragement for postponing (with fallback)
        let fallbackMessages = [
            "允许暂停，也是一种前进。",
            "明天的你，会感谢今天的安排。",
            "休息是为了走更远的路。",
            "调整节奏，不是放弃。",
            "给自己一些喘息的空间。"
        ]

        Task {
            do {
                let goalName = appState.currentGoalName
                let todayTask = appState.getTodayTask()
                let streakDays = appState.calculateStreakDays()

                let encouragement = try await ChatService.shared.sendSilentEvent(
                    trigger: "delay",
                    goalName: goalName,
                    todayTask: todayTask,
                    streakDays: streakDays,
                    context: "用户将任务「\(bubble.text)」推迟到明天"
                )

                await MainActor.run {
                    let message = encouragement.isEmpty ? fallbackMessages.randomElement()! : encouragement
                    appState.showBanner(message: message)
                }
            } catch {
                print("Silent event (delay) error: \(error.localizedDescription)")
                await MainActor.run {
                    appState.showBanner(message: fallbackMessages.randomElement()!)
                }
            }
        }

        // Also show the snooze hint UI
        snoozeHintText = "「\(bubble.text)」已转为明日待办"
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showSnoozeHint = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showSnoozeHint = false
            }
        }
    }

    private func showBubbleDetail(_ bubbleId: UUID) {
        guard let bubble = appState.bubbles.first(where: { $0.id == bubbleId }) else { return }
        guard bubble.type == .core else { return } // Only show detail for core bubbles

        // TODO: Fetch real goal data from SwiftData when Goal system is fully integrated
        // For now, show placeholder data
        appState.showTaskDetailOverlay(
            goalTitle: appState.currentGoalName ?? "未设置目标",
            phaseName: "习惯养成期",
            description: bubble.text + "\n\n这是一个核心任务，需要每日完成。长期坚持将帮助你实现目标。",
            color: "FFD700"
        )
    }
}

// MARK: - ========== SwiftUI to SpriteKit Snapshot Helper ==========
@available(iOS 16.0, *)
extension View {
    func renderToSKTexture(size: CGSize) -> SKTexture? {
        let renderer = ImageRenderer(content: self
            .background(Color.clear)           // CRITICAL: Transparent background
            .clipShape(Circle())                // CRITICAL: Round, not square
            .compositingGroup()                 // Preserve transparency
        )

        renderer.proposedSize = ProposedViewSize(size)
        renderer.isOpaque = false              // CRITICAL: Enable transparency
        renderer.scale = UIScreen.main.scale   // Retina quality

        if let uiImage = renderer.uiImage {
            return SKTexture(image: uiImage)
        }
        return nil
    }
}

// MARK: - ========== SpriteKit Soap Bubble System (SwiftUI Snapshot) ==========
class BubbleNode: SKNode {
    let bubbleId: UUID
    let bubbleText: String
    let bubbleType: Bubble.BubbleType

    // Frozen mode for past bubbles (crystallized glass marble look)
    let isFrozen: Bool

    // Store base color for particle effects
    var baseColor: UIColor = .white

    // Visual layers
    private var bubbleSprite: SKSpriteNode!
    private var glowSprite: SKSpriteNode?
    private var colorWheelSprite: SKSpriteNode?
    private var highlightSprite: SKSpriteNode?
    private var textLabel: SKLabelNode!

    init(bubble: Bubble, radius: CGFloat, isStatic: Bool = false) {
        self.bubbleId = bubble.id
        self.bubbleText = bubble.text
        self.bubbleType = bubble.type
        self.isFrozen = isStatic
        super.init()

        let diameter = radius * 2

        if bubbleType == .core {
            self.baseColor = UIColor(Color(hex: "FFD700"))
            if isFrozen {
                // FROZEN CORE: Crystallized glass marble look
                let bubbleTexture = renderFrozenCoreBubbleTexture(size: diameter)
                createBubbleSprite(texture: bubbleTexture, size: diameter)
            } else {
                // ALIVE CORE: Multi-layer orb matching onboarding SoapBubbleView.splash
                // We decompose the SwiftUI SoapBubbleView into separate SpriteKit layers
                // so we can animate rotation/pulse independently (SwiftUI animations are lost in texture snapshots)

                // Layer 0: Outer glow halo (blurred, behind everything)
                let glowFrameSize = diameter * 2.2
                if let glowTex = renderGlowTexture(bubbleDiameter: diameter, frameSize: glowFrameSize) {
                    let glow = SKSpriteNode(texture: glowTex)
                    glow.size = CGSize(width: glowFrameSize, height: glowFrameSize)
                    glow.zPosition = -2
                    addChild(glow)
                    self.glowSprite = glow
                    addGlowAnimations(to: glow)
                }

                // Layer 1: Color wheel (AngularGradient) — this layer ROTATES
                if let wheelTex = renderColorWheelTexture(size: diameter) {
                    let wheel = SKSpriteNode(texture: wheelTex)
                    wheel.size = CGSize(width: diameter, height: diameter)
                    wheel.blendMode = .add  // Matches SwiftUI .colorDodge
                    wheel.zPosition = -1
                    addChild(wheel)
                    self.colorWheelSprite = wheel
                    addRotationAnimation(to: wheel)
                }

                // Layer 2: Static bubble shell (edge glow, radial gradient, shadow — NO AngularGradient)
                if let shellTex = renderBubbleShellTexture(size: diameter) {
                    let shell = SKSpriteNode(texture: shellTex)
                    shell.size = CGSize(width: diameter, height: diameter)
                    shell.zPosition = 0
                    addChild(shell)
                    self.bubbleSprite = shell
                    addBubblePulseAnimation(to: shell)
                }

                // Layer 3: Highlight (pulsing opacity like onboarding's highlightPhase)
                if let hlTex = renderHighlightTexture(size: diameter) {
                    let hl = SKSpriteNode(texture: hlTex)
                    hl.size = CGSize(width: diameter, height: diameter)
                    hl.zPosition = 1
                    addChild(hl)
                    self.highlightSprite = hl
                    addHighlightPulseAnimation(to: hl)
                }
            }
        } else {
            let hazyPalettes = [
                ["FFFFFF", "FFB6C1", "CBA972"],  // Pink
                ["FFFFFF", "B0E0E6", "CBA972"],  // Blue
                ["FFFFFF", "F0E68C", "D2B48C"],  // Yellow
                ["FFFFFF", "E0BBE4", "CBA972"],  // Lavender
                ["FFFFFF", "ADD8E6", "9CB4CC"]   // Light Blue
            ]
            let chosenPalette = hazyPalettes.randomElement()!
            self.baseColor = UIColor(Color(hex: chosenPalette[1]))

            if isFrozen {
                // FROZEN CHORE: Solid matte bead
                let bubbleTexture = renderFrozenChoreBubbleTexture(size: diameter, colors: chosenPalette)
                createBubbleSprite(texture: bubbleTexture, size: diameter)
            } else {
                // ALIVE CHORE: Soft hazy bubble
                let bubbleTexture = renderChoreBubbleTexture(size: diameter, colors: chosenPalette)
                createBubbleSprite(texture: bubbleTexture, size: diameter)
            }
        }

        // Only add physics for dynamic (non-frozen) bubbles
        if !isFrozen {
            setupPhysicsBody(radius: radius)
        }

        addTextLabel(radius: radius)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - ALIVE Bubble Rendering (Transparent, Airy, Soap Bubble)
    private func renderCoreBubbleTexture(size: CGFloat) -> SKTexture? {
        if #available(iOS 16.0, *) {
            let bubbleView = SoapBubbleView.splash(size: size)
            return bubbleView.renderToSKTexture(size: CGSize(width: size, height: size))
        } else {
            return renderCoreBubbleFallback(size: size)
        }
    }

    // MARK: - Multi-layer Core Orb Rendering (matches onboarding SoapBubbleView.splash)

    /// Outer glow halo with blur baked into the texture (matches SplashView's blurred RadialGradient)
    private func renderGlowTexture(bubbleDiameter: CGFloat, frameSize: CGFloat) -> SKTexture? {
        if #available(iOS 16.0, *) {
            let glowView = Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "FFD700").opacity(0.45),
                            Color(hex: "FFB6C1").opacity(0.35),
                            Color(hex: "FFB6C1").opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: bubbleDiameter * 0.5
                    )
                )
                .frame(width: bubbleDiameter, height: bubbleDiameter)
                .blur(radius: bubbleDiameter * 0.18)  // Matches onboarding's blur(30) scaled down
                .frame(width: frameSize, height: frameSize)
            return glowView.renderToSKTexture(size: CGSize(width: frameSize, height: frameSize))
        } else {
            let image = UIGraphicsImageRenderer(size: CGSize(width: frameSize, height: frameSize)).image { ctx in
                let colors: [CGColor] = [
                    UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.45).cgColor,
                    UIColor(red: 1.0, green: 0.71, blue: 0.76, alpha: 0.35).cgColor,
                    UIColor.clear.cgColor
                ]
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors as CFArray,
                                         locations: [0.0, 0.5, 1.0])!
                ctx.cgContext.drawRadialGradient(gradient,
                                                startCenter: CGPoint(x: frameSize/2, y: frameSize/2),
                                                startRadius: 0,
                                                endCenter: CGPoint(x: frameSize/2, y: frameSize/2),
                                                endRadius: frameSize/2,
                                                options: [])
            }
            return SKTexture(image: image)
        }
    }

    /// AngularGradient color wheel — Layer 3 from SoapBubbleView, rendered alone so it can rotate in SpriteKit
    private func renderColorWheelTexture(size: CGFloat) -> SKTexture? {
        let splashColors: [Color] = [
            Color(hex: "FFD700"),
            Color(hex: "FF6B9D"),
            Color(hex: "C77DFF"),
            Color(hex: "4CC9F0"),
            Color(hex: "7FE3A0"),
            Color(hex: "FF9770"),
            Color(hex: "FFE66D"),
            Color(hex: "FFD700")  // close the loop
        ]

        if #available(iOS 16.0, *) {
            // Render at moderate opacity; .add blend mode in SpriteKit will brighten it
            let wheelView = Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: splashColors),
                        center: .center,
                        angle: .degrees(0)
                    )
                )
                .opacity(0.7)
                .blur(radius: 1.0)
                .frame(width: size, height: size)
            return wheelView.renderToSKTexture(size: CGSize(width: size, height: size))
        } else {
            return nil
        }
    }

    /// Static bubble shell — edge glow, radial gradient, bottom shadow (everything EXCEPT AngularGradient & highlight)
    private func renderBubbleShellTexture(size: CGFloat) -> SKTexture? {
        let splashColors: [Color] = [
            Color(hex: "FFD700"),
            Color(hex: "FF6B9D"),
            Color(hex: "C77DFF"),
            Color(hex: "4CC9F0"),
            Color(hex: "7FE3A0"),
            Color(hex: "FF9770"),
            Color(hex: "FFE66D")
        ]
        let intensity: CGFloat = 3.2

        if #available(iOS 16.0, *) {
            let shellView = ZStack {
                // Layer 1: Transparent base
                Circle()
                    .fill(splashColors.first!.opacity(0.02 * intensity))

                // Layer 2: Edge glow
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5 * intensity),
                                Color.white.opacity(0.15 * intensity)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 3
                    )
                    .blur(radius: 5)

                // Layer 4: Multi-color radial gradient
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                splashColors[0].opacity(0.3 * intensity),
                                splashColors[1].opacity(0.25 * intensity),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.5
                        )
                    )

                // Layer 6: Secondary highlight
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.4 * intensity),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.15
                        )
                    )
                    .frame(width: size * 0.3, height: size * 0.3)
                    .offset(x: -size * 0.25, y: -size * 0.25)

                // Layer 7: Bottom shadow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.black.opacity(0.1 * intensity),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.5, y: 0.85),
                            startRadius: 0,
                            endRadius: size * 0.3
                        )
                    )
            }
            .frame(width: size, height: size)
            return shellView.renderToSKTexture(size: CGSize(width: size, height: size))
        } else {
            return renderCoreBubbleFallback(size: size)
        }
    }

    /// Main highlight reflection — Layer 5 from SoapBubbleView, rendered alone so we can pulse its opacity
    private func renderHighlightTexture(size: CGFloat) -> SKTexture? {
        let intensity: CGFloat = 3.2

        if #available(iOS 16.0, *) {
            let hlView = Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.9 * intensity),
                            Color.white.opacity(0.4 * intensity),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.3, y: 0.25),
                        startRadius: 0,
                        endRadius: size * 0.35
                    )
                )
                .frame(width: size * 0.6, height: size * 0.6)
                .offset(x: -size * 0.15, y: -size * 0.2)
                .frame(width: size, height: size)
            return hlView.renderToSKTexture(size: CGSize(width: size, height: size))
        } else {
            return nil
        }
    }

    // MARK: - Core Orb Animations

    private func addGlowAnimations(to sprite: SKSpriteNode) {
        // Opacity pulse: 0.5 ↔ 0.85, ~3.5s (matches onboarding background pulse)
        let fadeUp = SKAction.fadeAlpha(to: 0.85, duration: 3.5)
        let fadeDown = SKAction.fadeAlpha(to: 0.5, duration: 3.5)
        fadeUp.timingMode = .easeInEaseOut
        fadeDown.timingMode = .easeInEaseOut
        let opacityPulse = SKAction.sequence([fadeUp, fadeDown])
        sprite.run(SKAction.repeatForever(opacityPulse), withKey: "glowOpacity")

        // Scale pulse: 1.0 ↔ 1.06, ~4s
        let scaleUp = SKAction.scale(to: 1.06, duration: 4.0)
        let scaleDown = SKAction.scale(to: 1.0, duration: 4.0)
        scaleUp.timingMode = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut
        let scalePulse = SKAction.sequence([scaleUp, scaleDown])
        sprite.run(SKAction.repeatForever(scalePulse), withKey: "glowScale")

        sprite.alpha = 0.7
    }

    /// Highlight opacity pulse: matches SoapBubbleView's `0.7 + 0.3 * sin(highlightPhase)` animation
    private func addHighlightPulseAnimation(to sprite: SKSpriteNode) {
        let fadeUp = SKAction.fadeAlpha(to: 1.0, duration: 1.5)
        let fadeDown = SKAction.fadeAlpha(to: 0.7, duration: 1.5)
        fadeUp.timingMode = .easeInEaseOut
        fadeDown.timingMode = .easeInEaseOut
        let pulse = SKAction.sequence([fadeUp, fadeDown])
        sprite.run(SKAction.repeatForever(pulse), withKey: "highlightPulse")
        sprite.alpha = 0.85
    }

    private func renderChoreBubbleTexture(size: CGFloat, colors: [String]) -> SKTexture? {
        if #available(iOS 16.0, *) {
            let bubbleView = createChoreBubbleView(size: size, colorHexes: colors)
            return bubbleView.renderToSKTexture(size: CGSize(width: size, height: size))
        } else {
            return renderChoreBubbleFallback(size: size, colors: colors)
        }
    }

    private func createChoreBubbleView(size: CGFloat, colorHexes: [String]) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hex: colorHexes[0]).opacity(0.9),
                        Color(hex: colorHexes[1]).opacity(0.6),
                        Color(hex: colorHexes[2]).opacity(0.4)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.5
                )
            )
            .shadow(color: .white.opacity(0.3), radius: 3, x: 0, y: 0)
            .frame(width: size, height: size)
    }

    // MARK: - FROZEN Bubble Rendering (Opaque, Solid, Glass Marble)
    private func renderFrozenCoreBubbleTexture(size: CGFloat) -> SKTexture? {
        if #available(iOS 16.0, *) {
            let frozenView = createFrozenCoreBubbleView(size: size)
            return frozenView.renderToSKTexture(size: CGSize(width: size, height: size))
        } else {
            return renderCoreBubbleFallback(size: size)
        }
    }

    private func renderFrozenChoreBubbleTexture(size: CGFloat, colors: [String]) -> SKTexture? {
        if #available(iOS 16.0, *) {
            let frozenView = createFrozenChoreBubbleView(size: size, colorHexes: colors)
            return frozenView.renderToSKTexture(size: CGSize(width: size, height: size))
        } else {
            return renderChoreBubbleFallback(size: size, colors: colors)
        }
    }

    // Frozen Core: Crystallized rainbow glass marble - brighter colors, high opacity, soft edge
    @ViewBuilder
    private func createFrozenCoreBubbleView(size: CGFloat) -> some View {
        ZStack {
            // Base fill - brighter rainbow colors, still crystallized
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            // Brighter but still "settled" rainbow colors
                            Color(hex: "E8C55A").opacity(0.80),  // Warm gold
                            Color(hex: "E89AAE").opacity(0.75),  // Soft rose
                            Color(hex: "B8A0D8").opacity(0.75),  // Light purple
                            Color(hex: "8ECCE8").opacity(0.75),  // Sky cyan
                            Color(hex: "90D8A8").opacity(0.75),  // Fresh mint
                            Color(hex: "E8A890").opacity(0.75),  // Peach coral
                            Color(hex: "E8C55A").opacity(0.80)   // Back to gold
                        ],
                        center: .center
                    )
                )

            // Inner luminous fill for density with warmth
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.45),
                            Color(hex: "E8C55A").opacity(0.4),
                            Color(hex: "CBA972").opacity(0.3)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.35),
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )

            // Soft shell edge - blurred for 3D glass effect
            Circle()
                .stroke(Color.white.opacity(0.7), lineWidth: 2.5)
                .blur(radius: 1.5)

            // Inner highlight for glass sphere effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.6),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.25
                    )
                )
                .frame(width: size * 0.5, height: size * 0.5)
                .offset(x: -size * 0.1, y: -size * 0.1)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(hex: "E8C55A").opacity(0.35), radius: 6, x: 0, y: 2)
    }

    // Frozen Chore: Solid matte bead - high opacity, minimal glow
    @ViewBuilder
    private func createFrozenChoreBubbleView(size: CGFloat, colorHexes: [String]) -> some View {
        ZStack {
            // Solid matte fill - high opacity
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: colorHexes[0]).opacity(0.85),
                            Color(hex: colorHexes[1]).opacity(0.75),
                            Color(hex: colorHexes[2]).opacity(0.65)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )

            // Hard shell edge
            Circle()
                .stroke(Color.white.opacity(0.75), lineWidth: 2.5)

            // Small highlight for bead effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.45),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.2
                    )
                )
                .frame(width: size * 0.4, height: size * 0.4)
                .offset(x: -size * 0.12, y: -size * 0.12)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(hex: colorHexes[1]).opacity(0.2), radius: 3, x: 0, y: 1)
    }

    // Fallback for iOS < 16
    private func renderCoreBubbleFallback(size: CGFloat) -> SKTexture? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { _ in
            let colors = [
                UIColor(Color(hex: "FFD700")),
                UIColor(Color(hex: "FFA500")),
                UIColor(Color(hex: "FFB6C1"))
            ]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors.map { $0.cgColor } as CFArray,
                                     locations: [0.0, 0.5, 1.0])!
            UIGraphicsGetCurrentContext()?.drawRadialGradient(gradient,
                                                             startCenter: CGPoint(x: size/2, y: size/2),
                                                             startRadius: 0,
                                                             endCenter: CGPoint(x: size/2, y: size/2),
                                                             endRadius: size/2,
                                                             options: [])
        }
        return SKTexture(image: image)
    }

    private func renderChoreBubbleFallback(size: CGFloat, colors: [String]) -> SKTexture? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { _ in
            let uiColors = colors.map { UIColor(Color(hex: $0)) }
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: uiColors.map { $0.cgColor } as CFArray,
                                     locations: [0.0, 0.5, 1.0])!
            UIGraphicsGetCurrentContext()?.drawRadialGradient(gradient,
                                                             startCenter: CGPoint(x: size/2, y: size/2),
                                                             startRadius: 0,
                                                             endCenter: CGPoint(x: size/2, y: size/2),
                                                             endRadius: size/2,
                                                             options: [])
        }
        return SKTexture(image: image)
    }

    private func createBubbleSprite(texture: SKTexture?, size: CGFloat) {
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = CGSize(width: size, height: size)
        sprite.zPosition = 0
        self.addChild(sprite)
        self.bubbleSprite = sprite

        // ONLY add breathing animation for ALIVE bubbles
        // Frozen bubbles are completely static - no animation at all
        if !isFrozen {
            addBubblePulseAnimation(to: sprite)
        }
        // Frozen bubbles: no animation, no pulse, completely still
    }

    // MARK: - Animation (ALIVE bubbles only)
    private func addBubblePulseAnimation(to sprite: SKSpriteNode) {
        let scaleUp = SKAction.scale(to: 1.05, duration: 3.0)
        let scaleDown = SKAction.scale(to: 0.95, duration: 3.0)
        scaleUp.timingMode = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut

        let breathe = SKAction.sequence([scaleUp, scaleDown])
        sprite.run(SKAction.repeatForever(breathe), withKey: "breathe")
    }

    private func addRotationAnimation(to sprite: SKSpriteNode) {
        let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 12.0)
        sprite.run(SKAction.repeatForever(rotate), withKey: "rotate")
    }

    // MARK: - Physics Setup
    private func setupPhysicsBody(radius: CGFloat) {
        self.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        self.physicsBody?.isDynamic = true
        self.physicsBody?.mass = bubbleType == .core ? 1.5 : 0.8
        self.physicsBody?.friction = 0.0
        self.physicsBody?.restitution = 0.6
        self.physicsBody?.linearDamping = 5.0  // Increased from 4.0 for 50% slower movement
        self.physicsBody?.angularDamping = 0.8
        self.physicsBody?.allowsRotation = false
        self.physicsBody?.categoryBitMask = 1
        self.physicsBody?.contactTestBitMask = 1
        self.physicsBody?.collisionBitMask = 1

        // 50% slower initial velocity (reduced from -8...8 to -4...4)
        self.physicsBody?.velocity = CGVector(
            dx: CGFloat.random(in: -4...4),
            dy: CGFloat.random(in: -4...4)
        )
    }

    private func addTextLabel(radius: CGFloat) {
        let label = SKLabelNode(text: bubbleText)
        label.fontName = "HelveticaNeue-Medium"
        label.fontSize = bubbleType == .core ? 16 : 13
        label.fontColor = UIColor(Color(hex: "6B6B6B"))
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = radius * 1.6
        label.zPosition = 4

        self.addChild(label)
        self.textLabel = label
    }

    private func addBreathingAnimation() {
        // Additional subtle whole-node breathing (on top of sprite pulse)
        let scaleUp = SKAction.scale(to: 1.02, duration: Double.random(in: 4...6))
        let scaleDown = SKAction.scale(to: 1.0, duration: Double.random(in: 4...6))
        scaleUp.timingMode = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut
        let breathe = SKAction.sequence([scaleUp, scaleDown])
        self.run(SKAction.repeatForever(breathe), withKey: "nodeBreathing")
    }

    func burst(completion: @escaping () -> Void) {
        // Stop all animations
        self.removeAction(forKey: "nodeBreathing")
        bubbleSprite?.removeAction(forKey: "breathe")
        bubbleSprite?.removeAction(forKey: "rotate")
        colorWheelSprite?.removeAllActions()
        glowSprite?.removeAllActions()
        highlightSprite?.removeAllActions()

        let scale = SKAction.scale(to: 1.3, duration: 0.2)
        let fade = SKAction.fadeOut(withDuration: 0.2)
        let group = SKAction.group([scale, fade])

        self.run(group) {
            completion()
        }
    }
}

class BubbleScene: SKScene {
    var onBubbleTapped: ((UUID) -> Void)?
    var onBubbleFlung: ((UUID) -> Void)?
    var onBubbleLongPressed: ((UUID) -> Void)?  // Notify when bubble is long-pressed
    var onDragStateChanged: ((Bool) -> Void)?  // Notify when drag starts/ends
    var archivePosition: CGPoint = .zero
    var calendarPosition: CGPoint = .zero  // Left-top corner for snooze to tomorrow

    // Read-only mode for past dates (bubbles cannot be interacted with)
    var isReadOnly: Bool = false

    private var bubbleNodes: [UUID: BubbleNode] = [:]
    private var draggedBubble: BubbleNode?
    private var longPressTimer: Timer?
    private var longPressDetected: Bool = false
    private var dragStartPosition: CGPoint = .zero
    private var dragStartTime: TimeInterval = 0

    override init(size: CGSize) {
        super.init(size: size)
        self.backgroundColor = .clear
        self.scaleMode = .aspectFill
        setupPhysicsWorld()
        setupFloatingFields()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupPhysicsWorld() {
        physicsWorld.gravity = CGVector(dx: 0, dy: -0.05)  // Reduced by 50% for slower movement
        physicsWorld.speed = 0.75  // Reduce overall physics speed by 25%
    }

    private func setupFloatingFields() {
        // Reduce field strengths by 50% for slower movement
        let noiseField = SKFieldNode.noiseField(withSmoothness: 1.0, animationSpeed: 0.15)
        noiseField.strength = 0.075  // Reduced by 50% from 0.15
        noiseField.position = CGPoint(x: size.width / 2, y: size.height / 2)
        noiseField.region = SKRegion(size: CGSize(width: size.width * 2, height: size.height * 2))
        addChild(noiseField)

        let turbulenceField = SKFieldNode.turbulenceField(withSmoothness: 0.8, animationSpeed: 0.25)
        turbulenceField.strength = 0.04  // Reduced by 50% from 0.08
        turbulenceField.position = CGPoint(x: size.width / 2, y: size.height / 2)
        turbulenceField.region = SKRegion(size: CGSize(width: size.width * 2, height: size.height * 2))
        addChild(turbulenceField)

        // Screen edge as container - strict boundary with small inset for bubble radius
        let boundaryRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let insetBounds = boundaryRect.insetBy(dx: 20, dy: 20)  // Minimal inset to account for bubble size
        let boundary = SKPhysicsBody(edgeLoopFrom: insetBounds)
        boundary.friction = 0.0
        boundary.restitution = 0.6  // Slightly bouncy for natural container feel
        physicsBody = boundary

        // Add edge repulsion forces to keep bubbles comfortably within screen bounds
        addEdgeRepulsionFields()
    }

    private func addEdgeRepulsionFields() {
        // Create stronger repulsion fields to keep bubbles within screen container
        let edgeStrength: Float = 3.5  // Increased strength for better containment
        let edgeWidth: CGFloat = 100  // Slightly wider field

        // Left edge
        let leftField = SKFieldNode.radialGravityField()
        leftField.strength = -edgeStrength
        leftField.position = CGPoint(x: edgeWidth / 2, y: size.height / 2)
        leftField.region = SKRegion(size: CGSize(width: edgeWidth, height: size.height))
        addChild(leftField)

        // Right edge
        let rightField = SKFieldNode.radialGravityField()
        rightField.strength = -edgeStrength
        rightField.position = CGPoint(x: size.width - edgeWidth / 2, y: size.height / 2)
        rightField.region = SKRegion(size: CGSize(width: edgeWidth, height: size.height))
        addChild(rightField)

        // Top edge
        let topField = SKFieldNode.radialGravityField()
        topField.strength = -edgeStrength
        topField.position = CGPoint(x: size.width / 2, y: size.height - edgeWidth / 2)
        topField.region = SKRegion(size: CGSize(width: size.width, height: edgeWidth))
        addChild(topField)

        // Bottom edge
        let bottomField = SKFieldNode.radialGravityField()
        bottomField.strength = -edgeStrength
        bottomField.position = CGPoint(x: size.width / 2, y: edgeWidth / 2)
        bottomField.region = SKRegion(size: CGSize(width: size.width, height: edgeWidth))
        addChild(bottomField)
    }

    func addBubble(bubble: Bubble, at position: CGPoint? = nil, isStatic: Bool = false) {
        guard bubbleNodes[bubble.id] == nil else { return }

        let radius: CGFloat = bubble.type == .core ? 80 : 45
        let bubbleNode = BubbleNode(bubble: bubble, radius: radius, isStatic: isStatic || isReadOnly)

        if let pos = position {
            bubbleNode.position = pos
        } else {
            let skPosition = CGPoint(
                x: bubble.position.x * size.width,
                y: (1.0 - bubble.position.y) * size.height
            )
            bubbleNode.position = skPosition
        }

        bubbleNodes[bubble.id] = bubbleNode
        addChild(bubbleNode)

        // Only add repulsion field for dynamic bubbles
        if !isStatic && !isReadOnly {
            addRepulsionField(to: bubbleNode, radius: radius)
        }
    }

    func clearAllBubbles() {
        for (_, node) in bubbleNodes {
            node.removeFromParent()
        }
        bubbleNodes.removeAll()
    }

    func removeBubble(_ bubbleId: UUID, animated: Bool = true) {
        guard let node = bubbleNodes[bubbleId] else { return }

        if animated {
            node.burst {
                node.removeFromParent()
            }
        } else {
            node.removeFromParent()
        }

        bubbleNodes.removeValue(forKey: bubbleId)
    }

    func popBubble(id: UUID) {
        guard let bubbleNode = bubbleNodes[id] else { return }

        let bubblePos = bubbleNode.position
        let bubbleColor = bubbleNode.baseColor

        SoundManager.hapticMedium()
        SoundManager.shared.playBubblePop()

        bubbleNode.burst {
            bubbleNode.removeFromParent()
        }

        createDreamyFlowParticles(from: bubblePos, color: bubbleColor)
        bubbleNodes.removeValue(forKey: id)
    }

    private func addRepulsionField(to bubbleNode: BubbleNode, radius: CGFloat) {
        let repulsionField = SKFieldNode.radialGravityField()
        repulsionField.strength = -1.5
        repulsionField.falloff = 2.0
        repulsionField.region = SKRegion(radius: Float(radius * 2.0))
        repulsionField.minimumRadius = Float(radius * 1.2)
        bubbleNode.addChild(repulsionField)
    }

    private func createDreamyFlowParticles(from startPos: CGPoint, color: UIColor) {
        let particleCount = 75  // Increased by 3x (from 25 to 75)
        // Flow to bottom-right corner
        let targetPoint = CGPoint(x: size.width - 30, y: size.height - 30)

        for i in 0..<particleCount {
            let delay = TimeInterval(i) * 0.015  // 加快释放速度

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 6...12))  // Slightly larger particles
                particle.fillColor = color
                particle.strokeColor = color.withAlphaComponent(0.8)
                particle.lineWidth = 1.5
                particle.glowWidth = 5
                particle.alpha = 0.95
                particle.position = startPos

                self.addChild(particle)

                let randomOffsetX = CGFloat.random(in: -20...20)
                let randomOffsetY = CGFloat.random(in: -20...20)
                let finalTarget = CGPoint(
                    x: targetPoint.x + randomOffsetX,
                    y: targetPoint.y + randomOffsetY
                )

                let path = self.createArcPath(from: startPos, to: finalTarget)
                let duration = TimeInterval.random(in: 0.6...1.2)

                let followPath = SKAction.follow(path, asOffset: false, orientToPath: false, duration: duration)
                followPath.timingMode = .easeOut

                let fadeOut = SKAction.fadeOut(withDuration: duration)
                let scaleDown = SKAction.scale(to: 0.2, duration: duration)

                let group = SKAction.group([followPath, fadeOut, scaleDown])

                particle.run(group) {
                    particle.removeFromParent()
                }
            }
        }
    }

    private func createArcPath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)

        let midX = (start.x + end.x) / 2
        let midY = (start.y + end.y) / 2

        let offsetX = CGFloat.random(in: -50...50)
        let offsetY: CGFloat = -100
        let controlPoint = CGPoint(x: midX + offsetX, y: midY + offsetY)

        path.addQuadCurve(to: end, control: controlPoint)

        return path
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Ignore touches in read-only mode
        guard !isReadOnly else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        let touchedNodes = nodes(at: location)
        if let bubbleNode = touchedNodes.compactMap({ $0 as? BubbleNode }).first {
            // Skip static bubbles
            guard !bubbleNode.isFrozen else { return }

            draggedBubble = bubbleNode
            dragStartPosition = location
            dragStartTime = Date().timeIntervalSince1970
            longPressDetected = false

            bubbleNode.physicsBody?.isDynamic = false
            SoundManager.hapticLight()

            // Start long press timer for core bubbles only
            if bubbleNode.bubbleType == .core {
                longPressTimer?.invalidate()
                longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
                    guard let self = self, let bubble = self.draggedBubble else { return }
                    self.longPressDetected = true
                    SoundManager.hapticMedium()
                    self.onBubbleLongPressed?(bubble.bubbleId)
                }
            }

            // Notify that dragging started
            onDragStateChanged?(true)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let bubble = draggedBubble else { return }

        let location = touch.location(in: self)

        // Cancel long press if movement is detected
        let dx = location.x - dragStartPosition.x
        let dy = location.y - dragStartPosition.y
        let distance = sqrt(dx * dx + dy * dy)
        if distance > 10 {
            longPressTimer?.invalidate()
            longPressTimer = nil
        }

        bubble.position = location
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let bubble = draggedBubble else { return }

        // Cancel long press timer
        longPressTimer?.invalidate()
        longPressTimer = nil

        let endPosition = touch.location(in: self)
        let endTime = Date().timeIntervalSince1970

        let dx = endPosition.x - dragStartPosition.x
        let dy = endPosition.y - dragStartPosition.y
        let distance = sqrt(dx * dx + dy * dy)
        let duration = endTime - dragStartTime

        bubble.physicsBody?.isDynamic = true

        // If long press was detected, don't process tap or drag
        if longPressDetected {
            onDragStateChanged?(false)
            draggedBubble = nil
            return
        }

        // Check if bubble was dragged to calendar icon (top-left corner) for snooze to tomorrow
        let distanceToCalendar = sqrt(pow(endPosition.x - calendarPosition.x, 2) +
                                     pow(endPosition.y - calendarPosition.y, 2))
        let isNearCalendar = distanceToCalendar < 100  // 100pt radius around calendar icon

        if isNearCalendar {
            // Bubble dragged to calendar - snooze to tomorrow
            SoundManager.hapticMedium()
            onBubbleFlung?(bubble.bubbleId)

            // Gentle animation toward calendar icon
            let impulse = CGVector(
                dx: (calendarPosition.x - endPosition.x) * 0.3,
                dy: (calendarPosition.y - endPosition.y) * 0.3
            )
            bubble.physicsBody?.applyImpulse(impulse)

        } else if distance < 20 && duration < 0.3 {
            // Quick tap - pop bubble
            SoundManager.hapticMedium()
            SoundManager.shared.playBubblePop()
            onBubbleTapped?(bubble.bubbleId)
        }

        // Notify that dragging ended
        onDragStateChanged?(false)
        draggedBubble = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let bubble = draggedBubble {
            bubble.physicsBody?.isDynamic = true
        }
        // Notify that dragging ended
        onDragStateChanged?(false)
        draggedBubble = nil
    }
}

struct BubbleSceneView: UIViewRepresentable {
    let scene: BubbleScene

    func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.backgroundColor = .clear
        skView.allowsTransparency = true
        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.presentScene(scene)
        return skView
    }

    func updateUIView(_ uiView: SKView, context: Context) {}
}

// MARK: - ========== 3. AI 对话（保留原版）==========
struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var inputText = ""
    @State private var isThinking = false
    @State private var dragOffset: CGFloat = 0
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            // Background - warm beige, extends to edges
            LinearGradient(
                colors: [Color(hex: "FFF9E6"), Color(hex: "FDFCF8")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Navigation Header
                chatNavigationHeader

                Divider()
                    .background(Color(hex: "E0DCD4"))

                // MARK: - Message List with safeAreaInset for Input Bar
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(appState.chatMessages) { message in
                                messageView(for: message)
                            }

                            // Typing Indicator
                            if isThinking {
                                TypingIndicatorRow()
                                    .id("typing")
                            }

                            // Bottom anchor for scrolling
                            Color.clear
                                .frame(height: 1)
                                .id("bottomAnchor")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }
                    .defaultScrollAnchor(.bottom)
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: appState.chatMessages.count) { _, _ in
                        scrollToBottom(proxy: scrollProxy)
                    }
                    .onChange(of: isThinking) { _, _ in
                        scrollToBottom(proxy: scrollProxy)
                    }
                    .safeAreaInset(edge: .bottom) {
                        // Input bar automatically rides on top of keyboard
                        chatInputBar
                    }
                }
            }
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow downward drag when keyboard is hidden
                    if !isInputFocused && value.translation.height > 0 {
                        dragOffset = value.translation.height * 0.5
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 && !isInputFocused {
                        dismissChat()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            // Initialize welcome message if chat history is empty
            appState.initializeWelcomeMessageIfNeeded(modelContext: modelContext)
            // Load chat messages from SwiftData
            appState.reloadChatMessages(from: modelContext)

            // Auto-request graduation letter if needed
            if appState.shouldAutoRequestGraduationLetter {
                appState.shouldAutoRequestGraduationLetter = false
                requestGraduationLetter()
            }
        }
    }

    // MARK: - Navigation Header
    private var chatNavigationHeader: some View {
        HStack {
            // Drag handle hint
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(hex: "CCCCCC"))
                .frame(width: 36, height: 5)
                .opacity(0.6)

            Spacer()

            // Title
            Text("Lumi")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "5C5C5C"))

            Spacer()

            // Done button - standard iOS style
            Button(action: dismissChat) {
                Text("完成")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "5C5C5C"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "FFF9E6").opacity(0.95))
    }

    // MARK: - Input Bar (iMessage Style)
    private var chatInputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color(hex: "E0DCD4"))

            HStack(spacing: 10) {
                // Capsule text field
                TextField("说说你的想法...", text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .overlay(
                                Capsule()
                                    .stroke(Color(hex: "E0DCD4"), lineWidth: 1)
                            )
                    )
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            sendMessage()
                        }
                    }

                // Send button - SF Symbol arrow.up.circle.fill
                Button(action: {
                    sendMessage()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color(hex: "CBA972").opacity(0.4)
                                : Color(hex: "CBA972")
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Message View Builder
    @ViewBuilder
    private func messageView(for message: ChatMessage) -> some View {
        if !message.isUser, let blueprint = extractBlueprintFromMessage(message.content) {
            // Successfully parsed blueprint - show contract card
            ContractCard(blueprint: blueprint) {
                sendConfirmation()
            }
            .id(message.id)
        } else if !message.isUser && isDraftPreview(message.content) {
            // Draft preview (before JSON generation)
            DraftPreviewCard(content: message.content)
                .id(message.id)
        } else if !message.isUser && containsJSONCodeBlock(message.content) {
            // JSON detected - check if parsing failed
            let parseResult = JSONParser.extractGoalBlueprintWithResult(from: message.content)
            switch parseResult {
            case .success(let blueprint):
                ContractCard(blueprint: blueprint) {
                    sendConfirmation()
                }
                .id(message.id)
            case .failure(let errorMsg):
                ContractErrorCard(errorMessage: errorMsg) {
                    inputText = "请重新生成愿景契约"
                    sendMessage()
                }
                .id(message.id)
            }
        } else {
            // Regular message
            ChatMessageRow(message: message)
                .id(message.id)
        }
    }

    // MARK: - Helper Functions
    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                if isThinking {
                    proxy.scrollTo("typing", anchor: .bottom)
                } else {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
        }
    }

    private func dismissChat() {
        isInputFocused = false
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = UIScreen.main.bounds.height
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
            appState.closeChat()

            // If we just showed a graduation letter (witness phase), reset to onboarding
            if self.appState.currentPhase == .witness {
                print("ChatView: Graduation letter dismissed - resetting to onboarding")
                self.appState.resetToOnboarding(modelContext: self.modelContext)
            }
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        let messageText = inputText
        inputText = ""

        // Show thinking indicator
        isThinking = true

        // Send to AI API with dynamic context
        Task {
            do {
                // Gather context data
                let goalName = appState.currentGoalName
                let todayTask = appState.getTodayTask()
                let streakDays = appState.calculateStreakDays()

                // Build context string with restart flag if applicable
                var contextString = ""
                if appState.currentPhase == .onboarding && appState.isRestartingAfterCompletion {
                    contextString = "User just finished a goal and is restarting. Skip the long introduction and welcome them back warmly."
                    // Clear the flag after using it once
                    appState.isRestartingAfterCompletion = false
                }

                let response = try await ChatService.shared.sendMessage(
                    userText: messageText,
                    phase: appState.currentPhase,
                    goalName: goalName,
                    todayTask: todayTask,
                    streakDays: streakDays,
                    context: contextString,
                    modelContext: modelContext
                )

                await MainActor.run {
                    isThinking = false

                    // INTERCEPT: Check for action commands in the response BEFORE showing to user
                    if let actionResponse = JSONParser.extractAction(from: response.text) {
                        handleActionCommand(actionResponse)
                    }

                    // Reload chat messages from SwiftData
                    appState.reloadChatMessages(from: modelContext)

                    // If a new goal was created, update app state and refresh HomeView
                    if let goal = response.createdGoal {
                        appState.currentGoalName = goal.title
                        appState.currentPhase = .companion // Move to companion phase
                        print("ChatView: New goal created - '\(goal.title)'")

                        // Post notification to refresh HomeView with new goal data
                        NotificationCenter.default.post(name: .goalDataDidChange, object: nil)
                    }

                    // Handle extracted JSON if present (for legacy support)
                    if response.hasJSON {
                        handleAIResponse(response)
                    }
                }
            } catch {
                await MainActor.run {
                    isThinking = false
                    // Show error message or fallback
                    let errorMessage = "抱歉，我暂时无法回应。请稍后再试。"
                    let errorChatMessage = ChatMessage(content: errorMessage, isUser: false)
                    modelContext.insert(errorChatMessage)
                    try? modelContext.save()
                    appState.reloadChatMessages(from: modelContext)
                    print("ChatService error: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Handle structured JSON responses from AI
    private func handleAIResponse(_ response: ChatResponse) {
        // Handle different JSON response types
        if let action = response.action {
            switch action {
            case "reschedule":
                // Handle bubble reschedule
                print("Reschedule action detected")
                // TODO: Implement reschedule logic

            case "trigger_phase_3_completion":
                // Trigger B: Early Finish - AI detected goal completion
                print("AI triggered goal completion (early finish)")
                appState.triggerGoalCompletion()

            default:
                break
            }
        }

        if let bubbles = response.bubbles {
            // Handle new bubbles from planning
            print("Received \(bubbles.count) bubbles from AI")
            // TODO: Implement bubble creation logic
        }

        if let crystal = response.crystal {
            // Handle crystal creation
            print("Received crystal data: \(crystal)")
            // TODO: Implement crystal creation logic
        }
    }

    /// Handle action commands extracted from AI response
    private func handleActionCommand(_ actionResponse: AIActionResponse) {
        print("ChatView: Handling action command: \(actionResponse.action)")

        switch actionResponse.action {
        case "trigger_phase_3_completion":
            // User completed the goal early!
            print("ChatView: 🎉 Triggering Phase 3 completion celebration")

            // 1. Mark remaining tasks as done and finish goal (FIRST, before animations)
            finishCurrentGoal()

            // 2. Close chat view first to show the full celebration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.dismissChat()
            }

            // 3. Show confetti + envelope celebration (after chat closes)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.appState.showCelebration()
            }

            // 4. Set flag for graduation letter to be requested when envelope is opened
            // (handled by triggerGoalCompletion() inside showCelebration())

        case "update_today_task":
            // User requested task adjustment
            if let newLabel = actionResponse.newTaskLabel {
                print("ChatView: Updating today's task to: \(newLabel)")
                updateTodayTask(newLabel: newLabel)
            }

        case "reset_goal":
            // User wants to start over
            print("ChatView: Resetting current goal")
            resetCurrentGoal()

        default:
            print("ChatView: Unknown action: \(actionResponse.action)")
        }
    }

    /// Finish the current goal - mark all remaining tasks as done and archive it
    private func finishCurrentGoal() {
        // Fetch active goal (not archived, not completed)
        var descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { !$0.isArchived && !$0.isCompleted },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let activeGoal = try? modelContext.fetch(descriptor).first else {
            print("ChatView: No active goal to finish")
            return
        }

        // Mark all remaining tasks as completed
        for task in activeGoal.dailyTasks where !task.isCompleted {
            task.isCompleted = true
        }

        // Mark goal as completed AND archived
        activeGoal.isCompleted = true
        activeGoal.isArchived = true

        // Save changes
        do {
            try modelContext.save()
            print("ChatView: ✅ Goal '\(activeGoal.title)' marked as completed and archived")
        } catch {
            print("ChatView: ❌ Failed to save goal completion: \(error)")
        }

        // Update app state (keep in witness phase until letter is shown)
        appState.currentPhase = .witness

        // Post notification for UI updates
        NotificationCenter.default.post(name: .goalDataDidChange, object: nil)
    }

    /// Update today's task with a new label
    private func updateTodayTask(newLabel: String) {
        // Fetch active goal (not archived)
        var descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { !$0.isArchived && !$0.isCompleted },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let activeGoal = try? modelContext.fetch(descriptor).first,
              let todayTask = activeGoal.getTaskForDate(Date()) else {
            print("ChatView: No active goal or today's task to update")
            return
        }

        // Update the task label
        todayTask.label = newLabel

        // Save changes
        do {
            try modelContext.save()
            print("ChatView: ✅ Updated today's task to: \(newLabel)")
        } catch {
            print("ChatView: ❌ Failed to update today's task: \(error)")
        }

        // Post notification for UI updates
        NotificationCenter.default.post(name: .goalDataDidChange, object: nil)
    }

    /// Reset the current goal (delete it and return to onboarding)
    private func resetCurrentGoal() {
        // Fetch active goal (not archived)
        var descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { !$0.isArchived && !$0.isCompleted },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let activeGoal = try? modelContext.fetch(descriptor).first else {
            print("ChatView: No active goal to reset")
            return
        }

        // Delete the goal
        modelContext.delete(activeGoal)

        // Save changes
        do {
            try modelContext.save()
            print("ChatView: ✅ Goal deleted, returning to onboarding")
        } catch {
            print("ChatView: ❌ Failed to delete goal: \(error)")
        }

        // Reset app state
        appState.currentGoalName = nil
        appState.currentPhase = .onboarding
        appState.isRestartingAfterCompletion = true  // Set restart flag for context-aware greeting

        // Post notification for UI updates
        NotificationCenter.default.post(name: .goalDataDidChange, object: nil)
    }

    /// Extract GoalBlueprint from message content
    private func extractBlueprintFromMessage(_ content: String) -> GoalBlueprint? {
        return JSONParser.extractGoalBlueprint(from: content)
    }

    /// Check if message is a draft preview (contains draft markers)
    private func isDraftPreview(_ content: String) -> Bool {
        let draftMarkers = [
            "【微光契约草案】",
            "【愿景契约草案】",
            "愿景契约草案",
            "微光契约草案",
            "草案如下",
            "以下是草案"
        ]

        for marker in draftMarkers {
            if content.contains(marker) {
                return true
            }
        }
        return false
    }

    /// Check if message contains JSON code block
    private func containsJSONCodeBlock(_ content: String) -> Bool {
        // Use the robust JSONParser method
        return JSONParser.containsJSON(content)
    }

    /// Send confirmation message
    private func sendConfirmation() {
        inputText = "确认"
        sendMessage()
    }

    /// Auto-request graduation letter (hidden from user)
    private func requestGraduationLetter() {
        // Show thinking indicator
        isThinking = true

        Task {
            do {
                // Gather context data
                let goalName = appState.currentGoalName
                let todayTask = appState.getTodayTask()
                let streakDays = appState.calculateStreakDays()

                // Send hidden request for graduation letter
                let response = try await ChatService.shared.sendMessage(
                    userText: "请为我写一封毕业信", // Hidden trigger message
                    phase: .witness,
                    goalName: goalName,
                    todayTask: todayTask,
                    streakDays: streakDays,
                    context: "用户完成了全部目标任务，请生成毕业信",
                    modelContext: modelContext
                )

                await MainActor.run {
                    isThinking = false

                    // Reload chat messages from SwiftData
                    appState.reloadChatMessages(from: modelContext)
                }
            } catch {
                await MainActor.run {
                    isThinking = false
                    let errorMessage = "抱歉，暂时无法生成毕业信。请稍后再试。"
                    let errorChatMessage = ChatMessage(content: errorMessage, isUser: false)
                    modelContext.insert(errorChatMessage)
                    try? modelContext.save()
                    appState.reloadChatMessages(from: modelContext)
                    print("Graduation letter error: \(error.localizedDescription)")
                }
            }
        }
    }

}

// MARK: - Chat Message Row
struct ChatMessageRow: View {
    let message: ChatMessage

    /// Get cleaned display text - strips JSON from AI messages
    private var displayContent: String {
        if message.isUser {
            return message.content
        } else {
            // Strip JSON from AI responses for clean display
            return JSONParser.stripJSON(from: message.content)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
            } else {
                // AI Avatar
                LumiMiniAvatar(isThinking: false, size: 36)
            }

            // Message Bubble - use cleaned display content
            Text(displayContent)
                .font(.system(size: 15))
                .foregroundColor(message.isUser ? .white : Color(hex: "3C3C3C"))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(message.isUser ? Color(hex: "5C5C5C") : Color.white.opacity(0.9))
                )

            if message.isUser {
                // User doesn't need avatar
            } else {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Typing Indicator Row
struct TypingIndicatorRow: View {
    @State private var dotAnimation = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Pulsing Avatar when thinking
            LumiMiniAvatar(isThinking: true, size: 36)

            // Typing dots bubble
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color(hex: "8B8B8B"))
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotAnimation ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                            value: dotAnimation
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.9))
            )
            .onAppear { dotAnimation = true }

            Spacer(minLength: 60)
        }
    }
}

// MARK: - Lumi Mini Avatar (Personified Light Ball)
struct LumiMiniAvatar: View {
    let isThinking: Bool
    let size: CGFloat

    @State private var breatheScale: CGFloat = 1.0
    @State private var blinkAnimation = false

    private var eyeSize: CGFloat { size * 0.12 }
    private var eyeSpacing: CGFloat { size * 0.25 }
    private var pupilSize: CGFloat { size * 0.08 }

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "FFD700").opacity(isThinking ? 0.5 : 0.3),
                            Color(hex: "CBA972").opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size * 1.3, height: size * 1.3)
                .scaleEffect(breatheScale)

            // Main bubble body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.95),
                            Color(hex: "ADD8E6").opacity(0.5),
                            Color(hex: "CBA972").opacity(0.35)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)
                .scaleEffect(breatheScale)
                .shadow(color: Color(hex: "CBA972").opacity(0.3), radius: 4, x: 0, y: 2)

            // Face - Eyes
            HStack(spacing: eyeSpacing) {
                MiniEyeView(isBlinking: blinkAnimation, eyeSize: eyeSize, pupilSize: pupilSize)
                MiniEyeView(isBlinking: blinkAnimation, eyeSize: eyeSize, pupilSize: pupilSize)
            }
            .offset(y: -size * 0.05)

            // Subtle smile - centered
            SmilePath(width: size * 0.25, curveHeight: size * 0.08)
                .stroke(Color(hex: "CBA972").opacity(0.6), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: size * 0.25, height: size * 0.1)
                .offset(y: size * 0.15)
        }
        .frame(width: size, height: size)
        .onAppear {
            startBreathing()
            startBlinking()
        }
        .onChange(of: isThinking) { thinking in
            updateBreathingSpeed(thinking: thinking)
        }
    }

    private func startBreathing() {
        withAnimation(.easeInOut(duration: isThinking ? 0.6 : 2.0).repeatForever(autoreverses: true)) {
            breatheScale = isThinking ? 1.08 : 1.04
        }
    }

    private func updateBreathingSpeed(thinking: Bool) {
        withAnimation(.easeInOut(duration: thinking ? 0.6 : 2.0).repeatForever(autoreverses: true)) {
            breatheScale = thinking ? 1.08 : 1.04
        }
    }

    private func startBlinking() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2...4)) {
            withAnimation(.easeInOut(duration: 0.1)) {
                blinkAnimation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    blinkAnimation = false
                }
                startBlinking()
            }
        }
    }
}

// MARK: - Mini Eye View
struct MiniEyeView: View {
    let isBlinking: Bool
    let eyeSize: CGFloat
    let pupilSize: CGFloat

    var body: some View {
        ZStack {
            // Eye white
            Capsule()
                .fill(Color.white.opacity(0.95))
                .frame(width: eyeSize, height: isBlinking ? eyeSize * 0.2 : eyeSize * 1.4)
                .shadow(color: Color(hex: "ADD8E6").opacity(0.3), radius: 1)

            // Pupil
            if !isBlinking {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "4682B4"), Color(hex: "1E3A5F")],
                            center: .center,
                            startRadius: 0,
                            endRadius: pupilSize
                        )
                    )
                    .frame(width: pupilSize, height: pupilSize)

                // Sparkle
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: pupilSize * 0.35, height: pupilSize * 0.35)
                    .offset(x: -pupilSize * 0.2, y: -pupilSize * 0.2)
            }
        }
        .animation(.easeInOut(duration: 0.1), value: isBlinking)
    }
}

// MARK: - Smile Path Shape (Centered)
struct SmilePath: Shape {
    let width: CGFloat
    let curveHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerX = rect.midX
        let centerY = rect.midY
        path.move(to: CGPoint(x: centerX - width/2, y: centerY))
        path.addQuadCurve(
            to: CGPoint(x: centerX + width/2, y: centerY),
            control: CGPoint(x: centerX, y: centerY + curveHeight)
        )
        return path
    }
}

// MARK: - Lumi Pet Avatar (Home Button - Larger Animated Avatar)
struct LumiPetAvatar: View {
    @State private var breatheScale: CGFloat = 1.0
    @State private var blinkAnimation = false
    @State private var floatOffset: CGFloat = 0

    private let size: CGFloat = 56

    var body: some View {
        ZStack {
            // Outer breathing glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "FFD700").opacity(0.4),
                            Color(hex: "CBA972").opacity(0.25),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)
                .scaleEffect(breatheScale)

            // Main bubble body with subtle iridescence
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.95),
                            Color(hex: "ADD8E6").opacity(0.55),
                            Color(hex: "CBA972").opacity(0.4)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)
                .scaleEffect(breatheScale)
                .shadow(color: Color(hex: "FFD700").opacity(0.5), radius: 12, x: 0, y: 4)
                .shadow(color: Color(hex: "CBA972").opacity(0.3), radius: 20, x: 0, y: 6)

            // Highlight shine
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.6), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.8, height: size * 0.8)
                .offset(x: -size * 0.1, y: -size * 0.1)
                .blur(radius: 4)

            // Face - Eyes
            HStack(spacing: size * 0.22) {
                PetEyeView(isBlinking: blinkAnimation, size: size)
                PetEyeView(isBlinking: blinkAnimation, size: size)
            }
            .offset(y: -size * 0.03)

            // Happy smile - centered
            SmilePath(width: size * 0.28, curveHeight: size * 0.1)
                .stroke(Color(hex: "CBA972").opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: size * 0.28, height: size * 0.12)
            .offset(y: size * 0.18)
        }
        .offset(y: floatOffset)
        .onAppear {
            startBreathing()
            startBlinking()
            startFloating()
        }
    }

    private func startBreathing() {
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            breatheScale = 1.06
        }
    }

    private func startFloating() {
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            floatOffset = -4
        }
    }

    private func startBlinking() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2.5...4.5)) {
            withAnimation(.easeInOut(duration: 0.12)) {
                blinkAnimation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.12)) {
                    blinkAnimation = false
                }
                startBlinking()
            }
        }
    }
}

// MARK: - Pet Eye View (for Home Button Avatar)
struct PetEyeView: View {
    let isBlinking: Bool
    let size: CGFloat

    private var eyeWidth: CGFloat { size * 0.13 }
    private var eyeHeight: CGFloat { size * 0.18 }
    private var pupilSize: CGFloat { size * 0.09 }

    var body: some View {
        ZStack {
            // Eye white
            Capsule()
                .fill(Color.white.opacity(0.95))
                .frame(width: eyeWidth, height: isBlinking ? eyeWidth * 0.25 : eyeHeight)
                .shadow(color: Color(hex: "ADD8E6").opacity(0.4), radius: 2)

            // Pupil
            if !isBlinking {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "4682B4"), Color(hex: "1E3A5F")],
                            center: .center,
                            startRadius: 0,
                            endRadius: pupilSize
                        )
                    )
                    .frame(width: pupilSize, height: pupilSize)

                // Sparkle highlight
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: pupilSize * 0.4, height: pupilSize * 0.4)
                    .offset(x: -pupilSize * 0.2, y: -pupilSize * 0.2)
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isBlinking)
    }
}

// MARK: - ========== AI Bubble Avatar Component ==========
struct AIBubbleAvatar: View {
    let isThinking: Bool
    let isSpeaking: Bool

    @State private var breatheScale: CGFloat = 1.0
    @State private var blinkAnimation = false
    @State private var mouthAnimation = false
    @State private var trembleOffset: CGSize = .zero
    @State private var brightnessBoost: Double = 0

    // Timer for speaking vibration
    @State private var speakingTimer: Timer?

    var body: some View {
        ZStack {
            // Bubble body with gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.9),
                            Color(hex: "ADD8E6").opacity(0.6),
                            Color(hex: "CBA972").opacity(0.4)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 90
                    )
                )
                .scaleEffect(breatheScale)
                .brightness(brightnessBoost)

            // Outer glow for wisdom feel - brighter when thinking
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "FFD700").opacity(isThinking ? 0.7 : 0.4),
                            Color(hex: "ADD8E6").opacity(isThinking ? 0.5 : 0.3),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isThinking ? 4 : 3
                )
                .blur(radius: isThinking ? 6 : 4)

            // Face elements
            VStack(spacing: 15) {
                // Eyes
                HStack(spacing: 28) {
                    // Left eye
                    EyeView(isBlinking: blinkAnimation, isThinking: isThinking)

                    // Right eye
                    EyeView(isBlinking: blinkAnimation, isThinking: isThinking)
                }
                .padding(.top, 10)

                // Mouth
                MouthView(isThinking: isThinking, isSpeaking: isSpeaking, animation: mouthAnimation)
                    .padding(.top, 5)
            }
        }
        .offset(trembleOffset)
        .onAppear {
            breatheScale = 1.05
            startBreathing()
            startBlinking()
            mouthAnimation = true
        }
        .onChange(of: isThinking) { thinking in
            updateBreathingAnimation(thinking: thinking)
        }
        .onChange(of: isSpeaking) { speaking in
            updateSpeakingAnimation(speaking: speaking)
        }
    }

    private func startBreathing() {
        // Normal slow breathing
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            breatheScale = 1.05
        }
    }

    private func updateBreathingAnimation(thinking: Bool) {
        if thinking {
            // Faster breathing when thinking
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                breatheScale = 1.08
                brightnessBoost = 0.1
            }
        } else {
            // Return to normal breathing
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breatheScale = 1.05
                brightnessBoost = 0
            }
        }
    }

    private func updateSpeakingAnimation(speaking: Bool) {
        speakingTimer?.invalidate()

        if speaking {
            // Start gentle trembling/vibration
            speakingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                withAnimation(.linear(duration: 0.05)) {
                    trembleOffset = CGSize(
                        width: CGFloat.random(in: -1.5...1.5),
                        height: CGFloat.random(in: -1.5...1.5)
                    )
                }
            }
        } else {
            // Stop trembling
            withAnimation(.easeOut(duration: 0.1)) {
                trembleOffset = .zero
            }
        }
    }

    private func startBlinking() {
        // Blink every 3-5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 3...5)) {
            withAnimation(.easeInOut(duration: 0.15)) {
                blinkAnimation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    blinkAnimation = false
                }
                startBlinking() // Schedule next blink
            }
        }
    }
}

// MARK: - Eye Component
struct EyeView: View {
    let isBlinking: Bool
    let isThinking: Bool

    var body: some View {
        ZStack {
            // Eye white
            Capsule()
                .fill(Color.white.opacity(0.9))
                .frame(width: 16, height: isBlinking ? 3 : 22)
                .shadow(color: Color(hex: "ADD8E6").opacity(0.3), radius: 2)

            // Pupil
            if !isBlinking {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "4682B4"),
                                Color(hex: "1E3A5F")
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 6
                        )
                    )
                    .frame(width: 10, height: 10)
                    .offset(y: isThinking ? -2 : 0) // Look up when thinking
                    .animation(.easeInOut(duration: 0.3), value: isThinking)

                // Sparkle in eye
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 3, height: 3)
                    .offset(x: -2, y: -2)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isBlinking)
    }
}

// MARK: - Mouth Component
struct MouthView: View {
    let isThinking: Bool
    let isSpeaking: Bool
    let animation: Bool

    @State private var speakingMouthHeight: CGFloat = 8

    var body: some View {
        Group {
            if isThinking {
                // Thinking mouth - small 'o' shape
                Circle()
                    .stroke(Color(hex: "CBA972").opacity(0.7), lineWidth: 2)
                    .frame(width: 12, height: 12)
                    .scaleEffect(animation ? 1.0 : 0.9)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animation)
            } else if isSpeaking {
                // Speaking mouth - animated open/close
                Capsule()
                    .fill(Color(hex: "CBA972").opacity(0.6))
                    .frame(width: 18, height: speakingMouthHeight)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.15).repeatForever(autoreverses: true)) {
                            speakingMouthHeight = 14
                        }
                    }
                    .onDisappear {
                        speakingMouthHeight = 8
                    }
            } else {
                // Happy smile
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addQuadCurve(
                        to: CGPoint(x: 30, y: 0),
                        control: CGPoint(x: 15, y: 8)
                    )
                }
                .stroke(Color(hex: "CBA972").opacity(0.8), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 30, height: 10)
            }
        }
    }
}

// MARK: - ========== 4. 日历（升级版）==========

/// Calendar day data structure
struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let dayNumber: Int
    let isCurrentMonth: Bool
    let isToday: Bool
    let isPast: Bool
    let isFuture: Bool
    let completionType: DayCompletionType
    let hasBubbles: Bool
}

struct CalendarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Namespace private var calendarAnimation

    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    @State private var calendarDays: [CalendarDay] = []
    @State private var dragOffset: CGFloat = 0
    @State private var selectedDayForTransition: CalendarDay?

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "2C2C3E"), Color(hex: "1C1C2E")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            StarField()

            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                // Header: Year Month (center aligned)
                Text(monthYearString)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: "CBA972"))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)

                // Weekdays row
                HStack(spacing: 0) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                // Calendar grid
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(calendarDays) { day in
                        if day.isCurrentMonth {
                            CalendarDayCell(
                                day: day,
                                namespace: calendarAnimation,
                                isSelected: selectedDayForTransition?.id == day.id,
                                onLongPress: {
                                    showDayTaskDetail(day)
                                }
                            )
                            .onTapGesture {
                                handleDayTap(day)
                            }
                        } else {
                            // Empty placeholder for days outside current month
                            Color.clear
                                .frame(width: 50, height: 50)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .offset(x: dragOffset)

                Spacer()

                // Bottom Quote with Typewriter Effect
                CalendarQuoteView()
                    .padding(.bottom, 16)

                // Back button hint
                HStack {
                    Image(systemName: "chevron.down")
                        .foregroundColor(Color.white.opacity(0.4))
                    Text("下滑返回今天")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                .padding(.bottom, 30)
            }

            // AI Chat Button (bottom-right) - same as HomeView
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        appState.closeCalendar()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            appState.openChat()
                        }
                    }) {
                        LumiPetAvatar()
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 110)
                }
            }
        }
        .onAppear {
            generateCalendarDays()
        }
        .onChange(of: appState.displayedMonth) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                generateCalendarDays()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Horizontal swipe for month navigation
                    if abs(value.translation.width) > abs(value.translation.height) {
                        dragOffset = value.translation.width * 0.3
                    }
                }
                .onEnded { value in
                    // Swipe left = next month
                    if value.translation.width < -80 {
                        SoundManager.hapticLight()
                        appState.navigateToNextMonth()
                    }
                    // Swipe right = previous month
                    else if value.translation.width > 80 {
                        SoundManager.hapticLight()
                        appState.navigateToPreviousMonth()
                    }
                    // Swipe down = close and return to Today
                    else if value.translation.height > 100 {
                        returnToToday()
                    }

                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
        )
    }

    private func returnToToday() {
        // Always return to Today's Bubble Sea
        appState.selectDate(Date())
        appState.isViewingDetailedDay = false
        appState.closeCalendar()
    }

    /// Show task detail overlay for a specific day (long press)
    private func showDayTaskDetail(_ day: CalendarDay) {
        // Get bubbles for this day from SwiftData
        let bubbles = appState.getBubbles(for: day.date, modelContext: modelContext)

        // Build task description from bubbles
        var taskDescription = ""
        var phaseName = ""
        var color = "FFD700"

        if day.isFuture {
            phaseName = "计划中"
            color = "87CEEB"
            if bubbles.isEmpty {
                taskDescription = "这一天还没有安排任务。"
            } else {
                let taskTexts = bubbles.map { "• \($0.text)" }.joined(separator: "\n")
                taskDescription = "已规划的任务：\n\n\(taskTexts)"
            }
        } else if day.isPast {
            switch day.completionType {
            case .coreCompleted:
                phaseName = "已完成 ✨"
                color = "FFD700"
                let taskTexts = bubbles.map { "• \($0.text)" }.joined(separator: "\n")
                taskDescription = bubbles.isEmpty ? "这一天完成了核心任务！" : "完成的任务：\n\n\(taskTexts)"
            case .choreOnly:
                phaseName = "小进步"
                color = "CBA972"
                let taskTexts = bubbles.map { "• \($0.text)" }.joined(separator: "\n")
                taskDescription = bubbles.isEmpty ? "这一天完成了一些小任务。" : "完成的任务：\n\n\(taskTexts)"
            case .empty:
                phaseName = "休息日"
                color = "888888"
                taskDescription = "这一天没有记录到任务。"
            }
        } else {
            // Today - shouldn't normally be triggered from calendar
            phaseName = "今天"
            color = "FFD700"
            let taskTexts = bubbles.map { "• \($0.text)" }.joined(separator: "\n")
            taskDescription = bubbles.isEmpty ? "今天的任务还没有设置。" : "今天的任务：\n\n\(taskTexts)"
        }

        // Format date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M月d日"
        dateFormatter.locale = Locale(identifier: "zh_Hans")
        let dateString = dateFormatter.string(from: day.date)

        // Show the overlay
        appState.showTaskDetailOverlay(
            goalTitle: dateString,
            phaseName: phaseName,
            description: taskDescription,
            color: color
        )
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        formatter.locale = Locale(identifier: "zh_Hans")
        return formatter.string(from: appState.displayedMonth)
    }

    private func generateCalendarDays() {
        let month = appState.displayedMonth
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return
        }

        var days: [CalendarDay] = []
        var currentDate = firstWeek.start

        // Generate 6 weeks of days (42 days max)
        for _ in 0..<42 {
            let dayNumber = calendar.component(.day, from: currentDate)
            let isCurrentMonth = calendar.isDate(currentDate, equalTo: month, toGranularity: .month)

            let day = CalendarDay(
                date: currentDate,
                dayNumber: dayNumber,
                isCurrentMonth: isCurrentMonth,
                isToday: appState.isToday(currentDate),
                isPast: appState.isPast(currentDate),
                isFuture: appState.isFuture(currentDate),
                completionType: appState.getCompletionType(for: currentDate),
                hasBubbles: !appState.getBubbles(for: currentDate, modelContext: modelContext).isEmpty
            )

            days.append(day)

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDay

            // Stop if we've passed the current month and filled a full week
            if !isCurrentMonth && calendar.component(.weekday, from: currentDate) == calendar.firstWeekday {
                break
            }
        }

        calendarDays = days
    }

    private func handleDayTap(_ day: CalendarDay) {
        SoundManager.hapticMedium()

        // Set the selected date
        appState.selectDate(day.date)

        // Trigger zoom transition
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            selectedDayForTransition = day
            appState.isViewingDetailedDay = true
        }

        // Close calendar after transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            appState.closeCalendar()
        }
    }
}

// MARK: - Calendar Day Cell
struct CalendarDayCell: View {
    let day: CalendarDay
    let namespace: Namespace.ID
    let isSelected: Bool
    var onLongPress: (() -> Void)? = nil

    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            if day.isToday {
                // Today: Full Rainbow Breathing Orb (Gold Standard)
                todayView
            } else if day.isPast {
                // Past: Crystallized based on completion type
                pastDayView
            } else {
                // Future: Static or empty ring
                futureDayView
            }

            // Day number
            Text("\(day.dayNumber)")
                .font(.system(size: 14, weight: day.isToday ? .bold : .semibold))
                .foregroundColor(dayNumberColor)
        }
        .frame(width: 50, height: 50)
        .matchedGeometryEffect(id: day.id, in: namespace, isSource: !isSelected)
        .scaleEffect(isSelected ? 8 : 1)
        .opacity(isSelected ? 0 : 1)
        .onLongPressGesture(minimumDuration: 0.5) {
            // Trigger for all days: today with bubbles, future with bubbles, or past with completed tasks
            if (day.isToday && day.hasBubbles) || (day.isFuture && day.hasBubbles) || (day.isPast && day.completionType != .empty) {
                SoundManager.hapticLight()
                onLongPress?()
            }
        }
    }

    // MARK: - Today View (Rainbow Breathing - The Gold Standard)
    private var todayView: some View {
        ZStack {
            // Full Rainbow SoapBubbleView with splash colors
            SoapBubbleView(
                size: 50,
                baseColors: [
                    Color(hex: "FFD700"), // Gold
                    Color(hex: "FF6B9D"), // Rose pink
                    Color(hex: "C77DFF"), // Bright purple
                    Color(hex: "4CC9F0"), // Cyan blue
                    Color(hex: "7FE3A0"), // Emerald green
                    Color(hex: "FF9770"), // Coral orange
                    Color(hex: "FFE66D")  // Bright yellow
                ],
                intensity: 3.2
            )
            .scaleEffect(pulseScale)
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: pulseScale)
            .onAppear {
                pulseScale = 1.08
            }

            // Soft outer glow ring - blurred for 3D sphere effect
            Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: 3)
                .blur(radius: 4)
        }
        .shadow(color: Color(hex: "FFD700").opacity(0.5), radius: 20)
        .shadow(color: Color.white.opacity(0.4), radius: 30)
    }

    // MARK: - Past Day View (Crystallized)
    private var pastDayView: some View {
        Group {
            switch day.completionType {
            case .coreCompleted:
                // High Light: Rainbow - AGED (reduced saturation/brightness, frozen)
                ZStack {
                    // Aged rainbow colors - desaturated and slightly dimmer
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [
                                    Color(hex: "D4B84A"),  // Aged gold
                                    Color(hex: "D4829A"),  // Muted pink
                                    Color(hex: "A882CC"),  // Soft purple
                                    Color(hex: "7AB8CC"),  // Muted cyan
                                    Color(hex: "8AC9A0"),  // Soft green
                                    Color(hex: "CC9080"),  // Muted coral
                                    Color(hex: "D4B84A")   // Back to aged gold
                                ],
                                center: .center
                            )
                        )
                        .opacity(0.55)  // Reduced from 0.7

                    // Inner glow - softer
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.15),
                                    Color.clear
                                ],
                                center: UnitPoint(x: 0.3, y: 0.3),
                                startRadius: 0,
                                endRadius: 25
                            )
                        )

                    // Edge highlight - softer
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                }
                .shadow(color: Color(hex: "D4B84A").opacity(0.25), radius: 10)

            case .choreOnly:
                // Small Win: Center glow with THICK GOLD RING
                ZStack {
                    // Center glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "CBA972").opacity(0.6),
                                    Color(hex: "8B7355").opacity(0.35),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 22
                            )
                        )

                    // Thick Gold Ring - "Small Wins" indicator
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "FFD700").opacity(0.8),
                                    Color(hex: "CBA972").opacity(0.6),
                                    Color(hex: "FFD700").opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                }
                .shadow(color: Color(hex: "FFD700").opacity(0.35), radius: 10)

            case .empty:
                // Empty: Ring only
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    .background(Circle().fill(Color.white.opacity(0.02)))
            }
        }
    }

    // MARK: - Future Day View
    private var futureDayView: some View {
        Group {
            if day.hasBubbles {
                // Has AI-planned tasks: Show static bubble
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "87CEEB").opacity(0.2),
                                    Color(hex: "ADD8E6").opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 25
                            )
                        )

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "87CEEB").opacity(0.4),
                                    Color(hex: "ADD8E6").opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )

                    // Small indicator dot for AI task
                    Circle()
                        .fill(Color(hex: "4CC9F0").opacity(0.6))
                        .frame(width: 6, height: 6)
                        .offset(x: 15, y: -15)
                }
            } else {
                // No tasks: Empty faint ring
                Circle()
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                    )
                    .foregroundColor(Color.white.opacity(0.15))
            }
        }
    }

    private var dayNumberColor: Color {
        if day.isToday {
            return .white
        } else if day.isPast {
            switch day.completionType {
            case .coreCompleted:
                return Color(hex: "FFD700").opacity(0.9)
            case .choreOnly:
                return Color(hex: "CBA972").opacity(0.8)
            case .empty:
                return Color.white.opacity(0.3)
            }
        } else {
            return day.hasBubbles
                ? Color(hex: "87CEEB").opacity(0.7)
                : Color.white.opacity(0.3)
        }
    }
}

// MARK: - Calendar Quote View (Typewriter Effect)
struct CalendarQuoteView: View {
    let quote = "看见每一步的微光。"
    @State private var displayedText: String = ""
    @State private var isAnimating: Bool = false

    var body: some View {
        Text(displayedText)
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(Color(hex: "CBA972").opacity(0.8))
            .multilineTextAlignment(.center)
            .onAppear {
                startTypewriterAnimation()
            }
    }

    private func startTypewriterAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        displayedText = ""

        for (index, character) in quote.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.12) {
                displayedText.append(character)
            }
        }
    }
}

struct StarField: View {
    @State private var stars: [Star] = []

    struct Star: Identifiable {
        let id = UUID()
        let position: CGPoint
        let size: CGFloat
        var opacity: Double
        let delay: Double
    }

    var body: some View {
        ZStack {
            ForEach(stars) { star in
                Circle()
                    .fill(Color.white)
                    .frame(width: star.size, height: star.size)
                    .position(star.position)
                    .opacity(star.opacity)
                    .animation(
                        .easeInOut(duration: Double.random(in: 2...4))
                            .repeatForever(autoreverses: true)
                            .delay(star.delay),
                        value: star.opacity
                    )
            }
        }
        .onAppear {
            generateStars()
        }
    }

    private func generateStars() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        stars = (0..<100).map { _ in
            Star(
                position: CGPoint(
                    x: CGFloat.random(in: 0...screenWidth),
                    y: CGFloat.random(in: 0...screenHeight)
                ),
                size: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.3...1.0),
                delay: Double.random(in: 0...3)
            )
        }
    }
}

// MARK: - ========== 5. L5 "Luminous Echo" - The Sanctuary (Archive View with Atmosphere & Flashlight) ==========
struct ArchiveView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var selectedGoal: CompletedGoal?
    @State private var showOverlay = false
    @State private var archivedGoals: [ArchivedGoal] = []

    // Fallback: 示例完成目标（如果没有真实数据）
    private let sampleGoals: [CompletedGoal] = [
        CompletedGoal(
            title: "完成第一本小说",
            aiWitnessText: "日复一日的书写中，碎片化的想法逐渐凝聚成完整的故事。",
            season: "2024 春",
            position: CGPoint(x: 0.5, y: 0.0),
            color: Color(hex: "FFD700")
        ),
        CompletedGoal(
            title: "30天冥想之旅",
            aiWitnessText: "每个清晨的呼吸，都成为了稳定心绪的锚点，平息着思绪的波澜。",
            season: "2025 冬",
            position: CGPoint(x: 0.5, y: 0.2),
            color: Color(hex: "87CEEB")
        ),
        CompletedGoal(
            title: "学会钢琴基础",
            aiWitnessText: "手指在琴键上找到了自己的声音，将寂静转化为旋律。",
            season: "2024 秋",
            position: CGPoint(x: 0.5, y: 0.4),
            color: Color(hex: "DDA0DD")
        ),
        CompletedGoal(
            title: "阅读50本书",
            aiWitnessText: "一个个世界如同石块般堆叠，搭建起通往理解的桥梁。",
            season: "2025 夏",
            position: CGPoint(x: 0.5, y: 0.6),
            color: Color(hex: "CBA972")
        ),
        CompletedGoal(
            title: "晨间仪式",
            aiWitnessText: "黎明又黎明，微小的仪式编织出蜕变人生的织锦。",
            season: "2025 春",
            position: CGPoint(x: 0.5, y: 0.8),
            color: Color(hex: "FFB6C1")
        ),
        CompletedGoal(
            title: "健康饮食挑战",
            aiWitnessText: "每一餐的选择，都是对自己身体的温柔对话。",
            season: "2024 夏",
            position: CGPoint(x: 0.5, y: 1.0),
            color: Color(hex: "98D8C8")
        )
    ]

    // Horizontal scatter offsets for irregular layout
    private let scatterOffsets: [CGFloat] = [-80, 60, -40, 70, -60, 50]

    // Computed property: Convert ArchivedGoals to CompletedGoal format for display
    private var completedGoals: [CompletedGoal] {
        let converted = archivedGoals.enumerated().map { index, archived in
            let season = seasonString(from: archived.completionDate)
            let yPosition = Double(index) * 0.15
            let colors: [Color] = [
                Color(hex: "FFD700"), // Gold
                Color(hex: "87CEEB"), // Sky Blue
                Color(hex: "DDA0DD"), // Plum
                Color(hex: "CBA972"), // Bronze
                Color(hex: "FFB6C1"), // Light Pink
                Color(hex: "98D8C8")  // Mint
            ]

            return CompletedGoal(
                title: archived.title,
                aiWitnessText: archived.identityTitle,
                season: season,
                position: CGPoint(x: 0.5, y: yPosition),
                color: colors[index % colors.count]
            )
        }

        // If no archived goals, show sample goals
        return converted.isEmpty ? sampleGoals : converted
    }

    var body: some View {
        ZStack {
            // LAYER 1: Deep, dark background
            LinearGradient(
                colors: [
                    Color(hex: "1C1C2E"),  // Dark Navy
                    Color(hex: "14141E"),  // Deep Charcoal
                    Color(hex: "0A0A0F")   // Almost black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // LAYER 2: Visible White Fog Blobs (Backlight - Alpha 0.15)
            ZStack {
                ForEach(0..<6, id: \.self) { index in
                    VisibleBacklightFog(index: index)
                }
            }

            // LAYER 3: Ambient Stars (Bigger - Radius 2.0-3.0)
            AmbientStarsBackground()

            // LAYER 4: Scrollable List with Irregular Scatter + Enhanced Flashlight Effect
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 140) {
                    ForEach(Array(completedGoals.enumerated()), id: \.element.id) { index, goal in
                        EnhancedFlashlightLightOrb(
                            goal: goal,
                            xOffset: scatterOffsets[index % scatterOffsets.count]
                        )
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.3)) {
                                selectedGoal = goal
                                showOverlay = true
                            }
                            SoundManager.hapticLight()
                        }
                    }
                }
                .padding(.vertical, 250)  // Add padding so items can scroll to center
            }

            // LAYER 5: Navigation header (Fixed)
            VStack {
                HStack {
                    Button(action: {
                        appState.closeArchive()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                    }

                    Spacer()

                    Text("光尘")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color(hex: "CBA972"))

                    Spacer()

                    Color.clear
                        .frame(width: 40, height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()
            }

            // LAYER 6: Overlay reveal when orb is tapped
            if showOverlay, let goal = selectedGoal {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showOverlay = false
                        }
                    }

                RecallOverlay(goal: goal)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .onAppear {
            loadArchivedGoals()
        }
    }

    // Load archived goals from SwiftData
    private func loadArchivedGoals() {
        let descriptor = FetchDescriptor<ArchivedGoal>(
            sortBy: [SortDescriptor(\.completionDate, order: .reverse)]
        )

        if let goals = try? modelContext.fetch(descriptor) {
            archivedGoals = goals
            print("ArchiveView: Loaded \(goals.count) archived goals")
        }
    }

    // Helper to format date to season
    private func seasonString(from date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        let season: String
        switch month {
        case 12, 1, 2: season = "冬"
        case 3, 4, 5: season = "春"
        case 6, 7, 8: season = "夏"
        default: season = "秋"
        }

        return "\(year) \(season)"
    }
}

// MARK: - Visible Backlight Fog Component (Alpha 0.15 - Acts as Backlight)
struct VisibleBacklightFog: View {
    let index: Int

    @State private var position: CGPoint = .zero
    @State private var opacity: Double = 0.0

    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(Color.white)
                .frame(
                    width: CGFloat.random(in: 200...350),  // Slightly smaller
                    height: CGFloat.random(in: 200...350)
                )
                .blur(radius: CGFloat.random(in: 80...120))
                .position(position)
                .opacity(opacity)
                .blendMode(.plusLighter)  // Makes it glow like backlight
                .onAppear {
                    // Initial random position
                    position = CGPoint(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height)
                    )

                    // Visible backlight - Alpha 0.15
                    withAnimation(.easeIn(duration: 4.0).delay(Double(index) * 0.4)) {
                        opacity = 0.15  // VISIBLE as backlight
                    }

                    // Slow drift
                    startDrifting(geometry: geometry)
                }
        }
    }

    private func startDrifting(geometry: GeometryProxy) {
        let duration = Double.random(in: 120...180)
        let newPosition = CGPoint(
            x: CGFloat.random(in: -80...geometry.size.width + 80),
            y: CGFloat.random(in: -80...geometry.size.height + 80)
        )

        withAnimation(.linear(duration: duration)) {
            position = newPosition
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            startDrifting(geometry: geometry)
        }
    }
}

// MARK: - Ambient Stars Background (Bigger - Radius 2.0-3.0)
struct AmbientStarsBackground: View {
    @State private var stars: [AmbientStar] = []

    var body: some View {
        ZStack {
            ForEach(stars) { star in
                Circle()
                    .fill(Color.white)
                    .frame(width: star.size, height: star.size)
                    .position(star.position)
                    .opacity(star.opacity)
                    .animation(
                        .easeInOut(duration: Double.random(in: 3...6))
                            .repeatForever(autoreverses: true)
                            .delay(star.delay),
                        value: star.opacity
                    )
            }
        }
        .onAppear {
            generateStars()
        }
    }

    private func generateStars() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        stars = (0..<80).map { _ in
            AmbientStar(
                position: CGPoint(
                    x: CGFloat.random(in: 0...screenWidth),
                    y: CGFloat.random(in: 0...screenHeight)
                ),
                size: CGFloat.random(in: 2.0...3.0),  // BIGGER stars (2.0-3.0)
                opacity: Double.random(in: 0.4...0.8),
                delay: Double.random(in: 0...4)
            )
        }
    }
}

struct AmbientStar: Identifiable {
    let id = UUID()
    let position: CGPoint
    let size: CGFloat
    let opacity: Double
    let delay: Double
}

// MARK: - Enhanced Flashlight Light Orb (DRAMATIC Scaling + Irregular Scatter)
struct EnhancedFlashlightLightOrb: View {
    let goal: CompletedGoal
    let xOffset: CGFloat  // Horizontal scatter offset

    var body: some View {
        GeometryReader { geometry in
            let screenCenterY = UIScreen.main.bounds.height / 2
            let itemCenterY = geometry.frame(in: .global).midY
            let distanceFromCenter = abs(itemCenterY - screenCenterY)

            // ENHANCED DRAMATIC SCALING
            // Max scale: 1.8x (REALLY POP!)
            // Min scale: 0.6x (Much smaller)
            let scale = max(0.6, min(1.8, 1.8 - (distanceFromCenter / 300)))

            // Opacity: Fade distant items to 0.4
            let opacity = max(0.4, 1.0 - (distanceFromCenter / 350))

            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                goal.color.opacity(0.6),
                                goal.color.opacity(0.4),
                                goal.color.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 18)

                // Core light
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                goal.color.opacity(0.9),
                                goal.color.opacity(0.7)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 22
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: goal.color.opacity(0.8), radius: 25, x: 0, y: 0)
            }
            .scaleEffect(scale)  // DRAMATIC flashlight effect
            .opacity(opacity)
            .offset(x: xOffset)  // IRREGULAR SCATTER (horizontal offset)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(height: 120)
    }
}

// MARK: - Recall Overlay Component
struct RecallOverlay: View {
    let goal: CompletedGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Goal title
            Text(goal.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            // AI Witness Text (The poetic reflection)
            Text(goal.aiWitnessText)
                .font(.custom("Georgia", size: 16))
                .italic()
                .foregroundColor(Color(hex: "CBA972").opacity(0.9))
                .lineSpacing(6)
                .padding(.vertical, 8)

            // Timestamp
            Text(goal.season)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))

            Spacer()
                .frame(height: 4)
        }
        .padding(28)
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "14141E").opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    goal.color.opacity(0.4),
                                    goal.color.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: goal.color.opacity(0.3), radius: 30, x: 0, y: 10)
    }
}

// MARK: - Data Model for Completed Goals
struct CompletedGoal: Identifiable {
    let id = UUID()
    let title: String
    let aiWitnessText: String
    let season: String
    let position: CGPoint
    let color: Color
}

// MARK: - Task Detail Overlay (Long Press)
struct TaskDetailOverlay: View {
    let goalTitle: String
    let phaseName: String
    let taskDetail: String
    let bubbleColor: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Glassmorphism card
            VStack(spacing: 20) {
                // Goal Title
                Text(goalTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: bubbleColor))
                    .multilineTextAlignment(.center)

                // Phase Name
                Text(phaseName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "8B8B8B"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(hex: bubbleColor).opacity(0.15))
                    )

                // Divider
                Rectangle()
                    .fill(Color(hex: bubbleColor).opacity(0.3))
                    .frame(height: 1)
                    .padding(.horizontal, 20)

                // Task Detail
                Text(taskDetail)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "3C3C3C"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 24)

                // Dismiss hint
                Text("轻触背景关闭")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8B8B8B"))
                    .padding(.top, 8)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: bubbleColor).opacity(0.5),
                                        Color(hex: bubbleColor).opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
            .shadow(color: Color(hex: bubbleColor).opacity(0.3), radius: 30, x: 0, y: 10)
            .padding(.horizontal, 40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

// MARK: - Floating Banner (Silent Narrator Toast)
struct FloatingBanner: View {
    let message: String
    let isVisible: Bool

    var body: some View {
        VStack {
            if isVisible {
                HStack(spacing: 10) {
                    // Lumi mini icon
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "FFD700"),
                                    Color(hex: "CBA972")
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 12
                            )
                        )
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )

                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "3C3C3C"))
                        .lineLimit(2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "FFD700").opacity(0.4),
                                            Color(hex: "CBA972").opacity(0.2)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .shadow(color: Color(hex: "FFD700").opacity(0.2), radius: 15, x: 0, y: 5)
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
    }
}

// MARK: - Draft Preview Card (Blueprint Text)
struct DraftPreviewCard: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "FFD700"))

                Text("愿景契约草案")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "FFD700"))

                Spacer()
            }

            // Divider
            Rectangle()
                .fill(Color(hex: "FFD700").opacity(0.3))
                .frame(height: 1)

            // Content
            Text(content)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "3C3C3C"))
                .lineSpacing(6)

            // Footer hint
            Text("请确认后继续")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "8B8B8B"))
                .padding(.top, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "FFF9E6"),
                            Color.white
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "FFD700"),
                                    Color(hex: "CBA972")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
        .shadow(color: Color(hex: "FFD700").opacity(0.2), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 16)
    }
}

// MARK: - Contract Status Card (Processing)
struct ContractStatusCard: View {
    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "FFD700"))

            // Status text
            VStack(spacing: 8) {
                Text("契约已生效")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "3C3C3C"))

                Text("愿景正在生成...")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "8B8B8B"))
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "FFD700").opacity(0.5),
                                    Color(hex: "CBA972").opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: Color(hex: "FFD700").opacity(0.15), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 16)
    }
}

// MARK: - Contract Error Card (JSON Parse Failed)
struct ContractErrorCard: View {
    let errorMessage: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Error Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "FF6B6B"))

            // Error text
            VStack(spacing: 8) {
                Text("契约解析失败")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "3C3C3C"))

                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "8B8B8B"))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            // Retry button
            Button(action: onRetry) {
                Text("重新生成")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color(hex: "CBA972"))
                    )
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "FF6B6B").opacity(0.4),
                                    Color(hex: "FFB5B5").opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: Color(hex: "FF6B6B").opacity(0.1), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 16)
    }
}

// MARK: - Contract Card (Blueprint Message)
struct ContractCard: View {
    let blueprint: GoalBlueprint
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(Color(hex: "FFD700"))
                    .font(.system(size: 20))

                Text("愿景契约草案")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "FFD700"))

                Spacer()
            }

            // Goal Title
            VStack(alignment: .leading, spacing: 6) {
                Text("目标")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "8B8B8B"))

                Text(blueprint.goalTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "3C3C3C"))
            }

            // Divider
            Rectangle()
                .fill(Color(hex: "FFD700").opacity(0.3))
                .frame(height: 1)

            // Phases
            VStack(alignment: .leading, spacing: 12) {
                Text("阶段计划")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "8B8B8B"))

                ForEach(Array(blueprint.phases.enumerated()), id: \.offset) { index, phase in
                    HStack(alignment: .top, spacing: 12) {
                        // Phase number
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: phase.bubbleColor))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color(hex: phase.bubbleColor).opacity(0.15))
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(phase.phaseName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "3C3C3C"))

                            Text("\(phase.durationDays)天 · \(phase.dailyTaskLabel)")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "8B8B8B"))
                        }

                        Spacer()
                    }
                }
            }

            // Confirm Button
            Button(action: onConfirm) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("确认启动")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [
                            Color(hex: "FFD700"),
                            Color(hex: "CBA972")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "FFD700"),
                                    Color(hex: "CBA972")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
        .shadow(color: Color(hex: "FFD700").opacity(0.2), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 16)
    }
}

// MARK: - Letter Envelope Overlay (Goal Completion Ritual)
struct LetterEnvelopeOverlay: View {
    let onTap: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var glowIntensity: Double = 0
    @State private var particlesVisible = false

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            // Particle effect background
            if particlesVisible {
                ForEach(0..<20, id: \.self) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "FFD700"),
                                    Color(hex: "CBA972")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 8, height: 8)
                        .offset(
                            x: CGFloat.random(in: -150...150),
                            y: CGFloat.random(in: -200...200)
                        )
                        .opacity(Double.random(in: 0.3...0.8))
                        .blur(radius: 2)
                }
            }

            // Central content
            VStack(spacing: 32) {
                // Envelope icon with glow
                ZStack {
                    // Outer glow layers
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: "envelope.circle.fill")
                            .font(.system(size: 140))
                            .foregroundColor(Color(hex: "FFD700"))
                            .opacity(glowIntensity * 0.3)
                            .scaleEffect(1.0 + Double(index) * 0.15 * glowIntensity)
                            .blur(radius: 15 + Double(index) * 10)
                    }

                    // Main envelope icon
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 120))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: "FFD700"),
                                    Color(hex: "CBA972")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color(hex: "FFD700").opacity(0.5), radius: 30, x: 0, y: 10)
                }
                .scaleEffect(scale)

                // Label
                VStack(spacing: 8) {
                    Text("微光为你寄来了一封信")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)

                    Text("轻触查看")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
                .opacity(opacity)
            }
        }
        .onTapGesture {
            onTap()
        }
        .onAppear {
            // Stagger animations
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }

            // Start particle effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    particlesVisible = true
                }
            }

            // Pulsing glow animation
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                glowIntensity = 1.0
            }
        }
    }
}

// MARK: - ========== Letter View (Graduation Letter Display) ==========
struct LetterView: View {
    @ObservedObject var appState: AppState
    let modelContext: ModelContext

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var cardRotation: Double = -10

    var body: some View {
        ZStack {
            // Dark overlay background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            // Loading indicator or letter content
            if appState.isLoadingLetter {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(Color(hex: "CBA972"))

                    Text("正在生成你的信...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "CBA972"))
                }
            } else {
                // Paper-texture card
                letterCard
            }
        }
        .contentShape(Rectangle())  // Make entire screen tappable
        .onTapGesture {
            if !appState.isLoadingLetter {
                dismissLetter()
            }
        }
        .onAppear {
            // Entrance animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
                cardRotation = 0
            }

            // Fetch letter content if not already loaded
            if appState.graduationLetterContent.isEmpty {
                Task {
                    await appState.fetchGraduationLetter(modelContext: modelContext)
                }
            }
        }
    }

    private var letterCard: some View {
        VStack(spacing: 0) {
                // Letter title
                Text(appState.graduationLetterTitle)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(Color(hex: "8B4513"))
                    .padding(.top, 40)
                    .padding(.bottom, 20)

                // Decorative line
                Divider()
                    .frame(width: 200)
                    .background(Color(hex: "CBA972").opacity(0.3))
                    .padding(.bottom, 30)

                // Letter content
                ScrollView {
                    Text(appState.graduationLetterContent)
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundColor(Color(hex: "4A4A4A"))
                        .lineSpacing(8)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 30)
                }
                .frame(maxHeight: 400)

                // Tap hint
                Text("轻触任意处继续")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(Color(hex: "8B8B8B"))
                    .padding(.top, 30)
                    .padding(.bottom, 40)
            }
            .frame(maxWidth: 350)
            .background(
                ZStack {
                    // Paper texture background
                    LinearGradient(
                        colors: [
                            Color(hex: "FFF8E7"),
                            Color(hex: "FFEFD5"),
                            Color(hex: "FFF8E7")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Subtle paper grain overlay
                    Color.white.opacity(0.1)
                        .blendMode(.overlay)
                }
            )
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.3), radius: 30, x: 0, y: 15)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "CBA972").opacity(0.6),
                                Color(hex: "D4AF37").opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .rotation3DEffect(
                .degrees(cardRotation),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.5
            )
    }

    private func dismissLetter() {
        SoundManager.hapticLight()

        // Exit animation
        withAnimation(.easeOut(duration: 0.3)) {
            scale = 0.8
            opacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Close letter view
            appState.showLetterView = false

            // Add transition message to chat
            let transitionMessage = ChatMessage(
                content: "（信已收好）\n\n休息得怎么样？当你准备好开始下一段旅程时，随时告诉我。",
                isUser: false
            )
            modelContext.insert(transitionMessage)
            try? modelContext.save()
            appState.reloadChatMessages(from: modelContext)

            // Open chat after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                appState.openChat()
            }
        }
    }
}

// MARK: - ========== 庆祝动画 (Confetti Overlay) ==========
struct ConfettiOverlay: View {
    @State private var particles: [ConfettiParticle] = []

    private let colors: [Color] = [
        Color(hex: "FFD700"), // Gold
        Color(hex: "FF6B9D"), // Pink
        Color(hex: "C77DFF"), // Purple
        Color(hex: "4CC9F0"), // Cyan
        Color(hex: "7FE3A0"), // Green
        Color(hex: "FF9770"), // Orange
        Color(hex: "FFEE58")  // Yellow
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiPiece(particle: particle)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
            }
        }
        .ignoresSafeArea()
    }

    private func createParticles(in size: CGSize) {
        particles = (0..<100).map { index in
            ConfettiParticle(
                id: index,
                color: colors[Int.random(in: 0..<colors.count)],
                startX: CGFloat.random(in: 0...size.width),
                startY: -20,
                endX: CGFloat.random(in: -100...size.width + 100),
                endY: size.height + 50,
                rotation: Double.random(in: 0...720),
                scale: CGFloat.random(in: 0.5...1.2),
                duration: Double.random(in: 2.0...3.5),
                delay: Double.random(in: 0...0.5)
            )
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id: Int
    let color: Color
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let rotation: Double
    let scale: CGFloat
    let duration: Double
    let delay: Double
}

struct ConfettiPiece: View {
    let particle: ConfettiParticle

    @State private var position: CGPoint
    @State private var currentRotation: Double = 0
    @State private var opacity: Double = 1.0

    init(particle: ConfettiParticle) {
        self.particle = particle
        self._position = State(initialValue: CGPoint(x: particle.startX, y: particle.startY))
    }

    var body: some View {
        // Random shape: rectangle or circle
        Group {
            if particle.id % 3 == 0 {
                Rectangle()
                    .fill(particle.color)
                    .frame(width: 8 * particle.scale, height: 12 * particle.scale)
            } else if particle.id % 3 == 1 {
                Circle()
                    .fill(particle.color)
                    .frame(width: 10 * particle.scale, height: 10 * particle.scale)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(particle.color)
                    .frame(width: 6 * particle.scale, height: 10 * particle.scale)
            }
        }
        .rotationEffect(.degrees(currentRotation))
        .position(position)
        .opacity(opacity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + particle.delay) {
                withAnimation(.easeIn(duration: particle.duration)) {
                    position = CGPoint(x: particle.endX, y: particle.endY)
                    currentRotation = particle.rotation
                }

                // Fade out near the end
                withAnimation(.easeIn(duration: particle.duration * 0.8).delay(particle.duration * 0.5)) {
                    opacity = 0
                }
            }
        }
    }
}

// MARK: - ========== 工具扩展 ==========
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
