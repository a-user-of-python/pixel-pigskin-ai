import Foundation
import FoundationModels

// MARK: - AI Brain input

/// Snapshot of the game the LLM brain reasons over. Pre-snap and mid-play.
struct BrainInput {
    var down: Int
    var distance: Int
    var yardLine: Int        // 0...100 from the offense's own goal
    var quarter: Int
    var clockSeconds: Int
    var scoreDiff: Int       // offense score minus defense score
    var offensivePlayName: String
    var secondsSinceSnap: Double
    var ballYardLine: Int
    var isBlitzLikely: Bool  // hint from previous decisions
}

// MARK: - AI decision (what the LLM outputs)

/// Flat, generable decision the 60fps reflex layer executes.
@Generable
struct AIDecision {
    @Guide(description: "True to send extra rushers at the quarterback")
    var blitz: Bool
    @Guide(description: "Receiver index to double-cover: 1=RB 2=WR1 3=WR2 4=TE, -1 for none")
    var doubleCoverIndex: Int
    @Guide(description: "True to keep a linebacker mirroring the quarterback")
    var spyQb: Bool
    @Guide(description: "Who defenders pursue: ball, qb, or carrier")
    var pursuitTarget: String
    @Guide(description: "Safety depth in yards, 8 to 20")
    var safetyDepth: Int
    @Guide(description: "Defensive line shift: -1 left, 0 none, 1 right")
    var gapShift: Int
    @Guide(description: "One short sentence explaining the call")
    var note: String

    static var neutral: AIDecision {
        AIDecision(blitz: false, doubleCoverIndex: -1, spyQb: false,
                   pursuitTarget: "ball", safetyDepth: 14, gapShift: 0,
                   note: "Base defense.")
    }
}

// MARK: - The on-device LLM brain

/// The "coach brain": an on-device LLM that makes defensive decisions at key
/// moments — pre-snap (has seconds) and mid-play (throttled to ~0.75s).
/// It NEVER runs per-frame; the reflex layer (AIPlayer) executes its
/// decisions at 60fps with steering behaviors.
final class AIBrain {
    static let shared = AIBrain()
    private init() {}

    var isAvailable: Bool {
        if #available(iOS 26, *) {
            return SystemLanguageModel.default.isAvailable
        }
        return false
    }

    private var cached = AIDecision.neutral
    private var inFlight = false
    private var lastCall = Date.distantPast
    private let minInterval: TimeInterval = 0.75

    /// Mid-play tick: returns the latest decision, refreshing from the LLM
    /// at most every `minInterval` seconds. Never blocks the game loop.
    func decide(_ input: BrainInput) -> AIDecision {
        guard isAvailable else { return FallbackAI.decide(input) }
        let now = Date()
        guard !inFlight, now.timeIntervalSince(lastCall) >= minInterval else {
            return cached
        }
        inFlight = true
        lastCall = now
        Task { [weak self] in
            guard let self else { return }
            do {
                let d = try await self.queryLLM(input)
                await MainActor.run { self.cached = d; self.inFlight = false }
            } catch {
                await MainActor.run { self.inFlight = false }
            }
        }
        return cached
    }

    /// Pre-snap: the UI waits on this (with timeout) before the play starts.
    func preSnapDecide(_ input: BrainInput) async -> AIDecision {
        guard isAvailable else { return FallbackAI.decide(input) }
        do {
            let d = try await withThrowingTaskGroup(of: AIDecision.self) { group in
                group.addTask { try await self.queryLLM(input) }
                group.addTask {
                    try await Task.sleep(nanoseconds: 2_500_000_000)
                    return FallbackAI.decide(input)
                }
                guard let first = try await group.next() else {
                    return FallbackAI.decide(input)
                }
                group.cancelAll()
                return first
            }
            cached = d
            return d
        } catch {
            return FallbackAI.decide(input)
        }
    }

    @available(iOS 26, *)
    private func queryLLM(_ input: BrainInput) async throws -> AIDecision {
        let session = LanguageModelSession()
        let prompt = """
        You are the defensive coordinator in a retro arcade football game.
        Offense situation: \(input.down)rd & \(input.distance), ball on yard \
        line \(input.yardLine) (0=own goal, 100=opponent goal), Q\(input.quarter) \
        \(input.clockSeconds)s left, score differential (offense minus defense) \
        \(input.scoreDiff). Offensive play: \(input.offensivePlayName). \
        \(input.secondsSinceSnap > 0 ? "The ball was snapped \(String(format: "%.1f", input.secondsSinceSnap))s ago; ball now at yard line \(input.ballYardLine)." : "Pre-snap.")
        Output a defensive decision as the requested fields.
        """
        let resp = try await session.respond(to: prompt, generating: AIDecision.self)
        var d = resp.content
        // Sanitize: the reflex layer trusts these ranges.
        d.doubleCoverIndex = (-1...4).contains(d.doubleCoverIndex) ? d.doubleCoverIndex : -1
        d.safetyDepth = min(20, max(8, d.safetyDepth))
        d.gapShift = min(1, max(-1, d.gapShift))
        if !["ball", "qb", "carrier"].contains(d.pursuitTarget) { d.pursuitTarget = "ball" }
        return d
    }

    func reset() {
        cached = .neutral
        inFlight = false
        lastCall = .distantPast
    }
}
