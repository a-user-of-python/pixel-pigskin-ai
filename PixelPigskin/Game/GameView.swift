import SwiftUI
import SpriteKit

/// SwiftUI wrapper around the SpriteKit game scene.
struct GameView: View {
    @EnvironmentObject var store: Store
    let info: Store.GameInfo

    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: makeScene(size: geo.size))
                .ignoresSafeArea()
        }
        .navigationBarHidden(true)
    }

    private func makeScene(size: CGSize) -> SKScene {
        let scene = GameScene()
        scene.size = CGSize(width: 1000, height: 700)
        scene.scaleMode = .aspectFill
        // From the player's perspective: playerTeam attacks, opponent defends.
        // Home/away only matters for score bookkeeping.
        let playerIsHome = info.home.id == store.playerTeamId
        scene.playerTeam = playerIsHome ? info.home : info.away
        scene.opponentTeam = playerIsHome ? info.away : info.home
        scene.difficultyBias = store.difficultyBias
        scene.onGameComplete = { [weak store] ps, os, updatedTeam in
            DispatchQueue.main.async {
                store?.completeGame(info: info, playerScore: ps, oppScore: os,
                                    updatedTeam: updatedTeam)
            }
        }
        return scene
    }
}
