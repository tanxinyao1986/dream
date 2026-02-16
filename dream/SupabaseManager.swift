import Foundation
import Combine
import Supabase
import AuthenticationServices

// MARK: - Data Models

struct DailyTaskRecord: Codable {
    let user_id: String
    let title: String
    let scheduled_date: String
    let is_completed: Bool
    let goal_id: String?
}

struct DailyReflectionRecord: Codable {
    let user_id: String
    let reflection_date: String
    let total_tasks: Int
    let completed_tasks: Int
    let mood: String
}

// MARK: - SupabaseManager

@MainActor
final class SupabaseManager: ObservableObject {

    static let shared = SupabaseManager()

    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://fvvxpizfqoeknubjjcpr.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ2dnhwaXpmcW9la251YmpqY3ByIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwODU2NzEsImV4cCI6MjA4MjY2MTY3MX0.m7iIvF1BGe5XEvvWIDqbqzJ-F_UWeXUbRIx78z3Hl4g"
        )
    }

    // MARK: - Session Restore

    func restoreSession() async {
        defer { isLoading = false }
        do {
            let session = try await client.auth.session
            isAuthenticated = true
            print("SupabaseManager: ✅ Session restored for user \(session.user.id)")
        } catch {
            isAuthenticated = false
            print("SupabaseManager: No existing session")
        }
    }

    // MARK: - Sign in with Apple

    func signInWithApple(idToken: String, nonce: String) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        isAuthenticated = true
        print("SupabaseManager: ✅ Signed in as \(session.user.id)")
    }

    // MARK: - Account & Data Management

    func signOut() async {
        do {
            try await client.auth.signOut()
            isAuthenticated = false
            print("SupabaseManager: ✅ Signed out")
        } catch {
            print("SupabaseManager: ⚠️ Failed to sign out: \(error.localizedDescription)")
        }
    }

    func deleteUserData() async {
        do {
            let userId = try await client.auth.session.user.id.uuidString

            // Delete user-scoped records (RLS must allow owner delete)
            try await client.from("daily_tasks")
                .delete()
                .eq("user_id", value: userId)
                .execute()

            try await client.from("daily_reflections")
                .delete()
                .eq("user_id", value: userId)
                .execute()

            print("SupabaseManager: ✅ Deleted user data for \(userId)")
        } catch {
            print("SupabaseManager: ⚠️ Failed to delete user data: \(error.localizedDescription)")
        }
    }

    // MARK: - Data Reporting

    func reportTaskCompletion(title: String, scheduledDate: Date) {
        Task {
            guard let userId = try? await client.auth.session.user.id.uuidString else { return }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateStr = formatter.string(from: scheduledDate)

            let record = DailyTaskRecord(
                user_id: userId,
                title: title,
                scheduled_date: dateStr,
                is_completed: true,
                goal_id: nil
            )

            do {
                try await client.from("daily_tasks").insert(record).execute()
                print("SupabaseManager: ✅ Reported task completion: \(title)")
            } catch {
                print("SupabaseManager: ⚠️ Failed to report task: \(error.localizedDescription)")
            }
        }
    }

    func reportDailyReflection(totalTasks: Int, completedTasks: Int, mood: String) {
        Task {
            guard let userId = try? await client.auth.session.user.id.uuidString else { return }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateStr = formatter.string(from: Date())

            let record = DailyReflectionRecord(
                user_id: userId,
                reflection_date: dateStr,
                total_tasks: totalTasks,
                completed_tasks: completedTasks,
                mood: mood
            )

            do {
                try await client.from("daily_reflections")
                    .upsert(record, onConflict: "user_id,reflection_date")
                    .execute()
                print("SupabaseManager: ✅ Reported daily reflection: mood=\(mood)")
            } catch {
                print("SupabaseManager: ⚠️ Failed to report reflection: \(error.localizedDescription)")
            }
        }
    }
}
