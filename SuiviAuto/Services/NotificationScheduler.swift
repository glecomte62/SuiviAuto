import Foundation
import SwiftData
import UserNotifications

@MainActor
enum NotificationScheduler {
    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Supprime puis replanifie toutes les notifications (idempotent).
    static func reschedule(context: ModelContext) async {
        let cars = (try? context.fetch(FetchDescriptor<Car>())) ?? []
        let plans = NotificationPlanner.plan(items: DueAggregator.items(for: cars), now: .now)
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for plan in plans {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: plan.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: plan.id, content: content, trigger: trigger))
        }
    }
}
