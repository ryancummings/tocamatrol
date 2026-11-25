// Draws the app icon: four rounded macro keycaps on a dark field.
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

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

context.setFillColor(color(0x17171C))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

let margin: CGFloat = 170
let gap: CGFloat = 56
let key = (CGFloat(size) - 2 * margin - gap) / 2
// Top left, top right, bottom left, bottom right (Core Graphics counts y from the bottom).
let keys: [(CGFloat, CGFloat, UInt32)] = [
    (margin, margin + key + gap, 0xF4A259),        // amber key
    (margin + key + gap, margin + key + gap, 0x8EB8E5), // blue key
    (margin, margin, 0xB9DDB0),                    // green key
    (margin + key + gap, margin, 0xE8D27A),        // sand key
]
for (x, y, hex) in keys {
    context.setFillColor(color(hex))
    context.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: key, height: key),
                           cornerWidth: 64, cornerHeight: 64, transform: nil))
    context.fillPath()
}

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
