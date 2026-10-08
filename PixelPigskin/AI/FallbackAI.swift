import Foundation

/// Rule-based fallback for every AI decision, used when Apple Intelligence
/// is unavailable (older device, or user declined). Same inputs/outputs as
/// the LLM brain so the game plays identically, just less creative.
enum FallbackAI {

    // MARK: - Defensive brain fallback

    static func decide(_ input: BrainInput) -> AIDecision {
        let long = input.distance >= 7
        let short = input.distance <= 2
        let backedUp = input.yardLine < 20
        let redZone = input.yardLine > 80
        let hurry = input.quarter == 4 && input.clockSeconds < 120 && input.scoreDiff > 0

        var d = AIDecision.neutral
        // Pressure when it matters.
        d.blitz = (input.down >= 3 && long) || hurry || (short && !redZone)
        // Double the most dangerous-looking target on obvious pass downs.
        d.doubleCoverIndex = (long || input.down >= 3) ? 2 : -1
        // Spy mobile situations.
        d.spyQb = input.yardLine > 40 && input.yardLine < 85 && !long
        // Red zone: everyone rallies to the ball.
        d.pursuitTarget = redZone ? "carrier" : "ball"
        d.safetyDepth = redZone ? 8 : (long ? 18 : 14)
        d.gapShift = backedUp ? 0 : (input.down == 1 ? 1 : 0)
        d.note = "Rule-based call."
        return d
    }

    // MARK: - Player-facing coach fallback (suggest a play for the user)

    /// Returns (playId, reasoning, suggested).
    static func suggestPlay(down: Int, distance: Int, yardLine: Int,
                            quarter: Int, clock: Int, scoreDiff: Int) -> (String, String) {
        // 4th down: kick.
        if down == 4 {
            if yardLine >= 65 { return ("Field Goal", "In range — take the 3.") }
            return ("Punt", "Too far — flip the field.")
        }
        // Goal line: pound it.
        if yardLine >= 90 { return ("Draw", "Goal line — run it in.") }
        // Backed up: safe.
        if yardLine <= 15 { return ("Draw", "Backed up — safe run.") }
        // Short yardage: run.
        if distance <= 2 { return ("Sweep", "Short yardage — get outside.") }
        // Long: air it out.
        if distance >= 8 { return ("Go", "Long — stretch the field.") }
        // 2-minute drill, trailing: quick passes.
        if quarter == 4 && clock < 120 && scoreDiff < 0 {
            return ("Slant", "Hurry-up — quick slant.")
        }
        // Default: balanced.
        let pick = ["Slant", "Curl", "Post", "Draw"].randomElement()!
        return (pick, "Balanced call.")
    }
}
