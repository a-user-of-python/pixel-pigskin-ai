
// MARK: - Game flow: update, throwing, tackling, kicks (extension)

extension GameScene {

    // MARK: - Update loop

    private func updateLive(dt: CGFloat) {
        snapElapsed += Double(dt)
        if jukeCooldown > 0 { jukeCooldown -= dt }

        // Game clock runs at 5x during live play.
        clockAccum += Double(dt) * 5
        if clockAccum >= 1 {
            let s = Int(clockAccum); clockAccum -= Double(s)
            let wasQ = state.quarter
            state.tickClock(s)
            if state.isOver { endGame(); return }
            if state.quarter == 3 && wasQ == 2 && !halftimeDone { startHalftime(); return }
        }

        let qb = offense.first { $0.posIndex == 0 }

        // Throttled LLM brain tick (never blocks the loop).
        brainDecision = AIBrain.shared.decide(brainInput())

        // Handoff on run plays.
        if handoffTimer > 0 {
            handoffTimer -= Double(dt)
            if handoffTimer <= 0, let rb = offense.first(where: { $0.posIndex == 1 }) {
                ball.attach(to: rb)
                if playerOnOffense { setControlled(rb) }
                rb.route = []
                rb.moveTarget = rb.position + (currentPlay?.runTarget ?? .zero) * Field.pointsPerYard
            }
        }

        // Receivers run routes (whoever isn't player-controlled).
        AIPlayer.updateRoutes(offense.filter { $0.posIndex >= 1 && $0.posIndex <= 4 }, dt: dt)

        // Blocking: OL engages rushers.
        let ol = offense.filter { $0.posIndex >= 5 }
        let rushers = defense.filter {
            $0.isRusher || ($0.posIndex >= 4 && $0.posIndex < 7 && brainDecision.blitz)
        }
        AIPlayer.applyBlocking(blockers: ol, rushers: rushers, shedSkill: 0.5)

        // Defense executes the brain's decision (skips the human-controlled man).
        let carrier = ball.holder
        let ballSpot: CGPoint? = ball.state == .flying ? ballTargetSpot : nil
        AIPlayer.updateDefense(defense.filter { !$0.controlled },
                               offense: offense, carrier: carrier, qb: qb,
                               ballFlyingTo: ballSpot, decision: brainDecision, dt: dt)

        // Opponent AI quarterback.
        if !playerOnOffense, ball.state == .held, let q = qb, ball.holder === q {
            aiThrowTimer -= Double(dt)
            if aiThrowTimer <= 0 {
                aiThrowTimer = -1
                let recs = offense.filter { $0.posIndex >= 1 && $0.posIndex <= 4 }
                AIPlayer.updateAIQuarterback(qb: q, receivers: recs, defenders: defense,
                                             timeSinceSnap: snapElapsed) { [weak self] target in
                    self?.aiThrow(to: target)
                }
            }
        }

        // Tackles, sidelines, endzones.
        if let c = carrier, ball.state == .held {
            let foes = c.side == 0 ? defense : offense
            if foes.contains(where: { $0.position.distance(to: c.position) < 1.3 * Field.pointsPerYard }) {
                if let t = foes.first(where: { $0.position.distance(to: c.position) < 1.3 * Field.pointsPerYard }) {
                    tackle(carrier: c, by: t)
                    return
                }
            }
            let yl = Field.yardLine(of: c.position)
            if abs(Field.lateral(of: c.position)) > Field.widthYards / 2 {
                endPlay(at: clampToField(c.position)); return
            }
            if c.side == 0 && yl >= 100 { endPlay(at: c.position, touchdown: true); return }
            if c.side == 1 && yl <= 0 { endPlay(at: c.position, touchdown: true, defensive: true); return }
            if c.side == 0 && yl <= 0 { endPlay(at: c.position, safety: true); return }
        }
    }

    // MARK: - Throwing

