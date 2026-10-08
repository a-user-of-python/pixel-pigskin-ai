import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("🏈")
                .font(.system(size: 72))
            ArcadeTitle(text: "PIXEL PIGSKIN")
            Text("ON-DEVICE AI FOOTBALL")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
                .tracking(4)
            Text("Your coach thinks. Your players fly.")
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(.gray)
            Spacer()
            ArcadeButton(text: "NEW SEASON", color: .green) {
                store.screen = .teamSelect
            }
            if store.season != nil {
                ArcadeButton(text: "CONTINUE SEASON", color: .blue) {
                    store.screen = .season
                }
            }
            ArcadeButton(text: "HOW TO PLAY", color: .orange) {
                store.screen = .howTo
            }
            Spacer()
            Text("🤖 AI coach on-device  •  📋 fallback offline")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.gray)
                .padding(.bottom, 20)
        }
    }
}

struct HowToView: View {
    @EnvironmentObject var store: Store

    let tips = [
        ("🎯 THROW", "Tap a receiver to lock on, then SWIPE to throw. Swipe direction aims, length sets power."),
        ("🏃 RUN", "DRAG anywhere to steer the ball carrier. Quick FLICK to juke a defender."),
        ("🦵 KICK", "On kicks, SWIPE UP. Straight = accurate, long = powerful."),
        ("🛡️ DEFENSE", "Drag your highlighted defender, or leave AUTO on and let the AI handle it."),
        ("🤖 AI BRAIN", "The on-device AI calls defensive plays and adjusts mid-play. Watch it adapt!"),
        ("📋 PLAY CLOCK", "Tap to snap early, or the play clock auto-snaps at zero."),
    ]

    var body: some View {
        VStack(spacing: 14) {
            ArcadeTitle(text: "HOW TO PLAY")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(tips, id: \.0) { tip in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tip.0)
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)
                            Text(tip.1)
                                .font(.system(size: 17, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                    }
                }
                .padding()
            }
            ArcadeButton(text: "BACK", color: .gray) { store.screen = .menu }
                .padding(.bottom, 20)
        }
    }
}
