import Cocoa

let pb = NSPasteboard.general
print("Count: \(pb.changeCount)")
if let str = pb.string(forType: .string) {
    print("Content: \(str)")
}
