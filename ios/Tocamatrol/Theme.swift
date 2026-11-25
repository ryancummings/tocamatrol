import SwiftUI
import TocaCore
import UIKit

/// The console look: warm near-black hardware neutrals, one amber accent for selection and
/// focus, monospaced data, and tactile keycaps. Every screen takes its colours from here.
enum Theme {
    static let ground = Color(hex: 0x0A0805)
    static let well = Color(hex: 0x100E0A)
    static let surface = Color(hex: 0x15120E)
    static let raised = Color(hex: 0x221F19)
    static let hairline = Color(hex: 0x2F2B24)
    static let strongBorder = Color(hex: 0x4C473F)

    static let text = Color(hex: 0xEBE7E0)
    static let muted = Color(hex: 0xA9A094)
    static let dim = Color(hex: 0x867F74)

    static let amber = Color(hex: 0xFAAB3F)
    static let amberLabel = Color(hex: 0xFDD7A2)
    static let green = Color(hex: 0x64CF80)
    static let red = Color(hex: 0xFF6467)

    /// Corner radius of panels, chips and pickers.
    static let radius: CGFloat = 6

    static var padSpacing: CGFloat { ScreenMetrics.isPad ? 10 : 8 }
    static var margin: CGFloat { ScreenMetrics.isPad ? 24 : 12 }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// A keycap's colours: the skirt round its edge, the cap's top and bottom, and the label.
struct KeyStyle {
    let skirt: Color
    let top: Color
    let bottom: Color
    /// The cap's top when pressed: it brightens as it sinks.
    let pressedTop: Color
    let label: Color

    static let sand = KeyStyle(skirt: Color(hex: 0x1B160F), top: Color(hex: 0x382F21), bottom: Color(hex: 0x2F281C),
                               pressedTop: Color(hex: 0x54462F), label: Color(hex: 0xF3E6C4))
    static let amber = KeyStyle(skirt: Color(hex: 0x2A1A06), top: Color(hex: 0x6A4512), bottom: Color(hex: 0x58390E),
                                pressedTop: Color(hex: 0x8F5E1A), label: Color(hex: 0xFFE2B5))
    static let rust = KeyStyle(skirt: Color(hex: 0x24160A), top: Color(hex: 0x452C14), bottom: Color(hex: 0x38230F),
                               pressedTop: Color(hex: 0x6E3D18), label: Color(hex: 0xFFD3B0))
    static let rose = KeyStyle(skirt: Color(hex: 0x220E12), top: Color(hex: 0x4A2028), bottom: Color(hex: 0x3D1A21),
                               pressedTop: Color(hex: 0x6A2E39), label: Color(hex: 0xF8D4DA))
    static let violet = KeyStyle(skirt: Color(hex: 0x170F1F), top: Color(hex: 0x2F2343), bottom: Color(hex: 0x271D38),
                                 pressedTop: Color(hex: 0x46345F), label: Color(hex: 0xE4D6F6))
    static let blue = KeyStyle(skirt: Color(hex: 0x0D1721), top: Color(hex: 0x1E3045), bottom: Color(hex: 0x182838),
                               pressedTop: Color(hex: 0x2C4A6A), label: Color(hex: 0xD2E5F8))
    static let teal = KeyStyle(skirt: Color(hex: 0x0A1A1A), top: Color(hex: 0x1A3B3B), bottom: Color(hex: 0x153131),
                               pressedTop: Color(hex: 0x255656), label: Color(hex: 0xCDEFEA))
    static let green = KeyStyle(skirt: Color(hex: 0x0E1811), top: Color(hex: 0x203426), bottom: Color(hex: 0x1A2B1F),
                                pressedTop: Color(hex: 0x2F4C37), label: Color(hex: 0xD2EBD0))
    static let graphite = KeyStyle(skirt: Color(hex: 0x0C0A07), top: Color(hex: 0x2A261F), bottom: Color(hex: 0x221F19),
                                   pressedTop: Color(hex: 0x3A352C), label: Theme.text)

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

/// A tactile keycap: a cap on a darker skirt. Pressed, the cap sinks 3 points, brightens, and
/// an amber light comes on in its corner.
struct Keycap<Label: View>: View {
    let style: KeyStyle
    let pressed: Bool
    /// The amber light, on while pressed and while a macro plays.
    var lit = false
    /// An amber ring round the cap: a macro playing.
    var ringed = false
    /// Room between the cap's edge and the label; small keys take less.
    var labelPadding: CGFloat = 6
    @ViewBuilder let label: () -> Label

