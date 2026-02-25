import Cocoa

let width: CGFloat = 500
let height: CGFloat = 300

let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

// Fill background with white
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

// Draw an arrow pointing from the App to the Applications folder
let arrowPath = NSBezierPath()
let startX: CGFloat = 190
let endX: CGFloat = 310
let y: CGFloat = 200 // Centered vertically with the icons (300 - 100 = 200)

arrowPath.move(to: NSPoint(x: startX, y: y))
arrowPath.line(to: NSPoint(x: endX, y: y))
arrowPath.lineWidth = 3.0

// Draw arrowhead
arrowPath.move(to: NSPoint(x: endX - 12, y: y + 8))
arrowPath.line(to: NSPoint(x: endX, y: y))
arrowPath.line(to: NSPoint(x: endX - 12, y: y - 8))

NSColor.systemGray.setStroke()
arrowPath.stroke()

// Add subtle instructions text (optional, but a nice touch)
let text = "Drag to Install" as NSString
let font = NSFont.systemFont(ofSize: 13, weight: .regular)
let textColor = NSColor.systemGray
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: textColor
]
let textSize = text.size(withAttributes: attributes)
text.draw(at: NSPoint(x: (width - textSize.width) / 2, y: y - 40), withAttributes: attributes)

image.unlockFocus()

guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to generate PNG data")
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg_background.png"
let url = URL(fileURLWithPath: outputPath)
try? pngData.write(to: url)
