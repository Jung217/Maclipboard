import Cocoa

enum AppConstants {
    // UI Constants
    enum UI {
        static let panelWidth: CGFloat = 350
        static let panelHeight: CGFloat = 450
        static let cornerRadius: CGFloat = 12
    }
    
    // Key Codes
    enum KeyCode {
        static let v: CGKeyCode = 0x09
        static let command: CGKeyCode = 0x37
    }
    
    // Core Logic Bounds
    enum Clipboard {
        static let pollingInterval: TimeInterval = 0.5
        static let historyLimit = 100
        static let activateDelay: TimeInterval = 0.15
    }
    
    // File Paths / System identifiers
    enum System {
        static let folderName = "Maclipboard"
        static let fileName = "history.json"
        static let accessibilityURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    }
    
    // Settings Defaults
    enum Settings {
        static let defaultOpacity: Double = 0.95
        static let defaultColorHex: String = "" // Empty means use system default
        static let defaultAppearance: Int = 0 // 0: System, 1: Light, 2: Dark
        static let defaultBlurBackground: Bool = false
        static let defaultBlurRadius: Double = 15.0
    }
}
