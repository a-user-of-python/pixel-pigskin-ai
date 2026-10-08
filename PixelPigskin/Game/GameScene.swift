import SpriteKit

/// Main gameplay scene. Original UI, arcade football mechanics:
/// swipe-to-throw, drag-to-run, juke flicks, swipe kicking, kickoffs,
/// 4 downs, PATs, halftime, and a full game loop.
final class GameScene: SKScene {

    // MARK: - Config (set by GameView)

    var playerTeam: Team!
    var opponentTeam: Team!
    var difficultyBias: Double = 0          // adaptive difficulty, +/- ratings
    var onGameComplete: ((Int, Int, Team) -> Void)?

    // MARK: - Nodes

    private let fieldNode = SKNode()
    private let cam = SKCameraNode()
    private let hud = SKNode()              // attached to camera
    private var offense: [PlayerNode] = []  //posIndex: 0=QB 1=RB 2=WR1 3=WR2 4=TE 5..=OL
    private var defense: [PlayerNode] = []  // 0-3 DL, 4-6 LB, 7-10 DB
    private var ball = BallNode()
    private var playButtons: [ButtonNode] = []
    private var overlay: SKNode?

    // MARK: - State

    private enum Phase {
        case playSelect, preSnap, live, playOver, kickMeter, halftime, gameOver
    }
    private var phase: Phase = .playSelect
    private var state = GameState()
    private var currentPlay: PlayDef?
    private var selectedReceiver: PlayerNode?
    private var controlled: PlayerNode?     // player-dragged player
    private var autoDefense = true
    private var brainDecision = AIDecision.neutral
    private var snapElapsed: Double = 0
    private var playClock: Double = 25
    private var aiThrowTimer: Double = -1
    private var handoffTimer: Double = -1
    private var touchStart: CGPoint = .zero
    private var touchTime: TimeInterval = 0
    private var dragging = false
    private var jukeCooldown: Double = 0
    private var kickKind: KickKind = .pat
    private var kickDistanceYards: CGFloat = 0
    private var ballTargetSpot: CGPoint = .zero
    private var clockAccum: Double = 0
    /// Injuries: "<teamUUID>-<posIndex>" -> plays remaining out.
    private var injuries: [String: Int] = [:]
    private var halftimeDone = false
    private var playerReceivedOpeningKickoff = true

    private enum KickKind { case pat, fieldGoal, punt, kickoff }

    // Player-team convenience: which side the human's team is on this drive.
    private var playerOnOffense: Bool { state.playerPossession }

    // MARK: - Scene setup

    override func didMove(to view: SKView) {
        size = CGSize(width: 1000, height: 700)
        scaleMode = .aspectFill
        backgroundColor = UIColor(red: 0.05, green: 0.12, blue: 0.06, alpha: 1)
        addChild(fieldNode)
        drawField()
        camera = cam
        cam.addChild(hud)
        addChild(cam)
        cam.position = CGPoint(x: 600, y: 0)
        buildHUD()
        refreshHUD()
        // Opening kickoff: the player's team receives.
        state.playerPossession = true
        playerReceivedOpeningKickoff = true
        startKickoff()
        SoundFX.shared.play(.whistle)
    }

    // MARK: - Field drawing (one static node)

    private func drawField() {
        let ppy = Field.pointsPerYard
        let W = Field.lengthYards * ppy, H = Field.widthYards * ppy
        let bg = SKShapeNode(rect: CGRect(x: 0, y: -H / 2, width: W, height: H))
        bg.fillColor = UIColor(red: 0.13, green: 0.42, blue: 0.18, alpha: 1)
        bg.strokeColor = .clear
        bg.zPosition = 0
        fieldNode.addChild(bg)

        // Endzones in team colors.
        for (x, color) in [(0, playerTeam.primaryColor),
                           (110 * ppy, opponentTeam.primaryColor)] as [(CGFloat, UIColor)] {
            let ez = SKShapeNode(rect: CGRect(x: x, y: -H / 2,
                                              width: 10 * ppy, height: H))
            ez.fillColor = color
            ez.strokeColor = .clear
            ez.zPosition = 1
            ez.alpha = 0.85
            fieldNode.addChild(ez)
        }

        // Yard lines, one path = one draw call.
        let path = CGMutablePath()
        for yd in 0...120 {
            let x = CGFloat(yd) * ppy
            let strong = yd % 5 == 0
            path.move(to: CGPoint(x: x, y: -H / 2))
            path.addLine(to: CGPoint(x: x, y: strong ? H / 2 : H * 0.12))
            if strong {
                path.move(to: CGPoint(x: x, y: H / 2))
                path.addLine(to: CGPoint(x: x, y: -H * 0.12))
            }
        }
        let lines = SKShapeNode(path: path)
        lines.strokeColor = UIColor(white: 1, alpha: 0.75)
        lines.lineWidth = 2
        lines.zPosition = 2
        fieldNode.addChild(lines)
    }

