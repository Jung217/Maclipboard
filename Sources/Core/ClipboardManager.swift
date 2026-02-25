import Cocoa
import Combine

class ClipboardManager: ObservableObject {
    @Published var history: [ClipboardItem] = []
    var previousApp: NSRunningApplication?
    
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    
    // Desktop Monitoring for Native Screenshots
    private var desktopMonitorSource: DispatchSourceFileSystemObject?
    private var desktopMonitorDescriptor: Int32 = -1
    private var seenDesktopFiles = Set<String>()
    
    init() {
        self.lastChangeCount = pasteboard.changeCount
        loadHistory()
        startMonitoring()
        startDesktopMonitoring()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ScreenshotDirectoryChanged"), object: nil, queue: .main) { [weak self] _ in
            self?.stopDesktopMonitoring()
            self?.startDesktopMonitoring()
        }
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
        stopDesktopMonitoring()
    }
    
    // MARK: - Desktop Monitor for Screenshots
    
    private func startDesktopMonitoring() {
        let screenshotURL = SettingsManager().screenshotDirectoryURL
        let path = screenshotURL.path
        
        // Initialize seen files
        if let files = try? FileManager.default.contentsOfDirectory(atPath: path) {
            seenDesktopFiles = Set(files)
        }
        
        desktopMonitorDescriptor = open(path, O_EVTONLY)
        guard desktopMonitorDescriptor != -1 else { return }
        
        desktopMonitorSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: desktopMonitorDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .userInitiated)
        )
        
        desktopMonitorSource?.setEventHandler { [weak self] in
            self?.checkDesktopForNewScreenshots()
        }
        
        desktopMonitorSource?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            close(self.desktopMonitorDescriptor)
            self.desktopMonitorDescriptor = -1
        }
        
        desktopMonitorSource?.resume()
    }
    
    private func stopDesktopMonitoring() {
        desktopMonitorSource?.cancel()
        desktopMonitorSource = nil
    }
    
    private func checkDesktopForNewScreenshots() {
        let screenshotURL = SettingsManager().screenshotDirectoryURL
        let path = screenshotURL.path
        
        guard let currentFiles = try? FileManager.default.contentsOfDirectory(atPath: path) else { return }
        let newFiles = Set(currentFiles).subtracting(seenDesktopFiles)
        seenDesktopFiles = Set(currentFiles)
        
        for file in newFiles {
            // macOS screenshot default names in English and common languages
            let lowerFile = file.lowercased()
            if lowerFile.starts(with: "screen shot") || lowerFile.starts(with: "screenshot") || lowerFile.starts(with: "截圖") || lowerFile.starts(with: "螢幕快照") {
                let fileURL = screenshotURL.appendingPathComponent(file)
                
                // Allow a tiny delay for the file write to finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.processScreenshotFile(at: fileURL)
                }
            }
        }
    }
    
    private func processScreenshotFile(at url: URL) {
        guard let image = NSImage(contentsOf: url),
              let tiffData = image.tiffRepresentation else { return }
        
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        var contentTitle = "[Screenshot \(width)x\(height)]"
        
        var finalData = tiffData
        if finalData.count > 5 * 1024 * 1024,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) {
            finalData = jpegData
            contentTitle += " (Compr)"
        }
        
        self.addItem(content: contentTitle, type: .image, imageData: finalData)
    }
    
    // MARK: - Clipboard Monitor
    
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
            
            // 2. Check for Images (More robust native NSImage extraction)
            if let images = self.pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], !images.isEmpty {
                let nsImage = images.first!
                var contentTitle = "[Image \(Int(nsImage.size.width))x\(Int(nsImage.size.height))]"
                
                // Convert NSImage to optimal data format
                guard let tiffData = nsImage.tiffRepresentation,
                      let bitmapRep = NSBitmapImageRep(data: tiffData) else { return }
                
                // Use generic TIFF or fallback to compressed JPEG if large
                var finalData = tiffData
                if finalData.count > 5 * 1024 * 1024,
                   let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) {
                    finalData = jpegData
                    contentTitle += " (Compr)"
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
