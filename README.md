# Pixel Pigskin AI

A retro-style American football game for iOS/iPadOS, inspired by classic
8-bit football games — with a twist: **on-device AI** (Apple Foundation
Models) calls the plays, manages the roster, and adapts the difficulty.

## Features

- **Swipe-to-throw**: swipe direction aims, swipe length sets power. Tap a
  receiver to lock onto him before throwing.
- **Drag-to-run**: drag anywhere to steer the ball carrier; juke past defenders.
- **Playbook**: Slant, Go, Post, Curl, Draw, Sweep + Punt / Field Goal.
- **Full game loop**: downs, first downs, touchdowns, PATs, field goals,
  punts, interceptions, turnovers, 4 quarters, playoffs, championship.
- **Season mode**: 8 teams, round-robin season, 4-team playoff bracket.
- **Team management**: 8-man rosters with ratings, stamina, and morale; an AI
  GM suggests roster moves between games.
- **AI Coach** (on-device, iOS 26 Foundation Models): suggests a play every
  down based on down/distance, field position, score, and clock. Falls back
  to a rule-based coach on devices without Apple Intelligence.
- **Adaptive difficulty**: the AI quietly tunes opponent ratings based on how
  you're doing.
- **Retro look & sound**: programmatic pixel-art sprites (no assets), square-
  wave chiptune SFX generated in code, big high-contrast HUD.

## Project layout

```
PixelPigskin/
├── App/        SwiftUI entry + menus (main menu, team select, season, front office)
├── Game/       SpriteKit gameplay (scene, players, ball, playbook, real-time AI)
├── AI/         Foundation Models coach + GM, plus rule-based fallbacks
├── Models/     Team, Player, Season, GameState
└── Resources/
```

## Build

Unsigned IPAs are built by `.github/workflows/build-ipa.yml`
(workflow dispatch, optional `version` input). Requires Xcode 26+.

## Notes

- Real-time player movement uses traditional game AI (state machines +
  steering) — an LLM can't run at 60fps. Foundation Models are used only for
  pre-play decisions (play calling, roster moves), which is exactly what
  they're good at.
- All team names are parodies; no trademarks of any football league are used.
