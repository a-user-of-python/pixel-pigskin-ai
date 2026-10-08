import SwiftUI

@main
struct PixelPigskinApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

/// Original arcade-style root navigation (not a copy of any existing game).
struct RootView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ZStack {
            // Stadium-night backdrop.
            LinearGradient(colors: [Color(red: 0.03, green: 0.08, blue: 0.05),
                                    Color(red: 0.02, green: 0.03, blue: 0.08)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            switch store.screen {
            case .menu: MainMenuView()
            case .teamSelect: TeamSelectView()
            case .season: SeasonView()
            case .frontOffice: FrontOfficeView()
            case .howTo: HowToView()
            case .game(let info): GameView(info: info)
            }
        }
    }
}

// MARK: - Shared UI atoms (original "neon arcade" style)

struct ArcadeTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 52, weight: .black, design: .monospaced))
            .foregroundStyle(
                LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
            )
            .shadow(color: .orange.opacity(0.6), radius: 12)
            .multilineTextAlignment(.center)
    }
}

struct ArcadeButton: View {
    let text: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: { SoundFX.shared.play(.click); action() }) {
            Text(text)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(color)
                        .shadow(color: color.opacity(0.5), radius: 8)
                )
        }
        .padding(.horizontal, 40)
    }
}

struct TeamBadge: View {
    let team: Team
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(team.primaryColor)
                .frame(width: 64, height: 64)
            Text(team.shortName)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(team.secondaryColor)
        }
    }
}
