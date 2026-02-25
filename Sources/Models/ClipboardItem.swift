import Foundation

enum ClipboardItemType: String, Codable {
    case text
    case image
    case file
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let content: String
    let timestamp: Date
    var isPinned: Bool = false
    
    // New properties for extended types
    var type: ClipboardItemType = .text
    var imageData: Data? = nil
    var fileURL: String? = nil
    
    // For Equatable, we primarily care about the ID,
    // but in lists, if content updates we might want differentiation.
    // We'll stick to ID since we overwrite items.
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        return lhs.id == rhs.id
    }
}