    // MARK: - HUD (camera-locked, big & high-contrast)

    private var scoreLabel: SKLabelNode!
    private var clockLabel: SKLabelNode!
    private var downLabel: SKLabelNode!
    private var msgLabel: SKLabelNode!
    private var coachLabel: SKLabelNode!
    private var autoButton: ButtonNode!

    private func buildHUD() {
        func label(_ text: String, size: CGFloat, pos: CGPoint) -> SKLabelNode {
            let l = SKLabelNode(fontNamed: "Courier-Bold")
            l.text = text; l.fontSize = size; l.fontColor = .white
            l.position = pos; l.zPosition = 100
            l.horizontalAlignmentMode = .center
            hud.addChild(l)
            return l
        }
        scoreLabel = label("", 30, CGPoint(x: 0, y: 300))
        clockLabel = label("", 26, CGPoint(x: 0, y: 262))
        downLabel = label("", 26, CGPoint(x: 0, y: 224))
        msgLabel = label("", 30, CGPoint(x: 0, y: -300))
        coachLabel = label("", 22, CGPoint(x: 0, y: -260))
        autoButton = ButtonNode(text: "AUTO: ON", size: CGSize(width: 170, height: 54)) { [weak self] in
            self?.toggleAuto()
        }
        autoButton.position = CGPoint(x: 400, y: 280)
        hud.addChild(autoButton)
    }

    private func refreshHUD() {
        scoreLabel.text = "\(playerTeam.shortName) \(state.playerScore)  —  \(state.opponentScore) \(opponentTeam.shortName)"
        clockLabel.text = "Q\(state.quarter)  \(state.clockString())"
        let ballOn = state.playerPossession ? state.yardLine : 100 - state.yardLine
        downLabel.text = "\(state.downString())   BALL ON \(ballOn)"
    }

