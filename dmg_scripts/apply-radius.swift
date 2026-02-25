import Cocoa

if CommandLine.arguments.count < 3 {
    print("Usage: swift apply-radius.swift <input> <output>")
    exit(1)
}

let inPath = CommandLine.arguments[1]
let outPath = CommandLine.arguments[2]

guard let image = NSImage(contentsOfFile: inPath) else {
    print("Could not load image at \(inPath)")
    exit(1)
}

let size = NSSize(width: 512, height: 512)
let newImage = NSImage(size: size)
newImage.lockFocus()

let radius = size.width * 0.225
let path = NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: radius, yRadius: radius)
path.addClip()

image.draw(in: NSRect(origin: .zero, size: size))

newImage.unlockFocus()

guard let tiff = newImage.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let pngData = rep.representation(using: .png, properties: [:]) else {
    print("Could not generate PNG data")
    exit(1)
}

try! pngData.write(to: URL(fileURLWithPath: outPath))
print("Saved \(outPath)")
