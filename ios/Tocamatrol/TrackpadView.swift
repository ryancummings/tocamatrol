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
    /// A faint light under each finger, by touch id.
    private var spots: [Int: CALayer] = [:]

    private static let amber = UIColor(red: 0xFA / 255, green: 0xAB / 255, blue: 0x3F / 255, alpha: 1)
    private static let hairline = UIColor(red: 0x2F / 255, green: 0x2B / 255, blue: 0x24 / 255, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        // The console's inset well (Theme.well, Theme.hairline).
        backgroundColor = UIColor(red: 0x10 / 255, green: 0x0E / 255, blue: 0x0A / 255, alpha: 1)
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = Self.hairline.cgColor
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
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
        let size: CGFloat = 46
        let spot = CALayer()
        spot.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        spot.cornerRadius = size / 2
        spot.backgroundColor = Self.amber.withAlphaComponent(0.10).cgColor
        spot.borderColor = Self.amber.withAlphaComponent(0.30).cgColor
        spot.borderWidth = 1
        spot.shadowColor = Self.amber.cgColor
        spot.shadowOpacity = 0.3
        spot.shadowRadius = 12
        spot.shadowOffset = .zero
        spot.shadowPath = UIBezierPath(ovalIn: spot.bounds).cgPath
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        spot.position = touch.location(in: self)
        layer.addSublayer(spot)
        CATransaction.commit()
        spots[Self.id(touch)]?.removeFromSuperlayer()
        spots[Self.id(touch)] = spot

        let appear = CABasicAnimation(keyPath: "opacity")
        appear.fromValue = 0
        appear.duration = 0.12
        spot.add(appear, forKey: "appear")
        if !UIAccessibility.isReduceMotionEnabled {
            let grow = CABasicAnimation(keyPath: "transform.scale")
            grow.fromValue = 0.6
            grow.duration = 0.16
            grow.timingFunction = CAMediaTimingFunction(name: .easeOut)
            spot.add(grow, forKey: "grow")
        }
        setBorderLit(true)
    }

    private func hideSpot(_ touch: UITouch) {
        guard let spot = spots.removeValue(forKey: Self.id(touch)) else { return }
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.22)
        CATransaction.setCompletionBlock { spot.removeFromSuperlayer() }
        spot.opacity = 0
        if !UIAccessibility.isReduceMotionEnabled { spot.transform = CATransform3DMakeScale(1.25, 1.25, 1) }
        CATransaction.commit()
        if spots.isEmpty { setBorderLit(false) }
    }

    /// The well's edge warms while a finger is down.
    private func setBorderLit(_ lit: Bool) {
        let color = (lit ? Self.amber.withAlphaComponent(0.35) : Self.hairline).cgColor
        guard layer.borderColor != color else { return }
        // A view's own layer takes no implicit animations, so fade it explicitly.
        let fade = CABasicAnimation(keyPath: "borderColor")
        fade.fromValue = layer.presentation()?.borderColor ?? layer.borderColor
        fade.duration = lit ? 0.12 : 0.3
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