    /// Swipe-to-throw. `swipe` is in scene points.
    private func doThrow(swipe: CGPoint) {
        guard phase == .live, playerOnOffense,
              ball.state == .held, let qb = ball.holder, qb.posIndex == 0 else { return }
        guard swipe.length > 40 else { return }
        let dir = swipe.normalized
        let power = min(1, swipe.length / 380)

        // Target: tapped receiver, else best in the swipe cone.
        var target = selectedReceiver
        if target == nil {
            var bestScore: CGFloat = -1
            for r in offense where r.posIndex >= 1 && r.posIndex <= 4 {
                let to = (r.position - qb.position).normalized
                let alignment = to.x * dir.x + to.y * dir.y
                if alignment > 0.7 {
                    let score = alignment - r.position.distance(to: qb.position) / 2000
                    if score > bestScore { bestScore = score; target = r }
                }
            }
        }
        guard let rec = target else { showMessage("No receiver there"); return }

        // Lead the receiver; QB-accuracy noise (worse under pressure).
        let dist = qb.position.distance(to: rec.position)
        let flight = dist / (38 * Field.pointsPerYard)
        var aim = rec.position + rec.vel * flight * 0.8
        let pressure = defense.contains { $0.position.distance(to: qb.position) < 3 * Field.pointsPerYard }
        let arm = Double(playerTeam.roster[0].arm)
        let noiseYards = (1 - arm / 130) * (pressure ? 6 : 2.5)
        aim = aim + CGPoint(x: CGFloat.random(in: -noiseYards...noiseYards) * Field.pointsPerYard,
                            y: CGFloat.random(in: -noiseYards...noiseYards) * Field.pointsPerYard)
        // Weak swipes fall short.
        let maxRange = (12 + power * 40) * Field.pointsPerYard
        if qb.position.distance(to: aim) > maxRange {
            aim = qb.position + (aim - qb.position).normalized * maxRange
        }

        ballTargetSpot = aim
        ball.onLand = { [weak self] spot in self?.resolveCatch(at: spot) }
        ball.throwTo(aim, duration: flight, in: fieldNode)
        setControlled(nil)
        selectedReceiver = nil
    }

    private func aiThrow(to rec: PlayerNode) {
        guard phase == .live, ball.state == .held, ball.holder != nil else { return }
        var aim = rec.position + rec.vel * 0.5
        let qbTeam = state.playerPossession ? playerTeam : opponentTeam
        let arm = Double(qbTeam.roster[0].arm)
        let n = (1 - arm / 130) * 4.0
        aim = aim + CGPoint(x: CGFloat.random(in: -n...n) * Field.pointsPerYard,
                            y: CGFloat.random(in: -n...n) * Field.pointsPerYard)
        ballTargetSpot = aim
        ball.onLand = { [weak self] spot in self?.resolveCatch(at: spot) }
        ball.throwTo(aim, duration: 0.9, in: fieldNode)
    }

    private func resolveCatch(at spot: CGPoint) {
        guard phase == .live else { return }
        let radius: CGFloat = 2.6 * Field.pointsPerYard
        let oBest = offense.min { $0.position.distance(to: spot) < $1.position.distance(to: spot) }
        let dBest = defense.min { $0.position.distance(to: spot) < $1.position.distance(to: spot) }
        let oD = oBest.map { $0.position.distance(to: spot) } ?? .greatestFiniteMagnitude
        let dD = dBest.map { $0.position.distance(to: spot) } ?? .greatestFiniteMagnitude

        if oD < radius && oD <= dD + 0.4 * Field.pointsPerYard, let o = oBest {
            ball.attach(to: o)
            SoundFX.shared.play(.catchBall)
            o.route = []
            if playerOnOffense { setControlled(o); showMessage("Caught! Run!") }
        } else if dD < radius, let d = dBest {
            ball.attach(to: d)
            SoundFX.shared.play(.interception)
            showMessage("INTERCEPTED!")
            if playerOnOffense { moraleHit(int: true) }
            endPlay(at: spot, turnover: true, interception: true)
        } else {
            SoundFX.shared.play(.whistle)
            showMessage("Incomplete")
            endPlay(at: CGPoint(x: Field.point(yardLine: CGFloat(state.yardLine), lateral: 0).x, y: 0),
                    incomplete: true)
        }
    }

