import Foundation
import BackgroundTasks

// MARK: - Background Task Scheduler
@MainActor
class NABackgroundService {
    static let shared = NABackgroundService()
    private let taskID = "com.santoslab.naice.refresh"

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            self.handleTask(task as! BGAppRefreshTask)
        }
    }

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleTask(_ task: BGAppRefreshTask) {
        task.expirationHandler = { task.setTaskCompleted(success: false) }

        Task {
            await NARollupService.shared.fetch()
            await WhatsAppViewModel.shared.fetchPending()
            await NAWorkflowService.shared.checkTriggers()
            task.setTaskCompleted(success: true)
            schedule()
        }
    }
}