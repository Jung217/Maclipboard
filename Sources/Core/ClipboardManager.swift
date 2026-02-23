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
        
        guard let app = previousApp else {
            // No previous app tracked — just hide the panel and copy to clipboard only
            NotificationCenter.default.post(name: NSNotification.Name("HidePanel"), object: nil)
            return
        }

        // Step 1: Hide our panel
        NotificationCenter.default.post(name: NSNotification.Name("HidePanel"), object: nil)

        // Step 2: Activate the previous app to restore its focus
        app.activate(options: .activateIgnoringOtherApps)

        // Step 3: Wait long enough for macOS to finish the app switch, then paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let vKeyCode: CGKeyCode = 0x09 // 'v'
            let cmdKeyCode: CGKeyCode = 0x37 // Command
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }
            
            let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: cmdKeyCode, keyDown: true)
            let vDown = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true)
            vDown?.flags = .maskCommand
            let vUp = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false)
            vUp?.flags = .maskCommand
            let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: cmdKeyCode, keyDown: false)
            
            cmdDown?.post(tap: .cghidEventTap)
            vDown?.post(tap: .cghidEventTap)
            vUp?.post(tap: .cghidEventTap)
            cmdUp?.post(tap: .cghidEventTap)
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
