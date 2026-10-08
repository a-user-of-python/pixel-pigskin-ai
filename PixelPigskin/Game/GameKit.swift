import CoreGraphics
import SpriteKit

// MARK: - Shared field constants & math

/// Field geometry. Offense always attacks +x (right).
/// x: 0...120 yards (endzones 0-10 and 110-120). y: -26.65...26.65.
enum Field {
    static let pointsPerYard: CGFloat = 10
    static let lengthYards: CGFloat = 120
    static let endzoneDepth: CGFloat = 10
    static let widthYards: CGFloat = 53.3

    /// Convert a yard-line (0...100 from own goal) + lateral offset to scene coords.
    /// - Parameters:
    ///   - yardLine: 0...100, 0 = own goal line, 100 = opponent goal line
    ///   - lateral: -26.65...26.65 across the field
    static func point(yardLine: CGFloat, lateral: CGFloat) -> CGPoint {
        CGPoint(x: (yardLine + endzoneDepth) * pointsPerYard,
                y: lateral * pointsPerYard)
    }

    /// Yard line (0...100) from a scene x.
    static func yardLine(of point: CGPoint) -> CGFloat {
        point.x / pointsPerYard - endzoneDepth
    }
    static func lateral(of point: CGPoint) -> CGFloat {
        point.y / pointsPerYard
    }
}

extension CGPoint {
    static func +(l: CGPoint, r: CGPoint) -> CGPoint { CGPoint(x: l.x + r.x, y: l.y + r.y) }
    static func -(l: CGPoint, r: CGPoint) -> CGPoint { CGPoint(x: l.x - r.x, y: l.y - r.y) }
    static func *(p: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: p.x * s, y: p.y * s) }
    static func /(p: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: p.x / s, y: p.y / s) }

    var length: CGFloat { sqrt(x * x + y * y) }
    var normalized: CGPoint {
        let l = length
        return l > 0.0001 ? self / l : .zero
    }
    func distance(to p: CGPoint) -> CGFloat { (self - p).length }
    /// Yards between two scene points.
    func yards(to p: CGPoint) -> CGFloat { distance(to: p) / Field.pointsPerYard }
}

extension SKNode {
    /// Yards between two nodes.
    func yards(to node: SKNode) -> CGFloat { position.yards(to: node.position) }
}
