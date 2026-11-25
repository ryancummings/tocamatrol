import SwiftUI
import TocaCore
import UIKit

/// Ink & Pop comic-book design tokens: Bright Newsprint in light mode, Dark Electric Comic in
/// dark mode, with India-ink borders, hard offset drop blocks, halftone dots, and vibrant keys.
enum Theme {
    static let ground = Color.adaptive(light: 0xFFF6DF, dark: 0x10152B)
    static let well = Color.adaptive(light: 0xF4E6C3, dark: 0x0A0E1F)
    static let surface = Color.adaptive(light: 0xFFFDF7, dark: 0x182042)
    static let raised = Color.adaptive(light: 0xFFE885, dark: 0x243061)

    static let inkBorder = Color.adaptive(light: 0x151311, dark: 0x7A93E6)
    static let inkShadow = Color.adaptive(light: 0x151311, dark: 0x050712)
    static let hairline = Color.adaptive(light: 0xD8C7A0, dark: 0x2D3B73)
    static let strongBorder = inkBorder

    static let text = Color.adaptive(light: 0x151311, dark: 0xF7F5EE)
    static let muted = Color.adaptive(light: 0x473F35, dark: 0xB7C4E6)
    static let dim = Color.adaptive(light: 0x655B4E, dark: 0x8899C4)

    static let tint = Color.adaptive(light: 0x0F52EB, dark: 0x38E4FF)
    static let popYellow = Color(hex: 0xFFD21F)
    static let popInk = Color(hex: 0x151311)

    static let amber = Color.adaptive(light: 0xFF7A14, dark: 0xFF9F2E)
    static let highlightLabel = Color.adaptive(light: 0xA83200, dark: 0xFFD21F)
    static let amberLabel = highlightLabel
    static let green = Color.adaptive(light: 0x0B8A40, dark: 0x2EE87A)
    static let red = Color.adaptive(light: 0xD11B1B, dark: 0xFF4D6A)

    static let halftone = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x56 / 255, green: 0xA8 / 255, blue: 1, alpha: 0.09)
            : UIColor(red: 0x15 / 255, green: 0x13 / 255, blue: 0x11 / 255, alpha: 0.055)
    })

    /// Corner radius of comic panels, chips, and controls.
    static let radius: CGFloat = 10

    static var padSpacing: CGFloat { ScreenMetrics.isPad ? 10 : 8 }
    static var margin: CGFloat { ScreenMetrics.isPad ? 24 : 12 }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat(hex >> 16 & 0xFF) / 255,
            green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

/// Subtle staggered Ben-Day comic halftone dots drawn over the canvas background.
struct HalftoneBackground: View {
    var spacing: CGFloat = 14
    var dotRadius: CGFloat = 1.35

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / spacing)) + 1
            let rows = Int(ceil(size.height / spacing)) + 1
            let diameter = dotRadius * 2
            var path = Path()
            for r in 0..<rows {
                let xOffset: CGFloat = r.isMultiple(of: 2) ? 0 : spacing / 2
                let y = CGFloat(r) * spacing
                for c in 0..<cols {
                    let x = CGFloat(c) * spacing + xOffset
                    path.addEllipse(in: CGRect(x: x - dotRadius, y: y - dotRadius, width: diameter, height: diameter))
                }
            }
            context.fill(path, with: .color(Theme.halftone))
        }
        .allowsHitTesting(false)
    }
}

/// A Pop-Art comic keycap style: ink border, solid offset shadow, top-to-bottom cap face, pressed
/// highlight, and high-contrast label color.
struct KeyStyle {
    let border: Color
    let shadow: Color
    let top: Color
    let bottom: Color
    let pressedTop: Color
    let label: Color

    static let inkBorder = Color.adaptive(light: 0x151311, dark: 0x090D1C)
    static let inkShadow = Color.adaptive(light: 0x151311, dark: 0x04060E)

