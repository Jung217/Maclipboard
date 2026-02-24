import SwiftUI

class SettingsManager: ObservableObject {
    @AppStorage("panelOpacity") var panelOpacity: Double = AppConstants.Settings.defaultOpacity
    @AppStorage("panelColorHex") var panelColorHex: String = AppConstants.Settings.defaultColorHex
    @AppStorage("appearanceMode") var appearanceMode: Int = AppConstants.Settings.defaultAppearance // 0: System, 1: Light, 2: Dark
    @AppStorage("backgroundImageBookmark") var backgroundImageBookmark: Data?
    @AppStorage("blurBackground") var blurBackground: Bool = AppConstants.Settings.defaultBlurBackground
    @AppStorage("blurRadius") var blurRadius: Double = AppConstants.Settings.defaultBlurRadius
    
    // Convert hex string to SwiftUI Color
    var panelColor: Color {
        get {
            if panelColorHex.isEmpty {
                return Color(NSColor.windowBackgroundColor) // Default macOS background
            }
            return Color(hex: panelColorHex) ?? Color(NSColor.windowBackgroundColor)
        }
        set {
            if let hex = newValue.toHex() {
                panelColorHex = hex
            } else {
                panelColorHex = "" // Fallback to default
            }
        }
    }
    
    // Determine the color scheme based on user selection
    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil // System default
        }
    }
    
    // MARK: - Background Image Handling
    
    var backgroundImage: NSImage? {
        guard let bookmarkData = backgroundImageBookmark else { return nil }
        var isStale = false
        
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                // If stale, try to re-create the bookmark (rare in this simple context without moving the file)
                saveBookmark(for: url)
            }
            
            if url.startAccessingSecurityScopedResource() {
                let image = NSImage(contentsOf: url)
                url.stopAccessingSecurityScopedResource()
                return image
            }
        } catch {
            print("Failed to resolve background image bookmark: \(error.localizedDescription)")
            // Clear invalid bookmark
            backgroundImageBookmark = nil
        }
        
        return nil
    }
    
    func selectBackgroundImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        
        if panel.runModal() == .OK, let url = panel.url {
            saveBookmark(for: url)
            panelOpacity = 1.0
        }
    }
    
    func clearBackgroundImage() {
        backgroundImageBookmark = nil
        blurBackground = AppConstants.Settings.defaultBlurBackground
        blurRadius = AppConstants.Settings.defaultBlurRadius
    }
    
    private func saveBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            backgroundImageBookmark = data
        } catch {
            print("Failed to save background image bookmark: \(error.localizedDescription)")
        }
    }
}

// Extension to convert between Color and Hex String
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        
        let r, g, b, a: Double
        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }

    func toHex() -> String? {
        // Extract RGB values using NSColor
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        
        let r = Int(nsColor.redComponent * 255.0)
        let g = Int(nsColor.greenComponent * 255.0)
        let b = Int(nsColor.blueComponent * 255.0)
        let a = Int(nsColor.alphaComponent * 255.0)
        
        if a == 255 {
            return String(format: "#%02X%02X%02X", r, g, b)
        } else {
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
    }
}
