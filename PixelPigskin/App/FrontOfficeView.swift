import SwiftUI

/// Franchise-lite front office: roster, salary cap, free agents, AI GM advice.
struct FrontOfficeView: View {
    @EnvironmentObject var store: Store
    @State private var advice: AIGM.RosterAdvice?
    @State private var loading = false

    var body: some View {
        VStack(spacing: 10) {
            ArcadeTitle(text: "FRONT OFFICE")
                .padding(.top, 12)

            // Salary cap bar.
            if let team = store.playerTeam {
                VStack(spacing: 4) {
                    Text("SALARY CAP  $\(store.capUsed())M / $\(store.salaryCap)M")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(store.capUsed() > store.salaryCap ? .red : .green)
                    ProgressView(value: Double(store.capUsed()), total: Double(store.salaryCap))
                        .tint(.green)
                        .padding(.horizontal, 40)
                }
            }

            // AI GM advice.
            VStack(spacing: 6) {
                Button {
                    loading = true
                    Task {
                        if let team = store.playerTeam, let season = store.season {
                            let st = season.standings().first { $0.teamId == team.id }
                            let a = await AIGM.shared.advise(
                                team: team, freeAgents: store.freeAgents,
                                record: (st?.wins ?? 0, st?.losses ?? 0))
                            await MainActor.run { advice = a; loading = false }
                        }
                    }
                } label: {
                    Text(loading ? "🤖 THINKING…" : "🤖 ASK AI GM")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.purple))
                }
                if let a = advice {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(a.title)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                        Text(a.detail)
                            .font(.system(size: 15, design: .monospaced))
                            .foregroundColor(.white)
                        Text(a.fromAI ? "🤖 on-device AI" : "📋 rule-based (no Apple Intelligence)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                    .padding(.horizontal)
                }
            }

            // Roster.
            Text("ROSTER")
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(.yellow)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(store.playerTeam?.roster ?? []) { p in
                        HStack {
                            Text(p.position.rawValue)
                                .frame(width: 44, alignment: .leading)
                                .foregroundColor(.orange)
                            Text(p.name).frame(maxWidth: .infinity, alignment: .leading)
                            Text("OVR \(p.overall)").foregroundColor(.gray)
                            // Stamina / morale mini-bars.
                            VStack(spacing: 2) {
                                bar(value: p.stamina, color: .green)
                                bar(value: p.morale, color: .blue)
                            }
                            .frame(width: 60)
                            Text("$\(AIGM.shared.salary(of: p))M")
                                .foregroundColor(.gray)
                        }
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    }
                }
            }

            // Free agents.
            Text("FREE AGENTS")
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(.yellow)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.freeAgents) { fa in
                        VStack(spacing: 4) {
                            Text(fa.name).font(.system(size: 14, weight: .bold, design: .monospaced))
                            Text("\(fa.position.rawValue)  OVR \(fa.overall)")
                                .font(.system(size: 12, design: .monospaced)).foregroundColor(.gray)
                            Text("$\(AIGM.shared.salary(of: fa))M")
                                .font(.system(size: 12, design: .monospaced)).foregroundColor(.green)
                            Button("SIGN") {
                                if !store.signFreeAgent(fa) {
                                    // Over the cap — shake handled by staying put.
                                }
                            }
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.green))
                        }
                        .foregroundColor(.white)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                    }
                }
                .padding(.horizontal)
            }

            ArcadeButton(text: "BACK", color: .gray) { store.screen = .season }
                .padding(.bottom, 16)
        }
    }

    private func bar(value: Int, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.15))
                RoundedRectangle(cornerRadius: 3).fill(color)
                    .frame(width: geo.size.width * CGFloat(value) / 100)
            }
        }
        .frame(height: 6)
    }
}
