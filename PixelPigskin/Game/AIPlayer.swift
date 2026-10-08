import SpriteKit

/// The reflex layer: executes the AI brain's decisions at 60fps with
/// steering behaviors. Every AI-controlled player on the field — all 11
/// opponents, plus route-runners and blockers — moves through here.
///
/// The LLM brain (AIBrain) decides *what* to do; this decides *how* to move.
enum AIPlayer {

    // MARK: - Defense

    /// Drive all defenders for one frame.
    /// - `offense`: offensive players (index 0=QB 1=RB 2=WR1 3=WR2 4=TE)
    /// - `carrier`: current ball carrier (either side) or nil
    /// - `ballFlyingTo`: landing spot while the ball is in the air
    static func updateDefense(_ defenders: [PlayerNode],
                              offense: [PlayerNode],
                              carrier: PlayerNode?,
                              qb: PlayerNode?,
                              ballFlyingTo: CGPoint?,
                              decision: AIDecision,
                              dt: CGFloat) {
        guard defenders.count >= 11 else { return }
        let dline = Array(defenders[0..<4])     // rushers
        let lbs = Array(defenders[4..<7])
        let dbs = Array(defenders[7..<11])

        // --- Defensive line: rush the QB (or the ball), shed blocks ---
        for (i, r) in dline.enumerated() {
            if r.slowTimer > 0 { /* still update below */ }
            var target: CGPoint
            if let c = carrier, decision.pursuitTarget == "carrier" {
                target = c.position
            } else if let q = qb, ballFlyingTo == nil {
                target = q.position
            } else if let c = carrier {
                target = c.position
            } else {
                target = r.position
            }
            // Gap shift slides the rush lane.
            target = target + CGPoint(x: 0, y: CGFloat(decision.gapShift) * 30)
            // Block shedding: engaged rushers are slowed unless they shed.
            _ = i
            r.moveTarget = target
        }

        // --- Linebackers ---
        for (i, lb) in lbs.enumerated() {
            if decision.blitz && i < 2 {
                // Extra rushers.
                lb.moveTarget = (carrier ?? qb)?.position ?? lb.position
            } else if decision.spyQb, i == 2, let q = qb {
                // Mirror the QB at 4 yards.
                let dir = (q.position - lb.position).normalized
                lb.moveTarget = q.position - dir * 4 * Field.pointsPerYard
            } else if let c = carrier {
                // Fill: pursue with a slight angle.
                lb.moveTarget = c.position + c.vel * 0.25
            } else if let rec = coverageTarget(for: lb, lbsIndex: i, offense: offense) {
                lb.moveTarget = mirror(rec, from: lb, cushion: 5)
            }
        }

        // --- Defensive backs ---
        for (i, db) in dbs.enumerated() {
            if let land = ballFlyingTo {
                // Ball in the air: nearest two converge, others hold.
                let rank = dbs.sorted { $0.position.distance(to: land) < $1.position.distance(to: land) }
                if rank.prefix(2).contains(where: { $0 === db }) {
                    db.moveTarget = land
                    continue
                }
            }
            if let rec = coverageTarget(for: db, dbsIndex: i, offense: offense,
                                        double: decision.doubleCoverIndex) {
                // Double-covered receiver gets bracketed: second DB plays deep.
                let cushion: CGFloat = (i == 0) ? CGFloat(decision.safetyDepth) : 4
                db.moveTarget = mirror(rec, from: db, cushion: cushion)
            } else if let c = carrier {
                db.moveTarget = c.position + c.vel * 0.3
            }
        }
    }

    /// Man-coverage assignment: DB/LB i mirrors receiver (i mapped onto 1...4).
    private static func coverageTarget(for db: PlayerNode, dbsIndex i: Int,
                                       offense: [PlayerNode],
                                       double: Int) -> PlayerNode? {
        let recIdx = [2, 3, 4, 1][i % 4] // WR1, WR2, TE, RB
        guard recIdx < offense.count else { return nil }
        let rec = offense[recIdx]
        // If this receiver is doubled and we're the extra man, still take him.
        if double == rec.posIndex, i == 3 { return rec }
        if double != -1, double == rec.posIndex, i != 0, i != 3 { return nil }
        return rec
    }

