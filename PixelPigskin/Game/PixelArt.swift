import SpriteKit
import UIKit

/// Programmatic 8-bit pixel-art sprites. No asset files needed — every sprite
/// is drawn from a string map so the game ships zero images.
enum PixelArt {

    /// Builds a nearest-filtered texture from a string map.
    /// "." = transparent. Any other char looks up `palette`.
    static func makeTexture(rows: [String], palette: [Character: UIColor],
                            pixel: CGFloat = 4) -> SKTexture {
        let h = rows.count
        let w = rows.map { $0.count }.max() ?? 1
        let size = CGSize(width: CGFloat(w) * pixel, height: CGFloat(h) * pixel)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return SKTexture() }
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                guard ch != ".", let color = palette[ch] else { continue }
                color.setFill()
                // Flip vertically: row 0 is the top of the sprite.
                ctx.fill(CGRect(x: CGFloat(x) * pixel,
                                y: CGFloat(h - 1 - y) * pixel,
                                width: pixel, height: pixel))
            }
        }
        guard let img = UIGraphicsGetImageFromCurrentImageContext() else {
            return SKTexture()
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .nearest
        return tex
    }

    /// 10x14 football player. Palette-swapped per team.
    /// H = helmet, S = skin, J = jersey, P = pants, W = cleats
    static func playerTexture(jersey: UIColor, helmet: UIColor,
                              skin: UIColor = UIColor(red: 0.85, green: 0.6, blue: 0.45, alpha: 1),
                              pants: UIColor = .white) -> SKTexture {
        let rows = [
            "...HHHH...",
            "..HHHHHH..",
            "..HSSSSH..",
            "...SSSS...",
            "..JJJJJJ..",
            ".JJJJJJJJ.",
            ".JSJJJJSJ.",
            ".JJJJJJJJ.",
            "..JJJJJJ..",
            "...PPPP...",
            "...PP.PP..",
            "...PP.PP..",
            "...PP.PP..",
            "...WW.WW..",
        ]
        return makeTexture(rows: rows, palette: [
            "H": helmet, "S": skin, "J": jersey, "P": pants, "W": .darkGray,
        ])
    }

    /// 6x5 football. B = leather, W = laces.
    static func ballTexture() -> SKTexture {
        let rows = [
            ".BBBB.",
            "BBBBBB",
            "BBWWBB",
            "BBBBBB",
            ".BBBB.",
        ]
        return makeTexture(rows: rows, palette: [
            "B": UIColor(red: 0.55, green: 0.32, blue: 0.16, alpha: 1),
            "W": .white,
        ], pixel: 3)
    }

    /// Simple 8x8 selection ring drawn as a texture-less shape node helper.
    static func selectionRing(radius: CGFloat, color: UIColor) -> SKShapeNode {
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.strokeColor = color
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.zPosition = 50
        return ring
    }
}
