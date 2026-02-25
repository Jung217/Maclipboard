import Cocoa

if CommandLine.arguments.count < 3 {
    print("Usage: swift set-icon.swift <sourcePath> <targetPath>")
    exit(1)
}

let sourcePath = CommandLine.arguments[1]
let targetPath = CommandLine.arguments[2]

let icon = NSWorkspace.shared.icon(forFile: sourcePath)
let success = NSWorkspace.shared.setIcon(icon, forFile: targetPath, options: [])

if success {
    print("Successfully set icon on \(targetPath)")
} else {
    print("Failed to set icon on \(targetPath)")
    exit(1)
}
