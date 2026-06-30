import Foundation

/// Lieu de stockage — table `locations`.
public struct ItemLocation: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