    private func tackle(carrier: PlayerNode, by tackler: PlayerNode) {
        SoundFX.shared.play(.tackle)
        carrier.run(SKAction.sequence([SKAction.moveBy(x: 6, y: 0, duration: 0.08),
                                       SKAction.moveBy(x: -6, y: 0, duration: 0.08)]))
        // Injury roll (franchise mode): out for the next 10 plays.
        if Double.random(in: 0...1) < 0.04 {
            injuries["\(teamId(forSide: carrier.side))-\(carrier.posIndex)", default: 0] = 10
            showMessage("\(carrierName(carrier)) is hurt!")
        }
        endPlay(at: carrier.position)
    }

    private func teamId(forSide side: Int) -> UUID {
        state.playerPossession
            ? (side == 0 ? playerTeam.id : opponentTeam.id)
            : (side == 0 ? opponentTeam.id : playerTeam.id)
    }

    private func carrierName(_ n: PlayerNode) -> String {
        let team = n.side == 0
            ? (state.playerPossession ? playerTeam : opponentTeam)
            : (state.playerPossession ? opponentTeam : playerTeam)
        let names = ["QB", "RB", "WR1", "WR2", "TE"]
        let nm = n.posIndex < names.count ? names[n.posIndex] : "DEF"
        return "\(team.shortName) \(nm)"
    }

    // MARK: - Play resolution

    private func clampToField(_ p: CGPoint) -> CGPoint {
        let maxLat = Field.widthYards / 2 * Field.pointsPerYard
        return CGPoint(x: p.x, y: max(-maxLat, min(maxLat, p.y)))
    }

    private func endPlay(at spot: CGPoint, touchdown: Bool = false,
                         turnover: Bool = false, interception: Bool = false,
                         incomplete: Bool = false, defensive: Bool = false,
                         safety: Bool = false) {
        phase = .playOver
        SoundFX.shared.play(.whistle)
        let oldYard = state.yardLine
        let newYard = max(0, min(100, Int(Field.yardLine(of: spot).rounded())))

        if touchdown && !defensive { onTouchdown(); return }
        if touchdown && defensive {
            if state.playerPossession { state.opponentScore += 6 } else { state.playerScore += 6 }
            showMessage("DEFENSIVE TD!")
            SoundFX.shared.play(.touchdown)
            state.playerPossession.toggle()
            state.resetForKickoff()
            scheduleKickoff(after: 1.6)
            return
        }
        if safety {
            if state.playerPossession { state.opponentScore += 2 } else { state.playerScore += 2 }
            showMessage("SAFETY!")
            state.playerPossession.toggle()
            state.resetForKickoff()
            scheduleKickoff(after: 1.6)
            return
        }
        if turnover {
            showMessage(interception ? "Turnover!" : "Turnover on downs!")
            state.playerPossession.toggle()
            state.down = 1; state.distance = 10
            state.yardLine = 100 - newYard
            scheduleNext(after: 1.6)
            return
        }

        let gain = incomplete ? 0 : newYard - oldYard
        if gain >= state.distance {
            state.down = 1; state.distance = 10
            state.yardLine = newYard
            showMessage("1st DOWN!")
            SoundFX.shared.play(.firstDown)
        } else {
            state.down += 1
            state.distance -= max(0, gain)
            state.yardLine = newYard
            if state.down > 4 {
                showMessage("Turnover on downs!")
                state.playerPossession.toggle()
                state.down = 1; state.distance = 10
                state.yardLine = 100 - newYard
            }
        }
        state.tickClock(Int.random(in: 16...24))
        if state.isOver { endGame(); return }
        scheduleNext(after: 1.4)
    }

