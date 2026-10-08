import CoreGraphics

// MARK: - Playbook

enum PlayKind { case pass, run, punt, fieldGoal }

/// Receiver indices: 1 = RB, 2 = WR1, 3 = WR2, 4 = TE (0 = QB).
struct PlayDef: Identifiable {
    var id: String { name }
    var name: String
    var kind: PlayKind
    /// Routes per receiver index, as waypoints in yards relative to snap spot.
    /// (dx = downfield, dy = across field)
    var routes: [Int: [CGPoint]]
    /// For run plays: which gap the RB aims at (dx, dy yards from snap).
    var runTarget: CGPoint?
    var description: String
}

enum Playbook {
    static let passPlays: [PlayDef] = [
        PlayDef(name: "Slant", kind: .pass, routes: [
            2: [CGPoint(x: 4, y: -2), CGPoint(x: 12, y: 8)],
            3: [CGPoint(x: 4, y: 2), CGPoint(x: 12, y: -8)],
            4: [CGPoint(x: 6, y: 0), CGPoint(x: 8, y: 0)],
            1: [CGPoint(x: 1, y: -6), CGPoint(x: 3, y: -8)],
        ], runTarget: nil, description: "Quick inside slants. Beats man coverage."),
        PlayDef(name: "Go", kind: .pass, routes: [
            2: [CGPoint(x: 25, y: -4)],
            3: [CGPoint(x: 25, y: 4)],
            4: [CGPoint(x: 15, y: 0)],
            1: [CGPoint(x: 2, y: -7)],
        ], runTarget: nil, description: "Everybody deep. Air it out."),
        PlayDef(name: "Post", kind: .pass, routes: [
            2: [CGPoint(x: 10, y: -3), CGPoint(x: 22, y: 6)],
            3: [CGPoint(x: 10, y: 3), CGPoint(x: 22, y: 12)],
            4: [CGPoint(x: 12, y: 0)],
            1: [CGPoint(x: 1, y: 6), CGPoint(x: 4, y: 8)],
        ], runTarget: nil, description: "Post + corner. Attacks the safeties."),
        PlayDef(name: "Curl", kind: .pass, routes: [
            2: [CGPoint(x: 9, y: -4)],
            3: [CGPoint(x: 9, y: 4)],
            4: [CGPoint(x: 7, y: 0)],
            1: [CGPoint(x: 3, y: -5)],
        ], runTarget: nil, description: "Short curls. Safe chain-mover."),
    ]

    static let runPlays: [PlayDef] = [
        PlayDef(name: "Draw", kind: .run, routes: [
            2: [CGPoint(x: 12, y: -6)],
            3: [CGPoint(x: 12, y: 6)],
            4: [CGPoint(x: 4, y: 0), CGPoint(x: 10, y: 2)],
            1: [CGPoint(x: 6, y: 0), CGPoint(x: 14, y: 0)],
        ], runTarget: CGPoint(x: 14, y: 0), description: "Delayed handoff up the middle."),
        PlayDef(name: "Sweep", kind: .run, routes: [
            2: [CGPoint(x: 8, y: -8), CGPoint(x: 14, y: -12)],
            3: [CGPoint(x: 10, y: 6)],
            4: [CGPoint(x: 5, y: -6), CGPoint(x: 10, y: -10)],
            1: [CGPoint(x: 3, y: -8), CGPoint(x: 12, y: -12)],
        ], runTarget: CGPoint(x: 12, y: -12), description: "Pitch outside. Beat them to the edge."),
    ]

    static let specialPlays: [PlayDef] = [
        PlayDef(name: "Punt", kind: .punt, routes: [:], runTarget: nil,
                description: "Flip the field."),
        PlayDef(name: "Field Goal", kind: .fieldGoal, routes: [:], runTarget: nil,
                description: "3 points if in range."),
    ]

    static let all: [PlayDef] = passPlays + runPlays

    static func play(id: String) -> PlayDef? { all.first { $0.id == id } }
}