    static let sand = KeyStyle(
        border: inkBorder, shadow: inkShadow,
        top: Color.adaptive(light: 0xFFE45E, dark: 0xF5CE2E),
        bottom: Color.adaptive(light: 0xFFD21F, dark: 0xDAA908),
        pressedTop: Color.adaptive(light: 0xFFF099, dark: 0xFFE059),
        label: Color.adaptive(light: 0x151311, dark: 0x12100E)
    )
    static let amber = KeyStyle(
        border: inkBorder, shadow: inkShadow,
        top: Color.adaptive(light: 0xFF9E3D, dark: 0xFF9429),
        bottom: Color.adaptive(light: 0xFF7315, dark: 0xE66300),
        pressedTop: Color.adaptive(light: 0xFFB86C, dark: 0xFFAD52),
        label: Color.adaptive(light: 0x151311, dark: 0x12100E)
    )
    static let rust = KeyStyle(
        border: inkBorder, shadow: inkShadow,
        top: Color.adaptive(light: 0xDF2920, dark: 0xDE2B2B),
        bottom: Color.adaptive(light: 0xC41D15, dark: 0xBF1E2E),
        pressedTop: Color.adaptive(light: 0xF0443B, dark: 0xEE4646),
        label: .white
    )
    static let rose = KeyStyle(
        border: inkBorder, shadow: inkShadow,
        top: Color.adaptive(light: 0xCC1B6E, dark: 0xD11B76),
        bottom: Color.adaptive(light: 0xAD135B, dark: 0xB31263),
        pressedTop: Color.adaptive(light: 0xE03182, dark: 0xE3348C),
        label: .white
    )
    static let violet = KeyStyle(
        border: inkBorder, shadow: inkShadow,
        top: Color.adaptive(light: 0x6F38E6, dark: 0x6D36E8),
        bottom: Color.adaptive(light: 0x5823C9, dark: 0x5622CC),
        pressedTop: Color.adaptive(light: 0x8452F2, dark: 0x824FF2),
        label: .white
    )
    static let blue = KeyStyle(
        border: inkBorder, shadow: inkShadow,
        top: Color.adaptive(light: 0x1A5BE0, dark: 0x1D5CE0),
        bottom: Color.adaptive(light: 0x1145B8, dark: 0x1448BA),
        pressedTop: Color.adaptive(light: 0x3070ED, dark: 0x3372ED),
        label: .white
    )
    static let teal = KeyStyle(
        border: inkBorder, shadow: inkShadow,
        top: Color.adaptive(light: 0x45E3F7, dark: 0x33DCF2),
        bottom: Color.adaptive(light: 0x0FC5DE, dark: 0x0BB2C9),
        pressedTop: Color.adaptive(light: 0x7CEDFC, dark: 0x66E7F7),
        label: Color.adaptive(light: 0x151311, dark: 0x10131F)
    )
    static let green = KeyStyle(
        border: inkBorder, shadow: inkShadow,
        top: Color.adaptive(light: 0x4FE36E, dark: 0x42DB63),
        bottom: Color.adaptive(light: 0x22C447, dark: 0x19B03C),
        pressedTop: Color.adaptive(light: 0x7AEC92, dark: 0x6EE688),
        label: Color.adaptive(light: 0x151311, dark: 0x10131F)
    )
    static let graphite = KeyStyle(
        border: Theme.inkBorder, shadow: inkShadow,
        top: Color.adaptive(light: 0xFFFFFF, dark: 0x2E3B70),
        bottom: Color.adaptive(light: 0xEFE8D6, dark: 0x202A52),
        pressedTop: Color.adaptive(light: 0xFFF2AE, dark: 0x3E4E91),
        label: Color.adaptive(light: 0x151311, dark: 0xF7F5EE)
    )
    static let keyboardLetter = KeyStyle(
        border: Theme.inkBorder, shadow: inkShadow,
        top: Color.adaptive(light: 0xFFFFFF, dark: 0x25305E),
        bottom: Color.adaptive(light: 0xF5EFE0, dark: 0x1C254A),
        pressedTop: Color.adaptive(light: 0xFFE885, dark: 0x38488A),
        label: Color.adaptive(light: 0x151311, dark: 0xF7F5EE)
    )

    static func tint(_ tint: ButtonAppearance.Tint) -> KeyStyle {
        switch tint {
        case .sand: .sand
        case .amber: .amber
        case .rust: .rust
        case .rose: .rose
        case .violet: .violet
        case .blue: .blue
        case .teal: .teal
        case .green: .green
        case .graphite: .graphite
        }
    }
}

extension ButtonAppearance.Tint {
    var name: String { rawValue.capitalized }
}

extension ButtonAppearance.Typeface {
    var design: Font.Design {
        switch self {
        case .standard: .default
        case .rounded: .rounded
        case .serif: .serif
        case .mono: .monospaced
        }
    }

    var name: String {
        switch self {
        case .standard: "Standard"
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .mono: "Mono"
        }
    }
}

