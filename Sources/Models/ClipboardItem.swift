import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let content: String
    let timestamp: Date
    var isPinned: Bool = false
    
    // For Equatable, we only care about id
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        return lhs.id == rhs.id
    }
}
