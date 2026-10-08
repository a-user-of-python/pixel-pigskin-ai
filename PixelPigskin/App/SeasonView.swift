import SwiftUI

struct SeasonView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 10) {
            header
            if let season = store.season {
                if season.isPlayoffs {
                    playoffSection(season)
                } else {
                    weekSection(season)
                }
                standingsSection(season)
            }
            Spacer()
            HStack(spacing: 12) {
                ArcadeButton(text: "FRONT OFFICE", color: .purple) {
                    store.screen = .frontOffice
                }
                ArcadeButton(text: "MENU", color: .gray) {
                    store.screen = .menu
                }
            }
            .padding(.bottom, 16)
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            if let t = store.playerTeam {
                HStack(spacing: 12) {
                    TeamBadge(team: t)
                    VStack(alignment: .leading) {
                        Text(t.name)
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        if let s = store.season {
                            let st = s.standings().first { $0.teamId == t.id }
                            Text("Record: \(st?.wins ?? 0)-\(st?.losses ?? 0)")
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            if store.difficultyBias != 0 {
                Text("🤖 AI difficulty \(store.difficultyBias > 0 ? "+" : "")\(Int(store.difficultyBias))")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.orange)
            }
        }
        .padding(.top, 12)
    }

    private func weekSection(_ season: Season) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WEEK \(season.currentWeek + 1)")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(.horizontal)
            if let g = season.playerGameThisWeek(pid: store.playerTeamId ?? UUID()) {
                let home = season.team(g.homeId)?.shortName ?? "?"
                let away = season.team(g.awayId)?.shortName ?? "?"
                ArcadeButton(text: "▶ PLAY: \(away) @ \(home)", color: .green) {
                    guard let homeT = season.team(g.homeId), let awayT = season.team(g.awayId) else { return }
                    store.screen = .game(Store.GameInfo(home: homeT, away: awayT,
                                                        isPlayoff: false, playoffIndex: nil,
                                                        week: season.currentWeek))
                }
            } else {
                Text("No game this week (bye or played).")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
            // Other games this week (already simmed or upcoming).
            ForEach(season.schedule[season.currentWeek].filter {
                $0.homeId != store.playerTeamId && $0.awayId != store.playerTeamId
            }, id: \.homeId) { g in
                HStack {
                    Text("\(season.team(g.awayId)?.shortName ?? "?") @ \(season.team(g.homeId)?.shortName ?? "?")")
                    Spacer()
                    Text(g.played ? "\(g.awayScore)-\(g.homeScore)" : "vs")
                }
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(.gray)
                .padding(.horizontal)
            }
        }
    }

    private func playoffSection(_ season: Season) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(season.championId == nil ? "🏆 PLAYOFFS" : "🏆 CHAMPIONS")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(.horizontal)
            if let champ = season.championId, let t = season.team(champ) {
                HStack {
                    TeamBadge(team: t)
                    Text("\(t.name) win it all!")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                ArcadeButton(text: "NEW SEASON", color: .green) {
                    store.screen = .teamSelect
                }
            } else {
                ForEach(Array(season.playoffBracket.enumerated()), id: \.offset) { idx, g in
                    let home = season.team(g.homeId)?.shortName ?? "?"
                    let away = season.team(g.awayId)?.shortName ?? "?"
                    HStack {
                        Text("\(away) @ \(home)")
                        Spacer()
                        if g.played {
                            Text("\(g.awayScore)-\(g.homeScore)")
                        } else if g.homeId == store.playerTeamId || g.awayId == store.playerTeamId {
                            Button("PLAY ▶") {
                                guard let homeT = season.team(g.homeId),
                                      let awayT = season.team(g.awayId) else { return }
                                store.screen = .game(Store.GameInfo(home: homeT, away: awayT,
                                                                    isPlayoff: true, playoffIndex: idx,
                                                                    week: g.week))
                            }
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                        } else {
                            Text("upcoming").foregroundColor(.gray)
                        }
                    }
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal)
                }
                // Eliminated? Sim the rest.
                if !season.playoffBracket.contains(where: {
                    !$0.played && ($0.homeId == store.playerTeamId || $0.awayId == store.playerTeamId)
                }) {
                    ArcadeButton(text: "SIM PLAYOFFS", color: .orange) {
                        store.simRestOfPlayoffs()
                    }
                }
            }
        }
    }

    private func standingsSection(_ season: Season) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STANDINGS")
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(.horizontal)
            ForEach(season.standings()) { st in
                HStack {
                    if let t = season.team(st.teamId) {
                        Text(t.shortName)
                            .foregroundColor(t.id == store.playerTeamId ? .green : .white)
                        Spacer()
                        Text("\(st.wins)-\(st.losses)")
                            .foregroundColor(.gray)
                    }
                }
                .font(.system(size: 16, design: .monospaced))
                .padding(.horizontal, 24)
            }
        }
    }
}