    private func onTouchdown() {
        if state.playerPossession { state.playerScore += 6 } else { state.playerScore += 6 }
        SoundFX.shared.play(.touchdown)
        showMessage("TOUCHDOWN!")
        if state.playerPossession { moraleHit(td: true) }
        run(SKAction.sequence([SKAction.wait(forDuration: 1.8),
                               SKAction.run { [weak self] in self?.startKick(kind: .pat) }]))
    }

    private func scheduleNext(after: Double) {
        run(SKAction.sequence([SKAction.wait(forDuration: after),
                               SKAction.run { [weak self] in
            guard let self, !state.isOver else { return }
            self.showPlaySelect()
        }]))
    }

    private func scheduleKickoff(after: Double) {
        run(SKAction.sequence([SKAction.wait(forDuration: after),
                               SKAction.run { [weak self] in self?.startKickoff() }]))
    }

    // MARK: - Kicking (swipe up; straightness = accuracy, length = power)

    private func startKick(kind: KickKind, distanceYards: CGFloat = 0) {
        phase = .kickMeter
        kickKind = kind
        kickDistanceYards = distanceYards
        clearOverlay()
        let o = SKNode(); o.zPosition = 200; hud.addChild(o); overlay = o
        let title = SKLabelNode(fontNamed: "Courier-Bold")
        title.fontSize = 30; title.fontColor = .yellow
        title.position = CGPoint(x: 0, y: 120)
        switch kind {
        case .pat: title.text = "EXTRA POINT — SWIPE UP!"
        case .fieldGoal: title.text = "FIELD GOAL (\(Int(distanceYards)) YDS) — SWIPE UP!"
        case .punt: title.text = "PUNT — SWIPE UP!"
        case .kickoff: title.text = "KICKOFF — SWIPE UP!"
        }
        o.addChild(title)
        let hint = SKLabelNode(fontNamed: "Courier")
        hint.fontSize = 20; hint.fontColor = .white
        hint.text = "Straight swipe = accurate   •   Long swipe = power"
        hint.position = CGPoint(x: 0, y: 70)
        o.addChild(hint)
    }

    /// Resolve a kick swipe. Up = +y in scene space.
    private func doKick(swipe: CGPoint) {
        guard phase == .kickMeter else { return }
        guard swipe.y > 60 else { showMessage("Swipe UP to kick"); return }
        let straightness = 1 - min(1, abs(swipe.x) / max(1, swipe.y))
        let power = min(1, swipe.length / 500)
        SoundFX.shared.play(.kick)
        clearOverlay()

        switch kickKind {
        case .pat:
            resolvePlaceKick(distance: 18, power: power, straightness: straightness,
                             points: 1, label: "PAT")
        case .fieldGoal:
            resolvePlaceKick(distance: kickDistanceYards, power: power,
                             straightness: straightness, points: 3, label: "FIELD GOAL")
        case .punt:
            let dist = power * 55 + 15
            showMessage("Punt \(Int(dist)) yds")
            let landYard = min(99, state.yardLine + Int(dist))
            state.yardLine = 100 - landYard
            state.playerPossession.toggle()
            state.down = 1; state.distance = 10
            state.tickClock(8)
            if state.isOver { endGame(); return }
            scheduleNext(after: 1.4)
        case .kickoff:
            let dist = 45 + power * 25
            showMessage("Kickoff \(Int(dist)) yds")
            beginReturn(kickDistance: dist, straightness: straightness)
        }
    }

