import ActivityKit
import Foundation
import SwiftShieldCore

@MainActor
final class LiveActivityController {
    private var activity: Activity<SwiftShieldActivityAttributes>?

    func restore() {
        activity = Activity<SwiftShieldActivityAttributes>.activities.first
    }

    func start(profile: TunnelProfile) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if activity != nil {
            update(status: "Подключение", profileName: profile.name, connectedAt: nil, isConnected: false)
            return
        }

        let attributes = SwiftShieldActivityAttributes(profileID: profile.id)
        let state = SwiftShieldActivityAttributes.ContentState(
            status: "Подключение",
            profileName: profile.name,
            connectedAt: nil,
            isConnected: false
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }

    func update(
        status: String,
        profileName: String,
        connectedAt: Date?,
        isConnected: Bool
    ) {
        guard let activity else { return }
        let state = SwiftShieldActivityAttributes.ContentState(
            status: status,
            profileName: profileName,
            connectedAt: connectedAt,
            isConnected: isConnected
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end(profileName: String) {
        guard let activity else { return }
        self.activity = nil
        let state = SwiftShieldActivityAttributes.ContentState(
            status: "Отключено",
            profileName: profileName,
            connectedAt: nil,
            isConnected: false
        )
        Task {
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }
}
