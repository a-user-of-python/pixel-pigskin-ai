import SwiftUI

struct TeamSelectView: View {
    @EnvironmentObject var store: Store
    @State private var teams = League.makeTeams()

    var body: some View {
        VStack(spacing: 12) {
            ArcadeTitle(text: "PICK YOUR TEAM")
                .padding(.top, 20)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(teams) { team in
                        Button {
                            SoundFX.shared.play(.click)
                            store.newSeason(teamId: team.id)
                        } label: {
                            VStack(spacing: 8) {
                                TeamBadge(team: team)
                                Text(team.name)
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                Text("OFF \(team.offenseRating)  DEF \(team.defenseRating)")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(team.primaryColor, lineWidth: 2)
                                    )
                            )
                        }
                    }
                }
                .padding()
            }
            ArcadeButton(text: "BACK", color: .gray) { store.screen = .menu }
                .padding(.bottom, 20)
        }
    }
}