extension ButtonAppearance.TextSize {
    /// Times the usual label size.
    var factor: CGFloat {
        switch self {
        case .small: 0.82
        case .medium: 1
        case .large: 1.22
        }
    }

    var shortName: String {
        switch self {
        case .small: "S"
        case .medium: "M"
        case .large: "L"
        }
    }
}

/// A tactile comic keycap: crisp face floating over a solid hard-offset ink shadow. Pressing slams
/// the face flush onto its shadow within its own layout frame.
struct Keycap<Label: View>: View {
    let style: KeyStyle
    let pressed: Bool
    /// Active indicator badge in the top corner while pressed or while a macro plays.
    var lit = false
    /// Crisp playing ring around the keycap.
    var ringed = false
    /// Room between the cap's edge and the label; small keys take less.
    var labelPadding: CGFloat = 6
    @ViewBuilder let label: () -> Label
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let sunk = pressed
        let radius: CGFloat = 10
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(style.shadow)
                .padding(.leading, 3)
                .padding(.top, 4)

            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [sunk ? style.pressedTop : style.top, style.bottom],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.45), .clear],
                                                     startPoint: .top, endPoint: .center), lineWidth: 2)
                        .padding(1)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(style.border, lineWidth: 2.5)
                }
                .overlay {
                    if ringed {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Theme.popYellow, lineWidth: 3)
                            .padding(2)
                    }
                }
                .overlay {
                    label()
                        .foregroundStyle(style.label)
                        .padding(.horizontal, labelPadding)
                        .padding(.vertical, labelPadding * 2 / 3)
                }
                .overlay(alignment: .topTrailing) {
                    if lit || sunk {
                        Circle()
                            .fill(Theme.popYellow)
                            .overlay { Circle().strokeBorder(Theme.popInk, lineWidth: 1.5) }
                            .frame(width: 9, height: 9)
                            .padding(6)
                    }
                }
                .padding(.leading, sunk ? 3 : 0)
                .padding(.top, sunk ? 4 : 0)
                .padding(.trailing, sunk ? 0 : 3)
                .padding(.bottom, sunk ? 0 : 4)
        }
        .animation(reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.06), value: sunk)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// An empty slot on a page: recessed comic blueprint well with dashed ink outline.
struct Socket: View {
    var addable = false
    var highlighted = false

    var body: some View {
        let radius: CGFloat = 10
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Theme.well)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        highlighted ? Theme.tint : Theme.dim.opacity(0.55),
                        style: StrokeStyle(lineWidth: highlighted ? 2.5 : 1.75, dash: highlighted ? [] : [6, 5])
                    )
            }
            .overlay {
                if addable || highlighted {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(highlighted ? Theme.tint : Theme.muted.opacity(0.65))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A key's label: bold name sized cleanly to the key, with optional secondary caption lines.
struct KeyLabel: View {
    let title: String
    var details: [String] = []
    var scale: CGFloat = 1
    var design: Font.Design = .default

    var body: some View {
        GeometryReader { geometry in
            let base = (ScreenMetrics.isPad ? 20 : 16) * scale
            let size = KeyLabel.fittingSize(title, base: base, width: geometry.size.width - 4, design: design)
            let detailSize = max(10, min(size * 0.68, ScreenMetrics.isPad ? 13 : 11.5) * min(scale, 1.2))
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: size, weight: .bold, design: design))
                    .tracking(-0.3)
                    .lineLimit(scale > 1.3 ? 3 : 2)
                    .minimumScaleFactor(0.8)
                ForEach(details, id: \.self) { detail in
                    Text(detail)
                        .font(.system(size: detailSize, weight: .semibold, design: .monospaced))
                        .opacity(0.82)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
            .multilineTextAlignment(.center)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    /// The largest size up to `base` at which the longest word fits `width`, so text wraps only
    /// between words.
    static func fittingSize(_ text: String, base: CGFloat, width: CGFloat, design: Font.Design = .default) -> CGFloat {
        var font = UIFont.systemFont(ofSize: base, weight: .bold)
        let uiDesign: UIFontDescriptor.SystemDesign? = switch design {
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        default: nil
        }
        if let uiDesign, let descriptor = font.fontDescriptor.withDesign(uiDesign) {
            font = UIFont(descriptor: descriptor, size: base)
        }
        let widest = text.split(whereSeparator: \.isWhitespace)
            .map { ($0 as Substring).description.size(withAttributes: [.font: font]).width }
            .max() ?? 0
        guard widest > width, widest > 0 else { return base }
        return max(9, (base * width / widest).rounded(.down))
    }
}

/// A small bold comic stamp tag: "2×", "INSTANT".
struct MonoTag: View {
    let text: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.system(size: 10, weight: .black, design: .rounded))
        .tracking(0.8)
        .textCase(.uppercase)
        .foregroundStyle(Theme.popInk)
        .lineLimit(1)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Theme.popYellow, in: Capsule())
        .overlay { Capsule().strokeBorder(Theme.popInk, lineWidth: 1.5) }
    }
}

