import Cocoa
import Combine

class ClipboardManager: ObservableObject {
    @Published var history: [ClipboardItem] = []
    var previousApp: NSRunningApplication?
    
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    
    // 100 items limit to prevent excessive memory/storage usage
    private let historyLimit = 100
    
    init() {
        self.lastChangeCount = pasteboard.changeCount
        loadHistory()
        startMonitoring()
    }
    
    func startMonitoring() {
        // Poll every 0.5 seconds for clipboard changes
        timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForChanges() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        print("Clipboard changed. count:", pasteboard.changeCount)
        lastChangeCount = pasteboard.changeCount
        
        // We only support plain text for now, but could be extended to rich text/images.
        if let newString = pasteboard.string(forType: .string) {
            let cleanString = newString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanString.isEmpty else { 
                print("String is empty")
                return 
            }
            
            DispatchQueue.main.async {
                print("Adding: \(cleanString.prefix(20))")
                self.addItem(content: cleanString)
            }
        } else {
            print("No string found in pasteboard.")
        }
    }
    
    func addItem(content: String) {
        let wasPinned = history.first(where: { $0.content == content })?.isPinned ?? false
        
        // Remove existing item with same content fully, so it will shift to top
        history.removeAll { $0.content == content }
        
        var item = ClipboardItem(content: content, timestamp: Date())
        item.isPinned = wasPinned
        history.insert(item, at: 0)
        
        // Enforce limit, keeping pinned items safe
        if history.count > historyLimit {
            let unpinnedIndexes = history.indices.filter { !history[$0].isPinned }
            // Only drop unpinned items from the tail
            if let lastUnpinned = unpinnedIndexes.last {
                history.remove(at: lastUnpinned)
            }
        }
        
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
        let success = pasteboard.setString(item.content, forType: .string)
        if !success {
            print("ERROR: Failed to write to pasteboard")
        }
        // Manually update lastChangeCount so we don't pick it up as a new item immediately
        lastChangeCount = pasteboard.changeCount
    }
    
    func copyAndPaste(item: ClipboardItem) {
        copyToClipboard(item: item)

        guard AXIsProcessTrusted() else {
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
                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }

        // Close panel but DO NOT call NSApplication.shared.hide(nil)
        // because hide() conflicts with explicitly activating another app.
        NotificationCenter.default.post(name: NSNotification.Name("HidePanel"), object: nil)

        // Force focus back to the target app using an AppleScript workaround,
        // which often bypasses WindowServer focus-stealing prevention better
        // than NSRunningApplication.activate() for LSUIElement apps.
        if let targetApp = previousApp, let appURL = targetApp.bundleURL {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, _ in
                // Once the app is opened/activated, post the keystroke
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    let vKeyCode: CGKeyCode = 0x09
                    let cmdKeyCode: CGKeyCode = 0x37
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
            }
        }
    }
    
    func clearUnpinnedHistory() {
        history.removeAll(where: { !$0.isPinned })
        saveHistory()
    }
    
    // MARK: - Persistence
    private var storageURL: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("Maclipboard")
        
        if !FileManager.default.fileExists(atPath: appSupport.path) {
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        return appSupport.appendingPathComponent("history.json")
    }
    
    private func saveHistory() {
        do {
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
