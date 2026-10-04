import ActivityKit
import SwiftUI
import SwiftShieldCore
import WidgetKit

struct SwiftShieldLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SwiftShieldActivityAttributes.self) { context in
            lockScreenView(context)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "swiftshield://open"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    elapsedTime(context.state.connectedAt)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.status)
                            .font(.headline)
                        Text(context.state.profileName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    disconnectLink
                        .padding(.top, 6)
                }
            } compactLeading: {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.white)
            } compactTrailing: {
                elapsedTime(context.state.connectedAt)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(maxWidth: 54)
            } minimal: {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.white)
            }
            .widgetURL(URL(string: "swiftshield://open"))
            .keylineTint(.white)
        }
    }

    private func lockScreenView(
        _ context: ActivityViewContext<SwiftShieldActivityAttributes>
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(context.state.status)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(context.state.profileName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 7) {
                elapsedTime(context.state.connectedAt)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white)
                disconnectLink
            }
        }
        .padding(16)
    }

    private var disconnectLink: some View {
        Link(destination: URL(string: "swiftshield://disconnect")!) {
            Label("Отключить", systemImage: "power")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(.white, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func elapsedTime(_ connectedAt: Date?) -> some View {
        if let connectedAt {
            Text(connectedAt, style: .timer)
        } else {
            Text("--:--")
        }
    }
}
