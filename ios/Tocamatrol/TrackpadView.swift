import SwiftUI
import TocaCore
import UIKit

/// The full-screen trackpad. UIKit touch handling, because SwiftUI gestures cannot tell
/// one- and two-finger taps, tap-then-drag and per-finger movement apart reliably.
struct TrackpadView: UIViewRepresentable {
    let controller: InputController

    func makeUIView(context: Context) -> TrackpadSurface {
        let view = TrackpadSurface()
        view.controller = controller
        return view
    }

    func updateUIView(_ view: TrackpadSurface, context: Context) {
        view.controller = controller
    }
}

final class TrackpadSurface: UIView {
    weak var controller: InputController?
    /// A crisp comic ripple ring under each finger, by touch id.
    private var spots: [Int: CALayer] = [:]
    private let halftoneLayer = CALayer()

    private static let surfaceFill = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x141B38) : UIColor(hex: 0xFFFDF7)
    }
    private static let idleBorder = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x7A93E6) : UIColor(hex: 0x151311)
    }
    private static let activeBorder = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0xFFD21F) : UIColor(hex: 0x0F52EB)
    }
    private static let spotFill = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: 0x38E4FF, alpha: 0.28)
            : UIColor(hex: 0x38E0F5, alpha: 0.30)
    }
    private static let spotBorder = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x38E4FF) : UIColor(hex: 0x151311)
    }
    private static let dotColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: 0x56A8FF, alpha: 0.10)
            : UIColor(hex: 0x151311, alpha: 0.05)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.borderWidth = 2.5
        clipsToBounds = true

        halftoneLayer.zPosition = -1
        layer.addSublayer(halftoneLayer)

        applyTheme()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: TrackpadSurface, _) in
            view.applyTheme()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        halftoneLayer.frame = bounds
        CATransaction.commit()
    }

    private func applyTheme() {
        backgroundColor = Self.surfaceFill.resolvedColor(with: traitCollection)
        let borderColor = (spots.isEmpty ? Self.idleBorder : Self.activeBorder).resolvedColor(with: traitCollection)
        layer.borderColor = borderColor.cgColor

        let dot = Self.dotColor.resolvedColor(with: traitCollection)
        halftoneLayer.backgroundColor = UIColor(patternImage: Self.makeHalftoneTile(color: dot)).cgColor
    }

    private static func makeHalftoneTile(color: UIColor) -> UIImage {
        let step: CGFloat = 16
        let size = CGSize(width: step, height: step)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            ctx.cgContext.setFillColor(color.cgColor)
            let d: CGFloat = 2.6
            ctx.cgContext.fillEllipse(in: CGRect(x: 2, y: 2, width: d, height: d))
            ctx.cgContext.fillEllipse(in: CGRect(x: 2 + step / 2, y: 2 + step / 2, width: d, height: d))
        }
    }

    // Three fingers belong to the trackpad (middle click and drag), not the system's
    // undo and copy shortcuts.
    override var editingInteractionConfiguration: UIEditingInteractionConfiguration { .none }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        controller?.touchesBegan(samples(touches), at: timestamp(touches, event))
        touches.forEach(showSpot)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        controller?.touchesMoved(samples(touches), at: timestamp(touches, event))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for touch in touches { spots[Self.id(touch)]?.position = touch.location(in: self) }
        CATransaction.commit()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        controller?.touchesEnded(touches.map(Self.id), at: timestamp(touches, event))
        touches.forEach(hideSpot)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        controller?.touchesEnded(touches.map(Self.id), at: timestamp(touches, event))
        touches.forEach(hideSpot)
    }

    // MARK: - Touch feedback

    private func showSpot(_ touch: UITouch) {
        let size: CGFloat = 52
        let spot = CALayer()
        spot.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        spot.cornerRadius = size / 2
        spot.backgroundColor = Self.spotFill.resolvedColor(with: traitCollection).cgColor
        spot.borderColor = Self.spotBorder.resolvedColor(with: traitCollection).cgColor
        spot.borderWidth = 2.5
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        spot.position = touch.location(in: self)
        layer.addSublayer(spot)
        CATransaction.commit()
        spots[Self.id(touch)]?.removeFromSuperlayer()
        spots[Self.id(touch)] = spot

        let appear = CABasicAnimation(keyPath: "opacity")
        appear.fromValue = 0
        appear.duration = 0.1
        spot.add(appear, forKey: "appear")
        if !UIAccessibility.isReduceMotionEnabled {
            let grow = CABasicAnimation(keyPath: "transform.scale")
            grow.fromValue = 0.55
            grow.duration = 0.14
            grow.timingFunction = CAMediaTimingFunction(name: .easeOut)
            spot.add(grow, forKey: "grow")
        }
        setBorderLit(true)
    }

    private func hideSpot(_ touch: UITouch) {
        guard let spot = spots.removeValue(forKey: Self.id(touch)) else { return }
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setCompletionBlock { spot.removeFromSuperlayer() }
        spot.opacity = 0
        if !UIAccessibility.isReduceMotionEnabled { spot.transform = CATransform3DMakeScale(1.25, 1.25, 1) }
        CATransaction.commit()
        if spots.isEmpty { setBorderLit(false) }
    }

    /// Highlights the comic border in Hero Blue / Sunburst Yellow while fingers are down.
    private func setBorderLit(_ lit: Bool) {
        let color = (lit ? Self.activeBorder : Self.idleBorder).resolvedColor(with: traitCollection).cgColor
        guard layer.borderColor != color else { return }
        let fade = CABasicAnimation(keyPath: "borderColor")
        fade.fromValue = layer.presentation()?.borderColor ?? layer.borderColor
        fade.duration = lit ? 0.1 : 0.25
        layer.borderColor = color
        layer.add(fade, forKey: "borderColor")
    }

    private static func id(_ touch: UITouch) -> Int {
        ObjectIdentifier(touch).hashValue
    }

    private func samples(_ touches: Set<UITouch>) -> [TouchSample] {
        touches.map { touch in
            let p = touch.location(in: self)
            return TouchSample(id: Self.id(touch), x: Double(p.x), y: Double(p.y), radius: Double(touch.majorRadius))
        }
    }

    private func timestamp(_ touches: Set<UITouch>, _ event: UIEvent?) -> Double {
        event?.timestamp ?? touches.first?.timestamp ?? CACurrentMediaTime()
    }
}
