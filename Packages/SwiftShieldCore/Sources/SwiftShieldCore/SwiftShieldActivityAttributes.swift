#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import Foundation

@available(iOS 16.1, *)
public struct SwiftShieldActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var status: String
        public var profileName: String
        public var connectedAt: Date?
        public var isConnected: Bool

        public init(status: String, profileName: String, connectedAt: Date?, isConnected: Bool) {
            self.status = status
            self.profileName = profileName
            self.connectedAt = connectedAt
            self.isConnected = isConnected
        }
    }

    public var profileID: UUID

    public init(profileID: UUID) {
        self.profileID = profileID
    }
}
#endif
