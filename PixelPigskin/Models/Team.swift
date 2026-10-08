import Foundation
import UIKit

// MARK: - Positions

enum Position: String, Codable, CaseIterable {
    case QB, RB, WR, TE, K, LB, DB, DL
}

// MARK: - Player

struct Player: Identifiable, Codable {
    var id = UUID()
    var name: String
    var position: Position
    var age: Int
    // Ratings 40...99
    var arm: Int
    var speed: Int
    var catching: Int
    var tackling: Int
    var kicking: Int
    // 0...100, drift with play
    var stamina: Int
    var morale: Int

    var overall: Int { (arm + speed + catching + tackling + kicking) / 5 }

    /// Effectiveness scaled by stamina/morale (0.7...1.0).
    var effective: Double {
        0.7 + 0.3 * (Double(stamina + morale) / 200.0)
    }
}

// MARK: - Team

struct Team: Identifiable, Codable {
    var id = UUID()
    var name: String
    var shortName: String   // 3-letter abbrev
    var primaryHex: String
    var secondaryHex: String
    var roster: [Player]

    /// 40...99 team strength for sims.
    var offenseRating: Int {
        let skill = roster.filter { [.QB, .RB, .WR, .TE].contains($0.position) }
        guard !skill.isEmpty else { return 70 }
        return skill.map { $0.overall }.reduce(0, +) / skill.count
    }
    var defenseRating: Int {
        let d = roster.filter { [.LB, .DB, .DL].contains($0.position) }
        guard !d.isEmpty else { return 70 }
        return d.map { $0.overall }.reduce(0, +) / d.count
    }

    var primaryColor: UIColor { UIColor(hex: primaryHex) }
    var secondaryColor: UIColor { UIColor(hex: secondaryHex) }
}

// MARK: - League (8 parody teams; expandable to 32)

