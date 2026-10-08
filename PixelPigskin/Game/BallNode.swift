import SpriteKit

/// The football. Simulates a simple ballistic arc; height is faked with
/// scale + a shadow node so it reads as 3D without any real physics.
final class BallNode: SKSpriteNode {

    enum State { case held, flying, loose }

    var state: State = .held
    var holder: PlayerNode?

    // Flight params
    private var from: CGPoint = .zero
    private var to: CGPoint = .zero
    private var t: CGFloat = 0
    private var duration: CGFloat = 1
    private let shadow = SKShapeNode(circleOfRadius: 8)

    /// Callback when a thrown ball lands.
    var onLand: ((CGPoint) -> Void)?

    init() {
        super.init(texture: PixelArt.ballTexture(), color: .clear,
                   size: PixelArt.ballTexture().size())
        zPosition = 20
        shadow.fillColor = .black
        shadow.alpha = 0.35
        shadow.zPosition = 5
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func attach(to node: PlayerNode) {
        removeFromParent()
        shadow.removeFromParent()
        state = .held
        holder = node
        node.hasBall = true
        node.addChild(self)
        position = CGPoint(x: 14, y: 6)
        setScale(1)
    }

    func throwTo(_ target: CGPoint, duration: CGFloat, in field: SKNode) {
        guard let h = holder else { return }
        h.hasBall = false
        holder = nil
        removeFromParent()
        field.addChild(self)
        field.addChild(shadow)
        from = h.position
        // Holder may be inside a node tree; use scene coords via field.
        from = field.convert(h.position, from: h.parent ?? h)
        to = target
        position = from
        state = .flying
        t = 0
        self.duration = max(0.25, duration)
        SoundFX.shared.play(.throwBall)
    }

    func update(dt: CGFloat) {
        switch state {
        case .held:
            break
        case .flying:
            t += dt
            let k = min(1, t / duration)
            position = from + (to - from) * k
            // Fake height: peak mid-flight.
            let hgt = sin(k * .pi) * 90
            setScale(1 + sin(k * .pi) * 0.6)
            shadow.position = position
            shadow.setScale(1 - sin(k * .pi) * 0.3)
            zRotation = t * 12
            if k >= 1 {
                state = .loose
                setScale(1)
                shadow.removeFromParent()
                onLand?(to)
            }
        case .loose:
            break
        }
    }
}
