import Foundation
import FoundationModels

/// AI general manager: roster advice between games. On-device LLM when
/// available, rules otherwise. Decisions are suggestions — the player taps
/// to apply them.
final class AIGM {
    static let shared = AIGM()
    private init() {}

    var isAvailable: Bool {
        if #available(iOS 26, *) {
            return SystemLanguageModel.default.isAvailable
        }
        return false
    }

    struct RosterAdvice {
        var title: String
        var detail: String
        var fromAI: Bool
    }

    /// Look at the roster and suggest one move (rest, sign, morale).
    func advise(team: Team, freeAgents: [Player],
                record: (wins: Int, losses: Int)) async -> RosterAdvice {
        // Fast rule-based scan first; the LLM adds the voice.
        let tired = team.roster.filter { $0.stamina < 55 }.sorted { $0.stamina < $1.stamina }
        let unhappy = team.roster.filter { $0.morale < 55 }.sorted { $0.morale < $1.morale }
        let capUsed = team.roster.reduce(0) { $0 + salary(of: $1) }

        let ruleTitle: String
        let ruleDetail: String
        if let t = tired.first {
            ruleTitle = "Rest \(t.name)"
            ruleDetail = "\(t.name) (\(t.position.rawValue)) is at \(t.stamina)% stamina. Bench him this week."
        } else if let u = unhappy.first {
            ruleTitle = "Boost \(u.name)"
            ruleDetail = "\(u.name)'s morale is \(u.morale)%. A win or a featured role would help."
        } else if capUsed < 80, let fa = freeAgents.max(by: { $0.overall < $1.overall }) {
            ruleTitle = "Sign \(fa.name)"
            ruleDetail = "\(fa.position.rawValue), \(fa.overall) OVR, $\(salary(of: fa))M. Cap room available."
        } else {
            ruleTitle = "Stand pat"
            ruleDetail = "Roster is healthy and near the cap. Record: \(record.wins)-\(record.losses)."
        }

        guard isAvailable else {
            return RosterAdvice(title: ruleTitle, detail: ruleDetail, fromAI: false)
        }
        do {
            let text = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask { [self] in try await self.queryLLM(team: team, record: record,
                                                                 tired: tired.first?.name,
                                                                 unhappy: unhappy.first?.name) }
                group.addTask {
                    try await Task.sleep(nanoseconds: 2_500_000_000)
                    return ruleDetail
                }
                guard let first = try await group.next() else { return ruleDetail }
                group.cancelAll()
                return first
            }
            return RosterAdvice(title: ruleTitle, detail: text, fromAI: true)
        } catch {
            return RosterAdvice(title: ruleTitle, detail: ruleDetail, fromAI: false)
        }
    }

    /// Salary in cap units, derived from overall.
    func salary(of p: Player) -> Int { max(2, p.overall / 10) }

    func makeFreeAgents() -> [Player] {
        let names = ["Z. Knox", "Q. Wilder", "V. Storm", "H. Jett", "L. Blaze",
                     "O. Steel", "N. Comet", "E. Rush"]
        let poss: [Position] = [.WR, .RB, .DB, .LB, .TE, .WR, .DL, .K]
        return zip(names, poss).map { n, pos in
            let ovr = Int.random(in: 68...84)
            return Player(name: n, position: pos, age: Int.random(in: 23...30),
                          arm: pos == .QB ? ovr : 50,
                          speed: ovr + Int.random(in: -6...6),
                          catching: ovr + Int.random(in: -6...6),
                          tackling: ovr + Int.random(in: -6...6),
                          kicking: pos == .K ? ovr + 6 : 40,
                          stamina: 95, morale: 75)
        }
    }

    @available(iOS 26, *)
    private func queryLLM(team: Team, record: (wins: Int, losses: Int),
                          tired: String?, unhappy: String?) async throws -> String {
        let session = LanguageModelSession()
        let prompt = """
        You are the general manager of the \(team.name) in a retro arcade \
        football game. Record: \(record.wins)-\(record.losses). \
        \(tired.map { "Tired player: \($0)." } ?? "") \
        \(unhappy.map { "Unhappy player: \($0)." } ?? "") \
        In two sentences max, give front-office advice in a confident GM voice.
        """
        let resp = try await session.respond(to: prompt)
        return resp.content
    }
}