    private func resolvePlaceKick(distance: CGFloat, power: CGFloat,
                                  straightness: CGFloat, points: Int, label: String) {
        let kickingTeam = state.playerPossession ? playerTeam : opponentTeam
        let leg = CGFloat(kickingTeam.roster.first { $0.position == .K }?.kicking ?? 80)
        let range = 25 + leg * 0.45
        let accNeed = 0.55 + (1 - leg / 120) * 0.2
        let good = power * range >= distance && straightness >= accNeed
        if good {
            if state.playerPossession { state.playerScore += points } else { state.opponentScore += points }
            showMessage("\(label) GOOD!")
            SoundFX.shared.play(.cheer)
        } else {
            showMessage("\(label) missed.")
        }
        state.tickClock(6)
        if state.isOver { endGame(); return }
        if good || kickKind == .pat {
            // Kickoff after scores (and after PAT either way).
            state.playerPossession.toggle() // scoring team kicks
            state.resetForKickoff()
            scheduleKickoff(after: 1.6)
        } else {
            // Missed FG: other team's ball at the spot.
            state.playerPossession.toggle()
            state.down = 1; state.distance = 10
            state.yardLine = 100 - state.yardLine
            scheduleNext(after: 1.6)
        }
    }

    // MARK: - Kickoff & returns

    private func startKickoff() {
        phase = .kickMeter
        kickKind = .kickoff
        clearOverlay()
        showMessage(state.playerPossession ? "You receive the kick" : "You kick off")
        state.yardLine = 35
        startKick(kind: .kickoff)
        // AI kicks automatically when it's the opponent's kick.
        if state.playerPossession {
            run(SKAction.sequence([SKAction.wait(forDuration: 1.2),
                                   SKAction.run { [weak self] in
                self?.doKick(swipe: CGPoint(x: CGFloat.random(in: -20...20), y: 420))
            }]))
        }
    }

    private func beginReturn(kickDistance: CGFloat, straightness: CGFloat) {
        let landYard = min(98, 35 + Int(kickDistance * (0.9 + straightness * 0.1)))
        let returnYards = Int.random(in: 0...18)
        let finalSpot = min(99, landYard + returnYards)
        showMessage("Return to the \(100 - finalSpot)")
        state.yardLine = 100 - finalSpot
        state.down = 1; state.distance = 10
        state.tickClock(10)
        if state.isOver { endGame(); return }
        scheduleNext(after: 1.6)
    }

    // MARK: - Halftime / game over

    private func startHalftime() {
        halftimeDone = true
        phase = .halftime
        clearOverlay()
        SoundFX.shared.play(.whistle)
        let o = SKNode(); o.zPosition = 200; hud.addChild(o); overlay = o
        let t = SKLabelNode(fontNamed: "Courier-Bold")
        t.fontSize = 44; t.fontColor = .yellow; t.text = "HALFTIME"
        t.position = CGPoint(x: 0, y: 80)
        o.addChild(t)
        let s = SKLabelNode(fontNamed: "Courier-Bold")
        s.fontSize = 30; s.fontColor = .white
        s.text = "\(playerTeam.shortName) \(state.playerScore) — \(state.opponentScore) \(opponentTeam.shortName)"
        s.position = CGPoint(x: 0, y: 10)
        o.addChild(s)
        let b = ButtonNode(text: "START 2ND HALF", size: CGSize(width: 340, height: 70)) { [weak self] in
            guard let self else { return }
            // The team that didn't receive the opening kick receives now.
            self.state.playerPossession = !self.playerReceivedOpeningKickoff
            self.clearOverlay()
            self.startKickoff()
        }
        b.position = CGPoint(x: 0, y: -90)
        o.addChild(b); playButtons.append(b)
    }

    private func endGame() {
        guard phase != .gameOver else { return }
        phase = .gameOver
        clearOverlay()
        SoundFX.shared.play(state.playerScore > state.opponentScore ? .cheer : .buzzer)
        let o = SKNode(); o.zPosition = 200; hud.addChild(o); overlay = o
        let t = SKLabelNode(fontNamed: "Courier-Bold")
        t.fontSize = 44; t.fontColor = .yellow
        let won = state.playerScore > state.opponentScore
        t.text = won ? "YOU WIN!" : (state.playerScore == state.opponentScore ? "TIE GAME" : "YOU LOSE")
        t.position = CGPoint(x: 0, y: 80)
        o.addChild(t)
        let s = SKLabelNode(fontNamed: "Courier-Bold")
        s.fontSize = 34; s.fontColor = .white
        s.text = "\(playerTeam.shortName) \(state.playerScore) — \(state.opponentScore) \(opponentTeam.shortName)"
        s.position = CGPoint(x: 0, y: 0)
        o.addChild(s)
        let b = ButtonNode(text: "CONTINUE", size: CGSize(width: 300, height: 70)) { [weak self] in
            guard let self else { return }
            self.applyPostGameMorale()
            self.onGameComplete?(self.state.playerScore, self.state.opponentScore, self.playerTeam)
        }
        b.position = CGPoint(x: 0, y: -100)
        o.addChild(b); playButtons.append(b)
    }

