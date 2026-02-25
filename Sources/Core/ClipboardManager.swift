import Cocoa
import Combine

class ClipboardManager: ObservableObject {
    @Published var history: [ClipboardItem] = []
    var previousApp: NSRunningApplication?
    
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    
    init() {
        self.lastChangeCount = pasteboard.changeCount
        loadHistory()
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer(timeInterval: AppConstants.Clipboard.pollingInterval, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForChanges() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. Check for Files
            if let fileURLs = self.pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !fileURLs.isEmpty {
                let firstURL = fileURLs[0]
                let content = firstURL.lastPathComponent
                DispatchQueue.main.async {
                    self.addItem(content: content, type: .file, fileURL: firstURL.path)
                }
                return
            }
            
            // 2. Check for Images
            if let imgData = self.pasteboard.data(forType: .tiff) ?? self.pasteboard.data(forType: .png) {
                // Determine image size for title if possible
                var contentTitle = "[Image]"
                if let nsImage = NSImage(data: imgData) {
                    contentTitle = "[Image \(Int(nsImage.size.width))x\(Int(nsImage.size.height))]"
                }
                
                // Downsample image data if it's too large to prevent history bloat
                var finalData = imgData
                if finalData.count > 5 * 1024 * 1024 { // Compress if > 5MB
                    if let bitmapRep = NSBitmapImageRep(data: imgData),
                       let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) {
                        finalData = jpegData
                    }
                }
                
                DispatchQueue.main.async {
                    self.addItem(content: contentTitle, type: .image, imageData: finalData)
                }
                return
            }
            
            // 3. Fallback to Text
            if let newString = self.pasteboard.string(forType: .string) {
                let cleanString = newString.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanString.isEmpty {
                    DispatchQueue.main.async {
                        self.addItem(content: cleanString, type: .text)
                    }
                }
            }
        }
    }
    
    func addItem(content: String, type: ClipboardItemType = .text, imageData: Data? = nil, fileURL: String? = nil) {
        let wasPinned = history.first(where: {
            if type == .text { return $0.content == content && $0.type == .text }
            if type == .image { return $0.imageData == imageData && $0.type == .image }
            if type == .file { return $0.fileURL == fileURL && $0.type == .file }
            return false
        })?.isPinned ?? false
        
        // Remove existing items with exact same content to bump to top
        history.removeAll {
            if type == .text { return $0.content == content && $0.type == .text }
            if type == .image { return $0.imageData == imageData && $0.type == .image }
            if type == .file { return $0.fileURL == fileURL && $0.type == .file }
            return false
        }
        
        var item = ClipboardItem(content: content, timestamp: Date())
        item.type = type
        item.imageData = imageData
        item.fileURL = fileURL
        item.isPinned = wasPinned
        history.insert(item, at: 0)
        
        enforceHistoryLimit()
        saveHistory()
    }
    
    private func enforceHistoryLimit() {
        if history.count > AppConstants.Clipboard.historyLimit {
            let unpinnedIndexes = history.indices.filter { !history[$0].isPinned }
            if let lastUnpinned = unpinnedIndexes.last {
                history.remove(at: lastUnpinned)
            }
        }
    }
    
    func deleteItem(id: UUID) {
        history.removeAll { $0.id == id }
        saveHistory()
    }
    
    func togglePin(for id: UUID) {
        if let index = history.firstIndex(where: { $0.id == id }) {
            history[index].isPinned.toggle()
            saveHistory()
        }
    }
    
    func copyToClipboard(item: ClipboardItem) {
        pasteboard.clearContents()
        
        switch item.type {
        case .text:
            pasteboard.setString(item.content, forType: .string)
        case .image:
            if let imgData = item.imageData {
                pasteboard.setData(imgData, forType: .tiff)
            }
        case .file:
            if let path = item.fileURL {
                let url = URL(fileURLWithPath: path)
                pasteboard.writeObjects([url as NSPasteboardWriting])
            }
        }
        
        lastChangeCount = pasteboard.changeCount
    }
    
    func copyAndPaste(item: ClipboardItem) {
        copyToClipboard(item: item)

        guard AXIsProcessTrusted() else {
            showAccessibilityAlert()
            return
        }

        NotificationCenter.default.post(name: NSNotification.Name("HidePanel"), object: nil)
        restoreFocusAndPaste()
    }
    
    private func showAccessibilityAlert() {
        NotificationCenter.default.post(name: NSNotification.Name("HidePanel"), object: nil)
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "macOS has revoked Maclipboard's Accessibility permission because the app was recompiled.\n\nPlease go to System Settings → Privacy & Security → Accessibility, remove (—) Maclipboard, and add (+) it again."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            
            NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
            
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: AppConstants.System.accessibilityURL) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    private func restoreFocusAndPaste() {
        guard let targetApp = previousApp, let appURL = targetApp.bundleURL else { return }
        
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { [weak self] _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Clipboard.activateDelay) {
                self?.simulatePasteKeystroke()
            }
        }
    }
    
    private func simulatePasteKeystroke() {
        let vKeyCode: CGKeyCode = AppConstants.KeyCode.v
        let cmdKeyCode: CGKeyCode = AppConstants.KeyCode.command
        guard let src = CGEventSource(stateID: .hidSystemState) else { return }

        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: cmdKeyCode, keyDown: true)
        let vDown   = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true)
        vDown?.flags = .maskCommand
        let vUp     = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false)
        vUp?.flags  = .maskCommand
        let cmdUp   = CGEvent(keyboardEventSource: src, virtualKey: cmdKeyCode, keyDown: false)

        let loc = CGEventTapLocation.cghidEventTap
        cmdDown?.post(tap: loc)
        vDown?.post(tap: loc)
        vUp?.post(tap: loc)
        cmdUp?.post(tap: loc)
    }
    
    func clearUnpinnedHistory() {
        history.removeAll(where: { !$0.isPinned })
        saveHistory()
    }
    
    func clearAllHistory() {
        history.removeAll()
        saveHistory()
    }
    
    // MARK: - Persistence
    
    // MARK: - Persistence
    
    private var storageURL: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return paths[0]
            .appendingPathComponent(AppConstants.System.folderName)
            .appendingPathComponent(AppConstants.System.fileName)
    }
    
    private func saveHistory() {
        do {
            let directory = storageURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            
            let data = try JSONEncoder().encode(history)
            try data.write(to: storageURL)
        } catch {
            print("Failed to save history: \(error)")
        }
    }
    
    private func loadHistory() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        do {
            history = try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            print("Failed to load history: \(error)")
        }
    }
}
