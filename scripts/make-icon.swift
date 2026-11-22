// Génère l'icône de SuiviAuto (1024 × 1024) : voiture blanche sur fond dégradé,
// pastille orange « clé » en relief.
// Usage : swift scripts/make-icon.swift <sortie.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Grille macOS : carré arrondi de 824 px centré, avec ombre portée.
let inset: CGFloat = 100
let tile = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let radius: CGFloat = 185
let tilePath = CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
ctx.addPath(tilePath)
ctx.setFillColor(NSColor.black.cgColor)
ctx.fillPath()
ctx.restoreGState()

// Fond dégradé bleu → turquoise.
ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [NSColor(srgbRed: 0.09, green: 0.36, blue: 0.62, alpha: 1).cgColor,
                             NSColor(srgbRed: 0.09, green: 0.75, blue: 0.73, alpha: 1).cgColor] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: tile.minX, y: tile.maxY), end: CGPoint(x: tile.maxX, y: tile.minY), options: [])

// Reflet en haut pour l'effet de relief.
let gloss = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                       colors: [NSColor.white.withAlphaComponent(0.16).cgColor,
                                NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                       locations: [0, 1])!
ctx.drawLinearGradient(gloss, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.midY), options: [])

// Route stylisée.
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.22).cgColor)
ctx.setLineWidth(18)
ctx.setLineDash(phase: 0, lengths: [60, 40])
ctx.move(to: CGPoint(x: tile.minX + 40, y: tile.minY + 262))
ctx.addLine(to: CGPoint(x: tile.maxX - 40, y: tile.minY + 262))
ctx.strokePath()
ctx.restoreGState()

// Dessine un symbole SF en blanc, avec ombre, dans un rectangle donné.
func drawSymbol(_ name: String, in rect: CGRect, color: NSColor, shadowAlpha: CGFloat) {
    let config = NSImage.SymbolConfiguration(pointSize: rect.height, weight: .bold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
    guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { fatalError("symbole \(name) introuvable") }
    let s = symbol.size
    let scale = min(rect.width / s.width, rect.height / s.height)
    let target = CGRect(x: rect.midX - s.width * scale / 2, y: rect.midY - s.height * scale / 2,
                        width: s.width * scale, height: s.height * scale)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 18, color: NSColor.black.withAlphaComponent(shadowAlpha).cgColor)
    symbol.draw(in: target)
    ctx.restoreGState()
}

// Voiture.
drawSymbol("car.side.fill", in: CGRect(x: tile.minX + 90, y: tile.minY + 250, width: tile.width - 180, height: 360),
           color: .white, shadowAlpha: 0.35)

// Pastille orange en relief avec une clé.
let badge = CGRect(x: tile.maxX - 330, y: tile.maxY - 330, width: 270, height: 270)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 22, color: NSColor.black.withAlphaComponent(0.4).cgColor)
ctx.addEllipse(in: badge)
ctx.setFillColor(NSColor.black.cgColor)
ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addEllipse(in: badge)
ctx.clip()
let orange = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: [NSColor(srgbRed: 1.0, green: 0.72, blue: 0.20, alpha: 1).cgColor,
                                 NSColor(srgbRed: 0.93, green: 0.40, blue: 0.10, alpha: 1).cgColor] as CFArray,
                        locations: [0, 1])!
ctx.drawLinearGradient(orange, start: CGPoint(x: badge.midX, y: badge.maxY), end: CGPoint(x: badge.midX, y: badge.minY), options: [])
ctx.restoreGState()
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
ctx.setLineWidth(12)
ctx.strokeEllipse(in: badge.insetBy(dx: 6, dy: 6))
drawSymbol("wrench.adjustable.fill", in: badge.insetBy(dx: 62, dy: 62), color: .white, shadowAlpha: 0.25)

image.unlockFocus()

guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError("encodage PNG impossible") }
try png.write(to: URL(fileURLWithPath: out))
print("Icône écrite : \(out)")
