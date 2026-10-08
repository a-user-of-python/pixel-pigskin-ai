import SpriteKit

/// One football player on the field. Movement is kinematic (custom steering);
/// no physics engine — fast enough for 22 players at 60fps on A14+.
final class PlayerNode: SKSpriteNode {

    /// 0 = offense, 1 = defense
    var side: Int = 0
    /// Roster index: offense 0=QB 1=RB 2=WR1 3=WR2 4=TE 5...=line; defense 0...10
    var posIndex: Int = 0
    /// Yards per second.
    var topSpeed: CGFloat = 9
    var vel: CGPoint = .zero
    var hasBall: Bool = false
    /// Player-controlled (drag to move).
    var controlled: Bool = false

    // Route running (receivers)
    var route: [CGPoint] = []
    var routeIndex: Int = 0

    // Defense assignment
    var covering: PlayerNode?
    var isRusher: Bool = false

    // Blocking
    var blockTarget: PlayerNode?

    /// Juke/stumble: when > 0, movement is slowed by slowFactor.
    var slowTimer: CGFloat = 0
    var slowFactor: CGFloat = 1
    /// Plays sidelined by injury.
    var injuredPlaysOut: Int = 0

    /// Current steering target (recomputed each frame by AI or drag input).
    var moveTarget: CGPoint?

    init(side: Int, posIndex: Int, texture: SKTexture, topSpeed: CGFloat) {
        self.side = side
        self.posIndex = posIndex
        self.topSpeed = topSpeed
        super.init(texture: texture, color: .clear, size: texture.size())
        self.zPosition = 10
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Kinematic seek: accelerate toward moveTarget, arrive smoothly.
    func update(dt: CGFloat) {
        if slowTimer > 0 { slowTimer -= dt }
        let speedScale: CGFloat = slowTimer > 0 ? slowFactor : 1
        guard let t = moveTarget else {
            vel = vel * pow(0.001, dt) // friction
            position = position + vel * dt
            return
        }
        let to = t - position
        let dist = to.length
        let desired = dist > 1 ? to.normalized * topSpeed * speedScale * Field.pointsPerYard : .zero
        // Simple critically-damped-ish approach.
        let accel: CGFloat = 60 * Field.pointsPerYard
        let dv = desired - vel
        let maxDv = accel * dt
        vel = vel + (dv.length > maxDv ? dv.normalized * maxDv : dv)
        position = position + vel * dt
        // Face movement direction (flip the sprite).
        if abs(vel.x) > 20 { xScale = vel.x < 0 ? -abs(xScale) : abs(xScale) }
    }
}