    private func showMessage(_ text: String, for seconds: Double = 2) {
        msgLabel.text = text
        msgLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: seconds),
            SKAction.run { [weak self] in self?.msgLabel.text = "" },
        ]))
    }

    private func toggleAuto() {
        autoDefense.toggle()
        autoButton.setText(autoDefense ? "AUTO: ON" : "AUTO: OFF")
        if autoDefense { controlled?.controlled = false; controlled = nil }
        SoundFX.shared.play(.click)
    }

    // MARK: - Buttons

    private func clearOverlay() {
        overlay?.removeFromParent()
        overlay = nil
        playButtons.removeAll()
    }

    // MARK: - Play select

    private func showPlaySelect() {
        phase = .playSelect
        clearOverlay()
        refreshHUD()
        let o = SKNode(); o.zPosition = 200
        hud.addChild(o); overlay = o

        let panel = SKShapeNode(rect: CGRect(x: -330, y: -240, width: 660, height: 480), cornerRadius: 18)
        panel.fillColor = UIColor(white: 0.08, alpha: 0.94)
        panel.strokeColor = .white; panel.lineWidth = 3
        o.addChild(panel)

        let title = SKLabelNode(fontNamed: "Courier-Bold")
        title.text = "CHOOSE PLAY  (\(state.downString()))"
        title.fontSize = 26; title.fontColor = .yellow
        title.position = CGPoint(x: 0, y: 190)
        o.addChild(title)

        coachLabel.text = "Coach is thinking…"
        var plays = Playbook.all
        if state.down == 4 { plays += Playbook.specialPlays }

        var y: CGFloat = 120
        for p in plays {
            let b = ButtonNode(text: p.name, size: CGSize(width: 280, height: 56)) { [weak self] in
                self?.startPlay(p)
            }
            b.position = CGPoint(x: -160, y: y)
            o.addChild(b); playButtons.append(b)
            let d = SKLabelNode(fontNamed: "Courier")
            d.text = p.description; d.fontSize = 15; d.fontColor = .lightGray
            d.position = CGPoint(x: 120, y: y - 6); d.horizontalAlignmentMode = .left
            o.addChild(d)
            y -= 68
        }

        // AI coach suggestion (async, on-device LLM or fallback).
        Task { [weak self] in
            guard let self else { return }
            let s = await AICoach.shared.suggest(
                down: state.down, distance: state.distance, yardLine: state.yardLine,
                quarter: state.quarter, clock: state.clockSeconds, scoreDiff: state.scoreDiff)
            await MainActor.run {
                let badge = s.2 ? "🤖" : "📋"
                self.coachLabel.text = "\(badge) Coach: \(s.0) — \(s.1)"
            }
        }
    }

    // MARK: - Lineup & snap

    private func makeSides() -> (off: [Player], def: [Player]) {
        let offTeam = state.playerPossession ? playerTeam : opponentTeam
        let defTeam = state.playerPossession ? opponentTeam : playerTeam
        // 8-man roster -> 11 on field: starters + generic linemen.
        func lineup(_ t: Team) -> [Player] { t.roster }
        return (lineup(offTeam), lineup(defTeam))
    }

    private func speed(for p: Player, bias: Double) -> CGFloat {
        let eff = Double(p.speed) * p.effective + bias
        return CGFloat(7 + eff / 100 * 4) // 7...11 y/s
    }

    private func startPlay(_ play: PlayDef) {
        // Special teams go through the kick flow, not a scrimmage lineup.
        if play.kind == .punt { startKick(kind: .punt); return }
        if play.kind == .fieldGoal {
            startKick(kind: .fieldGoal,
                      distanceYards: CGFloat(100 - state.yardLine) + 17)
            return
        }
        // Decrement injury timers.
        for k in injuries.keys { injuries[k] = max(0, injuries[k]! - 1) }
        currentPlay = play
        clearOverlay()
        coachLabel.text = ""
        selectedReceiver = nil

        let (offRoster, defRoster) = makeSides()
        let offTeam = state.playerPossession ? playerTeam : opponentTeam
        let defTeam = state.playerPossession ? opponentTeam : playerTeam
        let offTex = PixelArt.playerTexture(jersey: offTeam.primaryColor, helmet: offTeam.secondaryColor)
        let defTex = PixelArt.playerTexture(jersey: defTeam.primaryColor, helmet: defTeam.secondaryColor)

        for n in offense + defense { n.removeFromParent() }
        offense.removeAll(); defense.removeAll()

        // Adaptive difficulty: boost whichever unit belongs to the opponent.
        let offBias = state.playerPossession ? 0 : difficultyBias
        let defBias = state.playerPossession ? difficultyBias : 0
        let losX = Field.point(yardLine: CGFloat(state.yardLine), lateral: 0).x

        // Offense: 0=QB 1=RB 2=WR1 3=WR2 4=TE 5-9=OL
        let offSpots: [(Int, CGPoint, Player)] = [
            (0, CGPoint(x: -5, y: 0), offRoster[0]),
            (1, CGPoint(x: -6, y: play.kind == .run ? -2.2 : -3.0), offRoster[1]),
            (2, CGPoint(x: 0, y: -2.2), offRoster[2]),
            (3, CGPoint(x: 0, y: 2.2), offRoster[3]),
            (4, CGPoint(x: 0, y: 0.7), offRoster[4]),
            (5, CGPoint(x: -1, y: -0.5), offRoster[5 % offRoster.count]),
            (6, CGPoint(x: -1, y: -0.25), offRoster[6 % offRoster.count]),
            (7, CGPoint(x: -1, y: 0), offRoster[7 % offRoster.count]),
            (8, CGPoint(x: -1, y: 0.25), offRoster[6 % offRoster.count]),
            (9, CGPoint(x: -1, y: 0.5), offRoster[5 % offRoster.count]),
            (10, CGPoint(x: -2, y: -1.2), offRoster[4]),
        ]
        for (idx, rel, rp) in offSpots {
            if injuries["\(offTeam.id)-\(idx)", default: 0] > 0 { continue } // hurt
            let n = PlayerNode(side: 0, posIndex: idx, texture: offTex,
                               topSpeed: speed(for: rp, bias: offBias))
            n.position = CGPoint(x: losX, y: 0) + rel * Field.pointsPerYard
            if let routes = play.routes[idx] {
                n.route = routes.map { r in n.position + r * Field.pointsPerYard }
            }
            fieldNode.addChild(n)
            offense.append(n)
        }

        // Defense: 0-3 DL, 4-6 LB, 7-10 DB
        let defSpots: [(Int, CGPoint)] = [
            (0, CGPoint(x: 1, y: -0.36)), (1, CGPoint(x: 1, y: -0.12)),
            (2, CGPoint(x: 1, y: 0.12)), (3, CGPoint(x: 1, y: 0.36)),
            (4, CGPoint(x: 4, y: -0.6)), (5, CGPoint(x: 4, y: 0)), (6, CGPoint(x: 4, y: 0.6)),
            (7, CGPoint(x: 6, y: -2.0)), (8, CGPoint(x: 6, y: 2.0)),
            (9, CGPoint(x: 12, y: -0.6)), (10, CGPoint(x: 12, y: 0.6)),
        ]
        for (idx, rel) in defSpots {
            let rp = defRoster[idx % defRoster.count]
            if injuries["\(defTeam.id)-\(idx)", default: 0] > 0 { continue } // hurt
            let n = PlayerNode(side: 1, posIndex: idx, texture: defTex,
                               topSpeed: speed(for: rp, bias: defBias))
            n.position = CGPoint(x: losX, y: 0) + rel * Field.pointsPerYard
            n.isRusher = idx < 4
            fieldNode.addChild(n)
            defense.append(n)
        }

        // Ball to QB.
        if let qb = offense.first(where: { $0.posIndex == 0 }) {
            fieldNode.addChild(ball)
            ball.attach(to: qb)
            if playerOnOffense {
                controlled = qb; qb.controlled = true
            } else {
                // Player controls nearest defender (unless AUTO).
                pickDefender()
            }
        }

        // Ask the AI brain for a pre-snap plan (LLM, with timeout).
        let input = brainInput()
        Task { [weak self] in
            let d = await AIBrain.shared.preSnapDecide(input)
            await MainActor.run { self?.brainDecision = d }
        }

        phase = .preSnap
        playClock = 25
        snapElapsed = 0
        refreshHUD()
        showMessage("Tap to snap  •  Play clock 25s")
    }

    private func pickDefender() {
        if autoDefense { controlled = nil; return }
        let anchor = ball.holder?.position ?? ball.position
        controlled = defense.min { $0.position.distance(to: anchor) < $1.position.distance(to: anchor) }
        controlled?.controlled = true
    }

    private func brainInput() -> BrainInput {
        BrainInput(down: state.down, distance: state.distance, yardLine: state.yardLine,
                   quarter: state.quarter, clockSeconds: state.clockSeconds,
                   scoreDiff: state.playerPossession ? state.scoreDiff : -state.scoreDiff,
                   offensivePlayName: currentPlay?.name ?? "?",
                   secondsSinceSnap: snapElapsed, ballYardLine: state.yardLine,
                   isBlitzLikely: brainDecision.blitz)
    }

    private func snap() {
        guard phase == .preSnap else { return }
        phase = .live
        snapElapsed = 0
        AIBrain.shared.reset()
        brainDecision = AIDecision.neutral
        SoundFX.shared.play(.snap)
        showMessage("")
        if currentPlay?.kind == .run {
            handoffTimer = 0.5
        }
        if !playerOnOffense {
            // Opponent QB decides when to throw.
            aiThrowTimer = Double.random(in: 1.4...2.8)
        }
        state.tickClock(0)
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = CGFloat(1.0 / 60.0) // fixed step keeps steering stable

        switch phase {
        case .preSnap:
            playClock -= Double(dt)
            if playClock <= 0 { snap() }
        case .live:
            updateLive(dt: dt)
        default:
            break
        }

        ball.update(dt: dt)
        for n in offense + defense { n.update(dt: dt) }
        updateCamera()
        refreshHUD()
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let scenePoint = t.location(in: self)
        touchStart = scenePoint
        touchTime = t.timestamp
        dragging = false

        // Buttons first (play select, halftime, game over, AUTO toggle).
        for b in playButtons where buttonHit(b, at: scenePoint) { b.trigger(); return }
        if buttonHit(autoButton, at: scenePoint) { autoButton.trigger(); return }

        switch phase {
        case .preSnap:
            snap() // tap to snap early
        case .live where playerOnOffense && ball.state == .held && ball.holder?.posIndex == 0:
            // Tap a receiver to select him.
            let p = t.location(in: fieldNode)
            if let rec = offense.first(where: { $0.posIndex >= 1 && $0.posIndex <= 4 &&
                                                $0.position.distance(to: p) < 60 }) {
                selectedReceiver = rec
                showMessage("Target: \(["QB","RB","WR1","WR2","TE"][rec.posIndex])")
                SoundFX.shared.play(.click)
            }
        case .live where !playerOnOffense && !autoDefense:
            // Tap a defender to control him.
            let p = t.location(in: fieldNode)
            if let d = defense.min(by: { $0.position.distance(to: p) < $1.position.distance(to: p) }),
               d.position.distance(to: p) < 60 {
                setControlled(d)
            }
        default:
            break
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, phase == .live else { return }
        dragging = true
        // Drag steers whoever we control (QB, ball carrier, or defender).
        controlled?.moveTarget = t.location(in: fieldNode)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let swipe = t.location(in: self) - touchStart
        let dt = t.timestamp - touchTime
        dragging = false

        switch phase {
        case .kickMeter:
            doKick(swipe: swipe)
        case .live:
            let quickFlick = swipe.length < 90 && swipe.length > 25 && dt < 0.25
            if quickFlick, let c = ball.holder, ball.state == .held, c === controlled {
                doJuke(direction: swipe.normalized)
            } else if playerOnOffense && ball.state == .held && ball.holder?.posIndex == 0 {
                doThrow(swipe: swipe)
            }
        default:
            break
        }
    }
}