    var body: some View {
        let sunk = pressed
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(style.skirt)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color(hex: 0x050403), lineWidth: 1)
                }
                .shadow(color: .black.opacity(sunk ? 0.3 : 0.55), radius: sunk ? 1 : 2, y: sunk ? 1 : 2)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [sunk ? style.pressedTop : style.top, style.bottom],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    // The light catching the cap's front edge.
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(sunk ? 0.05 : 0.1), .clear],
                                                     startPoint: .top, endPoint: .center), lineWidth: 1)
                }
                .overlay {
                    if ringed {
                        RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.amber, lineWidth: 2)
                    }
                }
                .overlay {
                    label()
                        .foregroundStyle(sunk ? .white : style.label)
                        .padding(.horizontal, labelPadding)
                        .padding(.vertical, labelPadding * 2 / 3)
                }
                .overlay(alignment: .topTrailing) {
                    if lit || sunk {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Theme.amber)
                            .frame(width: 6, height: 6)
                            .shadow(color: Theme.amber.opacity(0.8), radius: 3)
                            .padding(5)
                    }
                }
                .padding(.top, sunk ? 5 : 2)
                .padding(.horizontal, 2)
                .padding(.bottom, sunk ? 2 : 5)
        }
        .animation(.easeOut(duration: 0.06), value: sunk)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// An empty place on a pad: a bare switch socket. `addable` marks one a macro can go on.
struct Socket: View {
    var addable = false
    var highlighted = false

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(hex: 0x070604))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(highlighted ? Theme.amber : Color(hex: 0x1A1712), lineWidth: highlighted ? 2 : 1)
            }
            .overlay {
                // Inner shadow along the top: the socket is recessed.
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .top, endPoint: .center),
                                  lineWidth: 3)
                    .padding(1)
            }
            .overlay {
                if addable || highlighted {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(highlighted ? Theme.amber : Color(hex: 0x2A261F))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A key's label: its name, sized to the key so a word never breaks, and mono detail lines.
struct KeyLabel: View {
    let title: String
    var details: [String] = []
    var scale: CGFloat = 1
    var design: Font.Design = .default

    var body: some View {
        GeometryReader { geometry in
            let base = (ScreenMetrics.isPad ? 20 : 16) * scale
            let size = KeyLabel.fittingSize(title, base: base, width: geometry.size.width - 4, design: design)
            let detailSize = max(10, min(size * 0.7, ScreenMetrics.isPad ? 14 : 12) * min(scale, 1.2))
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: size, weight: .semibold, design: design))
                    .tracking(-0.2)
                    .lineLimit(scale > 1.3 ? 3 : 2)
                    .minimumScaleFactor(0.8)
                ForEach(details, id: \.self) { detail in
                    Text(detail)
                        .font(.system(size: detailSize, design: .monospaced))
                        .opacity(0.7)
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
        var font = UIFont.systemFont(ofSize: base, weight: .semibold)
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

/// A small monospaced tag in a hairline box: "2×", "INSTANT".
struct MonoTag: View {
    let text: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .tracking(1.2)
        .textCase(.uppercase)
        .lineLimit(1)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .overlay { RoundedRectangle(cornerRadius: 2).strokeBorder(.foreground.opacity(0.6), lineWidth: 1) }
    }
}

/// The console's segmented control: an inset track holding the segments, the selected one
/// amber-tinted with an amber border.
struct ConsoleSegmented<Value: Hashable, Segment: View>: View {
    let options: [Value]
    @Binding var selection: Value
    var height: CGFloat = 32
    /// Options it would be wrong to pick now show dimmed and do nothing.
    var isEnabled: (Value) -> Bool = { _ in true }
    @ViewBuilder let segment: (Value) -> Segment

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                let enabled = on || isEnabled(option)
                Button {
                    selection = option
                } label: {
                    segment(option)
                        .font(.system(size: height > 34 ? 15 : 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(on ? Theme.amberLabel : Theme.muted)
                        .padding(.horizontal, 10)
                        .frame(minWidth: 36, maxHeight: .infinity)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Theme.amber.opacity(0.15))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .strokeBorder(Theme.amber.opacity(0.5), lineWidth: 1)
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
        .padding(2)
        .frame(height: height)
        .background(Theme.well, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// A square console button: the settings gear, the pencil.
struct ConsoleTileButtonStyle: ButtonStyle {
    var size: CGFloat = 32
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size > 34 ? 16 : 15, weight: .medium))
            .foregroundStyle(active ? Theme.amberLabel : Theme.muted)
            .frame(minWidth: size, minHeight: size)
            .padding(.horizontal, active ? 10 : 0)
            .background(configuration.isPressed ? Theme.raised : active ? Theme.amber.opacity(0.15) : Theme.surface,
                        in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(active ? Theme.amber.opacity(0.5) : Theme.hairline, lineWidth: 1)
            }
            .contentShape(Rectangle())
    }
}

extension View {
    /// A list or form on the console's ground. Its sections take `consoleRows()`.
    func consoleForm() -> some View {
        scrollContentBackground(.hidden).background(Theme.ground)
    }

    /// A list section's rows on the console's surface.
    func consoleRows() -> some View {
        listRowBackground(Theme.surface)
    }
}
