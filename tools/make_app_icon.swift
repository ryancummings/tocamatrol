// Draws the app icon: four Pop-Art comic keycaps with India-ink borders and offset shadows on
// a warm sunburst newsprint field with diagonal Ben-Day halftone dots.
// Run on a Mac: swift tools/make_app_icon.swift ios/Tocamatrol/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
// No alpha channel: the App Store rejects an icon with one.
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// 1. Warm sunburst comic canvas gradient (#FFF7D4 -> #FFE066)
let gradient = CGGradient(
    colorsSpace: space,
    colors: [color(0xFFE066), color(0xFFF7D4)] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: CGFloat(size)), options: [])

// 2. Staggered Ben-Day halftone dots
let dotStep: CGFloat = 56
let dotRadius: CGFloat = 10
context.setFillColor(color(0x151311, alpha: 0.085))
var row = 0
var yPos: CGFloat = 0
while yPos <= CGFloat(size) + dotStep {
    let xShift: CGFloat = row.isMultiple(of: 2) ? 0 : dotStep / 2
    var xPos: CGFloat = -dotStep + xShift
    while xPos <= CGFloat(size) + dotStep {
        context.fillEllipse(in: CGRect(x: xPos - dotRadius, y: yPos - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
        xPos += dotStep
    }
    yPos += dotStep
    row += 1
}

// 3. Four 2x2 Pop-Art comic keycaps with hard offset shadows, ink borders, and gloss highlights
let margin: CGFloat = 150
let gap: CGFloat = 62
let key = (CGFloat(size) - 2 * margin - gap) / 2
let radius: CGFloat = 68
let ink = color(0x151311)
let strokeWidth: CGFloat = 22
let shadowDX: CGFloat = 22
let shadowDY: CGFloat = -24 // Core Graphics counts y from bottom

// Top left, top right, bottom left, bottom right
let keys: [(CGFloat, CGFloat, UInt32, UInt32)] = [
    (margin, margin + key + gap, 0xFF564B, 0xE63229),        // Hero Vermilion
    (margin + key + gap, margin + key + gap, 0x45E3F7, 0x0FC5DE), // Electric Cyan
    (margin, margin, 0x4FE36E, 0x22C447),                    // Power Emerald
    (margin + key + gap, margin, 0x3D8DFF, 0x1B64F2),        // Hero Cobalt
]

for (x, y, topHex, botHex) in keys {
    let faceRect = CGRect(x: x, y: y, width: key, height: key)
    let shadowRect = faceRect.offsetBy(dx: shadowDX, dy: shadowDY)

    // Hard offset ink drop block
    context.setFillColor(ink)
    context.addPath(CGPath(roundedRect: shadowRect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()

    // Keycap gradient fill clipped to face rect
    let facePath = CGPath(roundedRect: faceRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.saveGState()
    context.addPath(facePath)
    context.clip()
    let capGrad = CGGradient(colorsSpace: space, colors: [color(botHex), color(topHex)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(capGrad, start: CGPoint(x: x, y: y), end: CGPoint(x: x, y: y + key), options: [])

    // Clean comic specular highlight bar across top inside edge
    let glossRect = CGRect(x: x + 38, y: y + key - 58, width: key - 76, height: 22)
    context.setFillColor(color(0xFFFFFF, alpha: 0.48))
    context.addPath(CGPath(roundedRect: glossRect, cornerWidth: 11, cornerHeight: 11, transform: nil))
    context.fillPath()
    context.restoreGState()

    // Crisp India-ink keyline
    context.setStrokeColor(ink)
    context.setLineWidth(strokeWidth)
    context.addPath(facePath)
    context.strokePath()
}

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
