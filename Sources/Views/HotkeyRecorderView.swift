import SwiftUI
import Carbon

struct GlobalHotkey: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt32
    
    var stringRepresentation: String {
        var str = ""
        if (modifiers & UInt32(controlKey)) != 0 { str += "⌃ " }
        if (modifiers & UInt32(optionKey)) != 0 { str += "⌥ " }
        if (modifiers & UInt32(shiftKey)) != 0 { str += "⇧ " }
        if (modifiers & UInt32(cmdKey)) != 0 { str += "⌘ " }
        
        // Very basic mapping for common keys
        switch Int(keyCode) {
        case kVK_ANSI_A: str += "A"
        case kVK_ANSI_B: str += "B"
        case kVK_ANSI_C: str += "C"
        case kVK_ANSI_D: str += "D"
        case kVK_ANSI_E: str += "E"
        case kVK_ANSI_F: str += "F"
        case kVK_ANSI_G: str += "G"
        case kVK_ANSI_H: str += "H"
        case kVK_ANSI_I: str += "I"
        case kVK_ANSI_J: str += "J"
        case kVK_ANSI_K: str += "K"
        case kVK_ANSI_L: str += "L"
        case kVK_ANSI_M: str += "M"
        case kVK_ANSI_N: str += "N"
        case kVK_ANSI_O: str += "O"
        case kVK_ANSI_P: str += "P"
        case kVK_ANSI_Q: str += "Q"
        case kVK_ANSI_R: str += "R"
        case kVK_ANSI_S: str += "S"
        case kVK_ANSI_T: str += "T"
        case kVK_ANSI_U: str += "U"
        case kVK_ANSI_V: str += "V"
        case kVK_ANSI_W: str += "W"
        case kVK_ANSI_X: str += "X"
        case kVK_ANSI_Y: str += "Y"
        case kVK_ANSI_Z: str += "Z"
        case kVK_ANSI_0: str += "0"
        case kVK_ANSI_1: str += "1"
        case kVK_ANSI_2: str += "2"
        case kVK_ANSI_3: str += "3"
        case kVK_ANSI_4: str += "4"
        case kVK_ANSI_5: str += "5"
        case kVK_ANSI_6: str += "6"
        case kVK_ANSI_7: str += "7"
        case kVK_ANSI_8: str += "8"
        case kVK_ANSI_9: str += "9"
        case kVK_Space: str += "Space"
        case kVK_Return: str += "Return"
        default: str += "Key (\(keyCode))"
        }
        
        return str.trimmingCharacters(in: .whitespaces)
    }
}

// macOS intercepts key events before SwiftUI when using Hotkeys, 
// so we need an NSViewRepresentable to capture all raw keystrokes cleanly.
struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var hotkey: GlobalHotkey
    @Binding var isRecording: Bool
    
    func makeNSView(context: Context) -> CustomKeyView {
        let view = CustomKeyView()
        view.onKeyPress = { keyCode, modifiers in
            self.hotkey = GlobalHotkey(keyCode: keyCode, modifiers: modifiers)
            self.isRecording = false
        }
        view.isRecording = isRecording
        return view
    }
    
    func updateNSView(_ nsView: CustomKeyView, context: Context) {
        nsView.isRecording = isRecording
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

class CustomKeyView: NSView {
    var onKeyPress: ((UInt16, UInt32) -> Void)?
    var isRecording = false
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if !isRecording {
            super.keyDown(with: event)
            return
        }
        
        let keyCode = event.keyCode
        
        // Map NSEvent.modifierFlags to Carbon Modifiers
        var carbonModifiers: UInt32 = 0
        if event.modifierFlags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if event.modifierFlags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if event.modifierFlags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        
        // Ignore if it's JUST a modifier key
        let isJustModifier = [kVK_Shift, kVK_RightShift, kVK_Command, kVK_RightCommand, kVK_Option, kVK_RightOption, kVK_Control, kVK_RightControl].contains(Int(keyCode))
        
        if !isJustModifier {
            onKeyPress?(keyCode, carbonModifiers)
        }
    }
}