/// Comic segmented bar: crisp ink border, hard offset shadow, selected segment in Sunburst Yellow.
struct ConsoleSegmented<Value: Hashable, Segment: View>: View {
    let options: [Value]
    @Binding var selection: Value
    var height: CGFloat = 34
    /// Options it would be wrong to pick now show dimmed and do nothing.
    var isEnabled: (Value) -> Bool = { _ in true }
    @ViewBuilder let segment: (Value) -> Segment

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                let enabled = on || isEnabled(option)
                Button {
                    selection = option
                } label: {
                    segment(option)
                        .font(.system(size: height > 34 ? 14 : 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .foregroundStyle(on ? Theme.popInk : Theme.muted)
                        .padding(.horizontal, 10)
                        .frame(minWidth: 36, maxHeight: .infinity)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Theme.popYellow)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .strokeBorder(Theme.popInk, lineWidth: 1.5)
                                    }
                            }
                        }
                        .contentShape(Rectangle())
                        .opacity(enabled ? 1 : 0.35)
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .frame(height: height)
        .background {
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .fill(Theme.surface)
                .shadow(color: Theme.inkShadow, radius: 0, x: 2, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(Theme.inkBorder, lineWidth: 2)
        }
        .padding(.trailing, 2)
        .padding(.bottom, 2)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Tactile comic tile button: ink border, solid offset shadow that slams flat on touch.
struct ConsoleTileButtonStyle: ButtonStyle {
    var size: CGFloat = 34
    var active = false
    var fullWidth = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = isEnabled && configuration.isPressed
        let fill: Color = !isEnabled
            ? Theme.well
            : active
                ? (pressed ? Color(hex: 0xFFE885) : Theme.popYellow)
                : (pressed ? Theme.raised : Theme.surface)
        let fg: Color = !isEnabled ? Theme.dim : active ? Theme.popInk : Theme.text
        let stroke: Color = !isEnabled ? Theme.hairline : active ? Theme.popInk : Theme.inkBorder

        configuration.label
            .font(.system(size: size > 34 ? 16 : 14, weight: .bold, design: .rounded))
            .foregroundStyle(fg)
            .frame(minWidth: size, maxWidth: fullWidth ? .infinity : nil, minHeight: size)
            .padding(.horizontal, active ? 12 : 4)
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: isEnabled ? 2 : 1.5)
            }
            .background {
                if isEnabled {
                    RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                        .fill(Theme.inkShadow)
                        .offset(x: pressed ? 0 : 2, y: pressed ? 0 : 2)
                }
            }
            .offset(x: pressed ? 2 : 0, y: pressed ? 2 : 0)
            .padding(.trailing, 2)
            .padding(.bottom, 2)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.06), value: pressed)
    }
}

extension View {
    /// Crisp comic card panel with bold ink outline and solid offset shadow.
    func comicPanel(fill: Color = Theme.surface, cornerRadius: CGFloat = 12, borderWidth: CGFloat = 2,
                    shadowOffset: CGFloat = 3) -> some View {
        background {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.inkShadow)
                    .offset(x: shadowOffset, y: shadowOffset)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Theme.inkBorder, lineWidth: borderWidth)
        }
        .padding(.trailing, shadowOffset)
        .padding(.bottom, shadowOffset)
    }

    /// A list or form on the comic canvas. Its sections take `consoleRows()`.
    func consoleForm() -> some View {
        scrollContentBackground(.hidden)
            .background {
                ZStack {
                    Theme.ground.ignoresSafeArea()
                    HalftoneBackground().ignoresSafeArea()
                }
            }
    }

    /// A list section's rows on the comic surface.
    func consoleRows() -> some View {
        listRowBackground(Theme.surface)
            .listRowSeparatorTint(Theme.hairline)
    }
}
