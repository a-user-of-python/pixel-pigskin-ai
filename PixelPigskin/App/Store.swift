import SwiftUI
import Combine

/// App-wide state. Original menu UI (not a copy of any existing game).
final class Store: ObservableObject {

    enum Screen {
        case menu, teamSelect, season, frontOffice, howTo
        case game(GameInfo)
    }

    struct GameInfo {
        var home: Team
        var away: Team
        var isPlayoff: Bool
        var playoffIndex: Int?
        var week: Int
    }

    @Published var screen: Screen = .menu
    @Published var season: Season?
    @Published var playerTeamId: UUID?
    @Published var difficultyBias: Double = 0
    @Published var freeAgents: [Player] = []
    @Published var salaryCap: Int = 90

    var playerTeam: Team? {
        guard let id = playerTeamId else { return nil }
        return season?.team(id)
    }

    func newSeason(teamId: UUID) {
        let teams = League.makeTeams()
        season = Season(teams: teams)
        playerTeamId = teamId
        difficultyBias = 0
        freeAgents = AIGM.shared.makeFreeAgents()
        screen = .season
    }

    func capUsed() -> Int {
        guard let t = playerTeam else { return 0 }
        return t.roster.reduce(0) { $0 + AIGM.shared.salary(of: $1) }
    }

    /// Called when the player's game finishes.
    func completeGame(info: GameInfo, playerScore: Int, oppScore: Int, updatedTeam: Team) {
        guard let season else { return }
        // Write back roster changes (morale/stamina).
        if let i = season.teams.firstIndex(where: { $0.id == updatedTeam.id }) {
            season.teams[i] = updatedTeam
        }
        // Determine home/away from the player's perspective.
        let playerIsHome = info.home.id == playerTeamId
        let hs = playerIsHome ? playerScore : oppScore
        let as_ = playerIsHome ? oppScore : playerScore

        if info.isPlayoff, let idx = info.playoffIndex {
            _ = season.resolvePlayoffGame(index: idx, homeScore: hs, awayScore: as_)
            // Sim the other playoff game if the player wasn't in it.
            simOtherPlayoff(except: idx)
        } else {
            season.recordPlayerGame(homeId: info.home.id, awayId: info.away.id,
                                    homeScore: hs, awayScore: as_)
            season.simWeek(exceptPlayerId: playerTeamId!)
            season.advanceWeek()
        }

        // Adaptive difficulty: tune opponent strength by margin.
        let margin = playerScore - oppScore
        if margin > 14 { difficultyBias = min(4, difficultyBias + 1) }
        else if margin < -14 { difficultyBias = max(-4, difficultyBias - 1) }

        screen = .season
    }

    /// Sim playoff games the player isn't part of.
    private func simOtherPlayoff(except idx: Int) {
        guard let season else { return }
        for i in season.playoffBracket.indices where i != idx && !season.playoffBracket[i].played {
            let g = season.playoffBracket[i]
            let r = season.simGame(homeId: g.homeId, awayId: g.awayId, week: g.week)
            _ = season.resolvePlayoffGame(index: i, homeScore: r.homeScore, awayScore: r.awayScore)
        }
    }

    /// Sim the rest of the playoffs (used when the player's team is eliminated).
    func simRestOfPlayoffs() {
        guard let season else { return }
        var guard_ = 0
        while season.championId == nil && guard_ < 10 {
            guard_ += 1
            guard let idx = season.playoffBracket.firstIndex(where: { !$0.played }) else { break }
            let g = season.playoffBracket[idx]
            let r = season.simGame(homeId: g.homeId, awayId: g.awayId, week: g.week)
            _ = season.resolvePlayoffGame(index: idx, homeScore: r.homeScore, awayScore: r.awayScore)
        }
    }

    func signFreeAgent(_ fa: Player) -> Bool {
        guard var team = playerTeam,
              let ti = season?.teams.firstIndex(where: { $0.id == team.id }) else { return false }
        guard capUsed() + AIGM.shared.salary(of: fa) <= salaryCap else { return false }
        team.roster.append(fa)
        season?.teams[ti] = team
        freeAgents.removeAll { $0.id == fa.id }
        return true
    }
}
