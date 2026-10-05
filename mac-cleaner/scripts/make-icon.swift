// Dessine l'icône de l'app (1024 × 1024) : usage `swift scripts/make-icon.swift sortie.png`
import AppKit

let side: CGFloat = 1024
let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()

let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.09, green: 0.78, blue: 0.80, alpha: 1),
    NSColor(calibratedRed: 0.16, green: 0.36, blue: 0.96, alpha: 1),
])
gradient?.draw(in: tile, angle: -90)

let configuration = NSImage.SymbolConfiguration(pointSize: 440, weight: .semibold)
if let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
    .withSymbolConfiguration(configuration) {
    let white = NSImage(size: symbol.size, flipped: false) { rect in
        symbol.draw(in: rect)
        NSColor.white.set()
        rect.fill(using: .sourceAtop)
        return true
    }
    let size = white.size
    white.draw(in: NSRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height))
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Impossible de générer l'icône")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
