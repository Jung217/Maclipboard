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
        
        guard let newString = pasteboard.string(forType: .string) else { return }
        
        let cleanString = newString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanString.isEmpty else { return }
        
        DispatchQueue.main.async {
            self.addItem(content: cleanString)
        }
    }
    
    func addItem(content: String) {
        let wasPinned = history.first(where: { $0.content == content })?.isPinned ?? false
        
        history.removeAll { $0.content == content }
        
        var item = ClipboardItem(content: content, timestamp: Date())
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
        pasteboard.setString(item.content, forType: .string)
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
