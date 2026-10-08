import Foundation
import FoundationModels

/// The player's AI coach: suggests a play before each snap using the
/// on-device LLM. Falls back to rules when Apple Intelligence is unavailable.
final class AICoach {
    static let shared = AICoach()
    private init() {}

    var isAvailable: Bool {
        if #available(iOS 26, *) {
            return SystemLanguageModel.default.isAvailable
        }
        return false
    }

    @Generable
    struct PlaySuggestion {
        @Guide(description: "Play name, exactly one of: Slant, Go, Post, Curl, Draw, Sweep, Punt, Field Goal")
        var playName: String
        @Guide(description: "One short sentence explaining why, in a coach's voice")
        var reasoning: String
    }

    /// Returns (playName, reasoning, cameFromAI).
    func suggest(down: Int, distance: Int, yardLine: Int,
                 quarter: Int, clock: Int, scoreDiff: Int) async -> (String, String, Bool) {
        guard isAvailable else {
            let (p, r) = FallbackAI.suggestPlay(down: down, distance: distance,
                                               yardLine: yardLine, quarter: quarter,
                                               clock: clock, scoreDiff: scoreDiff)
            return (p, r, false)
        }
        do {
            return try await withThrowingTaskGroup(of: (String, String, Bool).self) { group in
                group.addTask { [self] in
                    let s = try await self.queryLLM(down: down, distance: distance,
                                                    yardLine: yardLine, quarter: quarter,
                                                    clock: clock, scoreDiff: scoreDiff)
                    return (s.playName, s.reasoning, true)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 2_500_000_000)
                    let (p, r) = FallbackAI.suggestPlay(down: down, distance: distance,
                                                       yardLine: yardLine, quarter: quarter,
                                                       clock: clock, scoreDiff: scoreDiff)
                    return (p, r, false)
                }
                let first = try await group.next()!
                group.cancelAll()
                return first
            }
        } catch {
            let (p, r) = FallbackAI.suggestPlay(down: down, distance: distance,
                                               yardLine: yardLine, quarter: quarter,
                                               clock: clock, scoreDiff: scoreDiff)
            return (p, r, false)
        }
    }

    @available(iOS 26, *)
    private func queryLLM(down: Int, distance: Int, yardLine: Int,
                          quarter: Int, clock: Int, scoreDiff: Int) async throws -> PlaySuggestion {
        let session = LanguageModelSession()
        let prompt = """
        You are the offensive coordinator in a retro arcade football game. \
        Call the next play. Situation: down \(down), \(distance) yards to go, \
        ball on yard line \(yardLine) (0=own goal, 100=opponent goal), quarter \
        \(quarter), \(clock) seconds left in the quarter, score differential \
        (my team minus opponent) \(scoreDiff). Playbook: Slant, Go, Post, Curl \
        (passes), Draw, Sweep (runs), Punt, Field Goal (4th down only). \
        On 4th down always pick Punt or Field Goal. Be aggressive but smart.
        """
        let resp = try await session.respond(to: prompt, generating: PlaySuggestion.self)
        var s = resp.content
        let legal = ["Slant", "Go", "Post", "Curl", "Draw", "Sweep", "Punt", "Field Goal"]
        if !legal.contains(s.playName) { s.playName = "Slant" }
        return s
    }
}
