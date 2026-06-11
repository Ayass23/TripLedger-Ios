import Foundation

// Shared participant entry model for Split Bill
struct ParticipantEntry: Identifiable, Hashable {
    let id: String
    var uid: String?
    var name: String
    var isSelected: Bool = true

    // Equatable conformance
    static func == (lhs: ParticipantEntry, rhs: ParticipantEntry) -> Bool {
        return lhs.id == rhs.id &&
               lhs.uid == rhs.uid &&
               lhs.name == rhs.name &&
               lhs.isSelected == rhs.isSelected
    }
}
