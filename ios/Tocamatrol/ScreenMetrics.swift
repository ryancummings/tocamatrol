import UIKit

enum ScreenMetrics {
    /// Points per millimetre of glass, so the trackpad curves can work in millimetres. UIKit does
    /// not report pixel density, so this goes by device family: iPads are 132 points per inch
    /// (264 ppi at 2×) except the mini (163), and current iPhones are within a few percent of 156.
    static var pointsPerMillimetre: Double {
        let pointsPerInch: Double
        if UIDevice.current.userInterfaceIdiom == .pad {
            let bounds = UIScreen.main.bounds
            let isMini = min(bounds.width, bounds.height) <= 744
            pointsPerInch = isMini ? 163 : 132
        } else {
            pointsPerInch = 156
        }
        return pointsPerInch / 25.4
    }

    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
}