enum League {
    static func makeTeams() -> [Team] {
        func P(_ name: String, _ pos: Position, _ arm: Int, _ spd: Int,
               _ ctch: Int, _ tck: Int, _ kick: Int) -> Player {
            Player(name: name, position: pos, age: Int.random(in: 22...32),
                   arm: arm, speed: spd, catching: ctch, tackling: tck,
                   kicking: kick, stamina: 90, morale: 80)
        }
        func T(_ name: String, _ short: String, _ p: String, _ s: String,
               _ players: [Player]) -> Team {
            Team(name: name, shortName: short, primaryHex: p,
                 secondaryHex: s, roster: players)
        }
        return [
            T("New York Skyhawks", "NYS", "#0A7A3D", "#FFFFFF", [
                P("J. Carter", .QB, 88, 72, 60, 40, 40),
                P("M. Reed", .RB, 55, 90, 74, 45, 40),
                P("D. Fox", .WR, 50, 92, 86, 42, 40),
                P("T. Lane", .WR, 50, 87, 82, 44, 40),
                P("K. Moss", .TE, 50, 76, 80, 55, 40),
                P("R. Vale", .K, 40, 60, 50, 40, 88),
                P("B. Stone", .LB, 40, 80, 55, 86, 40),
                P("C. Drake", .DB, 40, 89, 70, 78, 40),
            ]),
            T("Los Angeles Stars", "LAS", "#1B4FD8", "#FFC72C", [
                P("S. Blaze", .QB, 91, 78, 60, 40, 40),
                P("R. Turbo", .RB, 55, 93, 70, 45, 40),
                P("A. Cruz", .WR, 50, 90, 88, 42, 40),
                P("J. Park", .WR, 50, 85, 84, 44, 40),
                P("E. Cole", .TE, 50, 74, 78, 55, 40),
                P("N. Frost", .K, 40, 60, 50, 40, 90),
                P("D. Rook", .LB, 40, 78, 55, 84, 40),
                P("P. Sage", .DB, 40, 88, 68, 76, 40),
            ]),
            T("Chicago Bruisers", "CHI", "#0B1F4B", "#E8641B", [
                P("B. Hammer", .QB, 84, 68, 60, 45, 40),
                P("T. Ox", .RB, 52, 86, 68, 60, 40),
                P("W. Brick", .WR, 50, 82, 80, 55, 40),
                P("S. Anvil", .WR, 50, 80, 78, 55, 40),
                P("G. Iron", .TE, 50, 72, 76, 65, 40),
                P("H. Boot", .K, 40, 58, 50, 40, 84),
                P("V. Crush", .LB, 40, 76, 52, 92, 40),
                P("R. Wall", .DL, 40, 70, 45, 90, 40),
            ]),
            T("Dallas Outlaws", "DAL", "#8A8D93", "#003594", [
                P("C. Ryder", .QB, 87, 74, 60, 40, 40),
                P("D. Spur", .RB, 55, 89, 72, 45, 40),
                P("L. Bandit", .WR, 50, 91, 85, 42, 40),
                P("K. Ranger", .WR, 50, 86, 83, 44, 40),
                P("M. Colt", .TE, 50, 75, 79, 55, 40),
                P("S. Spur", .K, 40, 60, 50, 40, 86),
                P("J. Posse", .LB, 40, 79, 55, 85, 40),
                P("T. Lasso", .DB, 40, 87, 69, 77, 40),
            ]),
            T("Miami Sharks", "MIA", "#008E97", "#FC4C02", [
                P("F. Tide", .QB, 86, 80, 60, 40, 40),
                P("C. Reef", .RB, 55, 91, 74, 45, 40),
                P("S. Fin", .WR, 50, 93, 84, 42, 40),
                P("B. Coral", .WR, 50, 88, 82, 44, 40),
                P("D. Kelp", .TE, 50, 77, 81, 55, 40),
                P("A. Surf", .K, 40, 62, 50, 40, 87),
                P("G. Chum", .LB, 40, 81, 56, 83, 40),
                P("N. Bait", .DB, 40, 90, 71, 75, 40),
            ]),
            T("Seattle Evergreens", "SEA", "#0B5D3B", "#7AC4D4", [
                P("E. Rain", .QB, 85, 76, 60, 40, 40),
                P("F. Fern", .RB, 55, 88, 72, 45, 40),
                P("P. Pine", .WR, 50, 89, 85, 42, 40),
                P("C. Cedar", .WR, 50, 86, 83, 44, 40),
                P("M. Mossy", .TE, 50, 75, 80, 56, 40),
                P("O. Drizzle", .K, 40, 60, 50, 40, 85),
                P("S. Spruce", .LB, 40, 80, 55, 86, 40),
                P("H. Heron", .DB, 40, 88, 70, 79, 40),
            ]),
            T("Denver Mountaineers", "DEN", "#E8641B", "#0B2545", [
                P("P. Peak", .QB, 89, 70, 60, 40, 40),
                P("A. Ascent", .RB, 55, 87, 70, 45, 40),
                P("R. Ridge", .WR, 50, 88, 83, 42, 40),
                P("S. Summit", .WR, 50, 85, 81, 44, 40),
                P("V. Valley", .TE, 50, 74, 78, 56, 40),
                P("K. Cliff", .K, 40, 58, 50, 40, 89),
                P("B. Boulder", .LB, 40, 77, 54, 88, 40),
                P("T. Trail", .DB, 40, 86, 68, 80, 40),
            ]),
            T("Boston Minutemen", "BOS", "#C8102E", "#FFFFFF", [
                P("P. Revere", .QB, 87, 73, 60, 40, 40),
                P("S. Adams", .RB, 55, 89, 73, 45, 40),
                P("J. Hancock", .WR, 50, 90, 86, 42, 40),
                P("B. Franklin", .WR, 50, 87, 84, 44, 40),
                P("T. Paine", .TE, 50, 76, 80, 55, 40),
                P("C. Dawes", .K, 40, 60, 50, 40, 88),
                P("G. Warren", .LB, 40, 79, 55, 87, 40),
                P("W. Prescott", .DB, 40, 87, 69, 81, 40),
            ]),
        ]
    }
}

// MARK: - UIColor hex helper

extension UIColor {
    convenience init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        h = h.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >> 8) & 0xFF) / 255
        let b = CGFloat(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
