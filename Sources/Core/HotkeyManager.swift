import Cocoa
import Carbon

class HotkeyManager {
    static let shared = HotkeyManager()
    
    var action: (() -> Void)?
    var capturedApp: NSRunningApplication?
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}
    
    func registerGlobalHotkey() {
        if let currentRef = hotKeyRef {
            UnregisterEventHotKey(currentRef)
            hotKeyRef = nil
        }
        if let currentHandler = eventHandlerRef {
            RemoveEventHandler(currentHandler)
            eventHandlerRef = nil
        }
        
        let defaultKeyCode: Int = 9 // kVK_ANSI_V
        let defaultModifiers: Int = 4096 // controlKey
        
        let keyCode = UserDefaults.standard.object(forKey: "globalHotkeyKeyCode") as? Int ?? defaultKeyCode
        let modifiers = UserDefaults.standard.object(forKey: "globalHotkeyModifiers") as? Int ?? defaultModifiers
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { (_, _, _) -> OSStatus in
            // Capture frontmost app NOW before our app steals focus
            let prevApp = NSWorkspace.shared.frontmostApplication
            DispatchQueue.main.async {
                HotkeyManager.shared.capturedApp = prevApp
                HotkeyManager.shared.action?()
            }
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandlerRef)
        
        let hotKeyID = EventHotKeyID(signature: 1, id: 1)
        
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