    // MARK: - Morale / stamina (franchise-lite)

    private func moraleHit(td: Bool = false, int: Bool = false) {
        if td {
            for i in playerTeam.roster.indices {
                playerTeam.roster[i].morale = min(100, playerTeam.roster[i].morale + 2)
            }
        }
        if int, !playerTeam.roster.isEmpty {
            playerTeam.roster[0].morale = max(0, playerTeam.roster[0].morale - 8)
        }
    }

    private func applyPostGameMorale() {
        let won = state.playerScore > state.opponentScore
        for i in playerTeam.roster.indices {
            playerTeam.roster[i].morale = min(100, max(0, playerTeam.roster[i].morale + (won ? 5 : -4)))
            playerTeam.roster[i].stamina = min(100, playerTeam.roster[i].stamina + 30)
        }
    }

    // MARK: - Camera

    private func updateCamera() {
        let focusX: CGFloat
        if ball.state == .flying {
            focusX = ball.position.x
        } else if let c = ball.holder {
            // Holder is a child of fieldNode via attach; use converted position.
            focusX = fieldNode.convert(c.position, from: c.parent ?? c).x
        } else {
            focusX = Field.point(yardLine: CGFloat(state.yardLine), lateral: 0).x
        }
        let half = size.width / 2
        let fieldW = Field.lengthYards * Field.pointsPerYard
        cam.position.x = max(half, min(fieldW - half, focusX))
        cam.position.y = 0
    }

    // MARK: - Touches: tap select, drag run, swipe throw, flick juke, swipe kick

    private func buttonHit(_ b: ButtonNode, at scenePoint: CGPoint) -> Bool {
        guard let parent = b.parent else { return false }
        return b.frame.contains(convert(scenePoint, to: parent))
    }

    /// Quick flick while running: burst + nearest defender stumbles.
    private func doJuke(direction: CGPoint) {
        guard jukeCooldown <= 0, let c = ball.holder else { return }
        jukeCooldown = 1.5
        c.vel = direction * c.topSpeed * Field.pointsPerYard * 1.6
        let foes = c.side == 0 ? defense : offense
        if let near = foes.min(by: { $0.position.distance(to: c.position) < $1.position.distance(to: c.position) }),
           near.position.distance(to: c.position) < 3.5 * Field.pointsPerYard {
            near.slowTimer = 0.6
            near.slowFactor = 0.25
            showMessage("Juked!")
        }
        SoundFX.shared.play(.click)
    }
}

// MARK: - Simple tappable button (original UI)

final class ButtonNode: SKShapeNode {
    private var label: SKLabelNode!
    private var action: () -> Void

    init(text: String, size: CGSize, action: @escaping () -> Void) {
        self.action = action
        super.init()
        self.path = CGPath(roundedRect: CGRect(origin: CGPoint(x: -size.width / 2, y: -size.height / 2),
                                               size: size), cornerWidth: 12, cornerHeight: 12, transform: nil)
        fillColor = UIColor(red: 0.12, green: 0.2, blue: 0.35, alpha: 1)
        strokeColor = .white
        lineWidth = 2
        label = SKLabelNode(fontNamed: "Courier-Bold")
        label.text = text
        label.fontSize = 22
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        addChild(label)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func setText(_ t: String) { label.text = t }
    func trigger() { SoundFX.shared.play(.click); action() }
}
