import Foundation

// MARK: - In-game state (one game)

/// Yard line measured 0...100 from the possessing team's own goal line.
struct GameState {
    var down: Int = 1
    var distance: Int = 10          // yards to go
    var yardLine: Int = 25          // 0...100
    var quarter: Int = 1
    var clockSeconds: Int = 150     // per quarter (2:30)
    var playerScore: Int = 0
    var opponentScore: Int = 0
    var playerPossession: Bool = true
    var isOver: Bool = false

    var scoreDiff: Int { playerScore - opponentScore }  // from player's view

    mutating func resetForKickoff() {
        down = 1; distance = 10; yardLine = 25
    }

    mutating func tickClock(_ seconds: Int) {
        clockSeconds -= seconds
        if clockSeconds <= 0 {
            if quarter < 4 {
                quarter += 1
                clockSeconds = 150
            } else {
                clockSeconds = 0
                isOver = true
            }
        }
    }

    func clockString() -> String {
        String(format: "%d:%02d", clockSeconds / 60, clockSeconds % 60)
    }

    func downString() -> String {
        let ord: String
        switch down {
        case 1: ord = "1st"; case 2: ord = "2nd"; case 3: ord = "3rd"
        default: ord = "4th"
        }
        return "\(ord) & \(distance)"
    }
}

// MARK: - Season

struct GameResult: Codable {
    var week: Int
    var homeId: UUID
    var awayId: UUID
    var homeScore: Int
    var awayScore: Int
    var played: Bool
}

struct Standing: Identifiable {
    var id: UUID { teamId }
    var teamId: UUID
    var wins: Int = 0
    var losses: Int = 0
}

/// 8 teams, round-robin (7 weeks), top 4 make the playoffs.
final class Season {
    var teams: [Team]
    var schedule: [[GameResult]] = []   // schedule[week] = games
    var currentWeek: Int = 0
    var playoffBracket: [GameResult] = []
    var championId: UUID?
    var isPlayoffs: Bool = false

    init(teams: [Team]) {
        self.teams = teams
        buildSchedule()
    }

    private func buildSchedule() {
        // Circle method round-robin for 8 teams -> 7 rounds.
        var ids = teams.map { $0.id }
        let n = ids.count
        for round in 0..<(n - 1) {
            var games: [GameResult] = []
            for i in 0..<(n / 2) {
                let home = ids[i], away = ids[n - 1 - i]
                games.append(GameResult(week: round, homeId: home, awayId: away,
                                        homeScore: 0, awayScore: 0, played: false))
            }
            schedule.append(games)
            // Rotate (keep first fixed).
            ids = [ids[0]] + [ids[n - 1]] + Array(ids[1..<(n - 1)])
        }
    }

    func team(_ id: UUID) -> Team? { teams.first { $0.id == id } }

    func standings() -> [Standing] {
        var map: [UUID: Standing] = [:]
        for t in teams { map[t.id] = Standing(teamId: t.id) }
        let all = schedule.flatMap { $0 } + playoffBracket
        for g in all where g.played {
            if g.homeScore > g.awayScore {
                map[g.homeId]?.wins += 1; map[g.awayId]?.losses += 1
            } else {
                map[g.awayId]?.wins += 1; map[g.homeId]?.losses += 1
            }
        }
        return map.values.sorted {
            if $0.wins != $1.wins { return $0.wins > $1.wins }
            return team($0.teamId)?.offenseRating ?? 0 > team($1.teamId)?.offenseRating ?? 0
        }
    }

    /// Sim a game between two AI teams from ratings.
    @discardableResult
    func simGame(homeId: UUID, awayId: UUID, week: Int) -> GameResult {
        guard let h = team(homeId), let a = team(awayId) else {
            return GameResult(week: week, homeId: homeId, awayId: awayId,
                              homeScore: 0, awayScore: 0, played: true)
        }
        let hEdge = Double(h.offenseRating - a.defenseRating) * 0.35 + 2.0 // home edge
        let aEdge = Double(a.offenseRating - h.defenseRating) * 0.35
        let hs = max(0, Int(21 + hEdge + Double.random(in: -9...9)))
        let as_ = max(0, Int(21 + aEdge + Double.random(in: -9...9)))
        return GameResult(week: week, homeId: homeId, awayId: awayId,
                          homeScore: hs, awayScore: as_, played: true)
    }

    /// Sim every game this week except the player's.
    func simWeek(exceptPlayerId pid: UUID) {
        guard currentWeek < schedule.count else { return }
        for i in schedule[currentWeek].indices {
            var g = schedule[currentWeek][i]
            if g.played { continue }
            if g.homeId == pid || g.awayId == pid { continue }
            g = simGame(homeId: g.homeId, awayId: g.awayId, week: currentWeek)
            schedule[currentWeek][i] = g
        }
    }

    func recordPlayerGame(homeId: UUID, awayId: UUID, homeScore: Int, awayScore: Int) {
        guard currentWeek < schedule.count else { return }
        for i in schedule[currentWeek].indices {
            var g = schedule[currentWeek][i]
            if (g.homeId == homeId && g.awayId == awayId) ||
               (g.homeId == awayId && g.awayId == homeId) {
                g.homeScore = homeScore; g.awayScore = awayScore; g.played = true
                schedule[currentWeek][i] = g
            }
        }
    }

    func playerGameThisWeek(pid: UUID) -> GameResult? {
        guard currentWeek < schedule.count else { return nil }
        return schedule[currentWeek].first {
            !$0.played && ($0.homeId == pid || $0.awayId == pid)
        }
    }

    func advanceWeek() {
        currentWeek += 1
        if currentWeek >= schedule.count && !isPlayoffs {
            startPlayoffs()
        }
    }

    private func startPlayoffs() {
        isPlayoffs = true
        let top4 = standings().prefix(4).map { $0.teamId }
        guard top4.count == 4 else { return }
        playoffBracket = [
            GameResult(week: 100, homeId: top4[0], awayId: top4[3],
                       homeScore: 0, awayScore: 0, played: false), // semi 1
            GameResult(week: 100, homeId: top4[1], awayId: top4[2],
                       homeScore: 0, awayScore: 0, played: false), // semi 2
        ]
    }

    /// Returns (championId) when the bracket is complete.
    func resolvePlayoffGame(index: Int, homeScore: Int, awayScore: Int) -> UUID? {
        guard index < playoffBracket.count else { return nil }
        playoffBracket[index].homeScore = homeScore
        playoffBracket[index].awayScore = awayScore
        playoffBracket[index].played = true
        if playoffBracket.count == 2 && playoffBracket.allSatisfy({ $0.played }) {
            let w1 = playoffBracket[0].homeScore > playoffBracket[0].awayScore
                ? playoffBracket[0].homeId : playoffBracket[0].awayId
            let w2 = playoffBracket[1].homeScore > playoffBracket[1].awayScore
                ? playoffBracket[1].homeId : playoffBracket[1].awayId
            playoffBracket.append(GameResult(week: 101, homeId: w1, awayId: w2,
                                             homeScore: 0, awayScore: 0, played: false))
            return nil
        }
        if playoffBracket.count == 3 && playoffBracket[2].played {
            let g = playoffBracket[2]
            championId = g.homeScore > g.awayScore ? g.homeId : g.awayId
            return championId
        }
        return nil
    }
}
