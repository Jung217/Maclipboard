import Cocoa
import Carbon

class HotkeyManager {
    static let shared = HotkeyManager()
    
    var action: (() -> Void)?
    var capturedApp: NSRunningApplication?

    private init() {}
    
    func registerCmdShiftV() {
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
        
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, nil)
        
        let hotKeyID = EventHotKeyID(signature: 1, id: 1)
        var hotKeyRef: EventHotKeyRef?
        
        // kVK_ANSI_V = 0x09 (9)
        // cmdKey = 0x0100 (256)
        // shiftKey = 0x0200 (512)
        RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(cmdKey | shiftKey), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
