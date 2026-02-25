import Cocoa

if CommandLine.arguments.count < 3 {
    print("Usage: swift make-alias.swift <targetPath> <aliasPath>")
    exit(1)
}

let targetPath = CommandLine.arguments[1]
let aliasPath = CommandLine.arguments[2]

let targetUrl = URL(fileURLWithPath: targetPath)
let aliasUrl = URL(fileURLWithPath: aliasPath)

do {
    let bookmarkData = try targetUrl.bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
    try URL.writeBookmarkData(bookmarkData, to: aliasUrl)
    print("Alias created successfully at \(aliasPath)")
    
    // Now get the icon and set it
    let icon = NSWorkspace.shared.icon(forFile: targetPath)
    // We must use a separate script or NSWorkspace extension to set icon on the ALIAS file itself vs resolving it.
    // Actually, NSWorkspace.shared.setIcon modifies the file at the path. 
    // IF it's an alias, does it resolve? Let's check:
    let success = NSWorkspace.shared.setIcon(icon, forFile: aliasPath, options: [])
    if success {
        print("Icon set successfully")
    } else {
        print("Failed to set icon")
    }
} catch {
    print("Error: \(error)")
    exit(1)
}