    private static func coverageTarget(for lb: PlayerNode, lbsIndex i: Int,
                                       offense: [PlayerNode]) -> PlayerNode? {
        let recIdx = [1, 4, 2][i % 3]
        guard recIdx < offense.count else { return nil }
        return offense[recIdx]
    }

    /// Position between the receiver and the (assumed right-side) endzone.
    private static func mirror(_ rec: PlayerNode, from db: PlayerNode,
                               cushion: CGFloat) -> CGPoint {
        let goal = CGPoint(x: 120 * Field.pointsPerYard, y: rec.position.y)
        let dir = (goal - rec.position).normalized
        return rec.position + dir * cushion * Field.pointsPerYard * 0.5
             + (db.position - rec.position).normalized * cushion * Field.pointsPerYard * 0.5
    }

    // MARK: - Offense (route running, opponent QB)

    /// Receivers run their routes; called every frame during a live play.
    static func updateRoutes(_ receivers: [PlayerNode], dt: CGFloat) {
        for r in receivers where !r.controlled {
            if r.routeIndex < r.route.count {
                let wp = r.route[r.routeIndex]
                r.moveTarget = wp
                if r.position.distance(to: wp) < 8 { r.routeIndex += 1 }
            } else {
                // Route done: drift downfield / come back slightly.
                r.moveTarget = r.position + CGPoint(x: 30, y: 0)
            }
        }
    }

    /// Simple AI quarterback for when the opponent has the ball (or AUTO).
    /// Returns true when it decided to throw (scene performs the throw).
    static func updateAIQuarterback(qb: PlayerNode, receivers: [PlayerNode],
                                    defenders: [PlayerNode],
                                    timeSinceSnap: Double,
                                    decideThrow: (PlayerNode) -> Void) {
        // Hold, then pick the most open receiver and throw.
        guard timeSinceSnap > Double.random(in: 1.2...2.6) else {
            // Drift in the pocket.
            qb.moveTarget = qb.position + CGPoint(x: -10, y: sin(timeSinceSnap * 2) * 20)
            return
        }
        var best: PlayerNode?
        var bestScore: CGFloat = -1
        for r in receivers {
            let nearestD = defenders.map { $0.position.distance(to: r.position) }.min() ?? 0
            let downfield = r.position.x
            let score = nearestD + downfield * 0.15
            if score > bestScore { bestScore = score; best = r }
        }
        if let target = best { decideThrow(target) }
    }

    // MARK: - Blocking

    /// Pair blockers with the nearest rusher; engaged rushers are slowed.
    static func applyBlocking(blockers: [PlayerNode], rushers: [PlayerNode],
                              shedSkill: CGFloat) {
        for b in blockers {
            guard let r = rushers.min(by: { $0.position.distance(to: b.position)
                                          < $1.position.distance(to: b.position) }) else { continue }
            b.moveTarget = r.position
            b.blockTarget = r
            if b.position.distance(to: r.position) < 2.2 * Field.pointsPerYard {
                // Engaged: slow the rusher unless he sheds (skill roll per call ~ frame).
                if CGFloat.random(in: 0...1) < shedSkill * 0.02 {
                    r.slowTimer = 0 // shed!
                } else {
                    r.slowTimer = 0.2
                    r.slowFactor = 0.45
                }
            }
        }
    }

    // MARK: - Kick coverage / returns

    /// Coverage team sprints downfield; returner waits then runs.
    static func updateKickoff(coverage: [PlayerNode], returnTeam: [PlayerNode],
                             ball: BallNode, ballLanded: Bool) {
        if !ballLanded {
            for c in coverage { c.moveTarget = c.position + CGPoint(x: 400, y: 0) }
            if let ret = returnTeam.first {
                ret.moveTarget = ball.position
            }
        } else {
            // After the catch everyone pursues / blocks.
            for c in coverage {
                if let holder = ball.holder { c.moveTarget = holder.position }
            }
        }
    }
}
