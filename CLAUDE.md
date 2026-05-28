# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

MacPal — macOS desktop pet (Tamagotchi + RPG). SwiftUI + AppKit overlay. Multiple borderless transparent `NSWindow`s float above all Spaces: the pet itself, a draggable house, and any active monster. Menu bar app (`LSUIElement = true`), no Dock icon.

## Build & Run

Requires Xcode 16+ and `xcodegen` (`brew install xcodegen`). The `.xcodeproj` is generated — edit `project.yml` (not the pbxproj) and regenerate.

```bash
# Regenerate Xcode project after editing project.yml or adding/removing .swift files
xcodegen generate

# Debug build (ad-hoc signing, no entitlements)
xcodebuild -project MacPal.xcodeproj -scheme MacPal -configuration Debug \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Launch
open build/Build/Products/Debug/MacPal.app

# Force-quit (menu bar quit also works: Cmd-Q from 🐾 menu)
pkill -f MacPal
```

`xcodegen generate` is required whenever you add a new `.swift` file under `MacPal/`, because the target sources are globbed from the folder at generation time.

## Persistence (UserDefaults)

Defaults domain `com.teerapat.MacPal`:
- `MacPal.character` — selected character id (`cat`, `dog`, `slime`, `ghost`, `fish`, `octopus`, `alien`, `robot`, `dino`)
- `MacPal.stats.v1` — JSON-encoded `PetStats` (level, xp, hunger, happiness)

To preset state when debugging:
```bash
defaults write com.teerapat.MacPal MacPal.character -string "dino"
defaults delete com.teerapat.MacPal MacPal.stats.v1   # reset progress
```

## Architecture

### Single source of truth: `PetController`

`@MainActor @Observable final class PetController` owns all mutable state and drives every behavior loop. Three timers run off it:

1. **Behavior tick** (~30 Hz) — advances the `PetState` machine: `.idle`, `.walking`, `.walkingHome`, `.approachingEnemy`, `.fighting`, `.sleeping`, `.happy`, `.dragged`.
2. **Decay tick** (30 s) — drains hunger + happiness, persists `stats`.
3. **Monster spawn tick** (random 60–120 s) — possibly spawns a monster when pet is awake.

A fourth timer (`combatTimer`, 1 Hz) is created on demand when combat starts.

Mutating state from outside `MainActor` (e.g. inside `Timer` closures) uses `MainActor.assumeIsolated { … }` because Swift 6 strict concurrency is on.

### Window topology

AppKit windows are all borderless transparent `.floating` with `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`. SwiftUI views are mounted via `NSHostingView`. Each window registers mouse handling in its `NSWindow` subclass (not in SwiftUI) so click-vs-drag can be distinguished by pixel distance.

| Window | File | Purpose |
| --- | --- | --- |
| `PetWindow` | `PetWindow.swift` | The pet sprite (128×128). Drag → moves window + sets `.dragged`; click (<4 px move) → `handleClick`. |
| `HomeWindow` | `HomeWindow.swift` | Floating pixel house (144×144). Drag → publishes new origin via `controller.houseDidMove`. Click → opens Status Panel. |
| `MonsterWindow` | `MonsterWindow.swift` | Per-monster sprite + HP bar (96×96). Non-interactive (`ignoresMouseEvents = true`). One per active monster. |
| Status Panel | `HouseView.swift` + `HouseWindow.swift` | Regular titled `NSWindow` with stat bars + Feed/Play buttons + decorative room scene. Toggled via menu bar. |

`AppDelegate` owns all windows and bridges controller callbacks (`monsterDidSpawn`, `monsterDidDespawn`, `openStatusPanel`) to window lifecycle.

### Pixel sprite system

Sprites are encoded as arrays of equal-length character strings — one row per string, one char per pixel. Size is per-instance (`PixelSprite.size = rows.count`), so different characters can use different grids if needed (current chars are 32×32, monsters are 24×24).

`PixelPalette.map` is a global `[Character: Color]` lookup. **Adding a new color** = add an entry there before referencing the char in any sprite. Convention: uppercase = main shade, lowercase = darker shadow, family-specific letters per character (`O/o` cat orange, `B/b` dog brown, `T/t` dino teal, etc.). Highlights use a third letter (`L`, `N`, `M`, `H`, `V`, `Q`, `I`, `J`).

Rendering: `PixelSpriteView` (and inline `PetView.spriteCanvas`) draws each cell as an axis-aligned rect in a `Canvas`. Pixel size = `displaySize / sprite.size`, so use integer-divisible display sizes for crisp output (e.g. 32-grid at 128 px = 4×).

Characters live in `PetCharacters.swift` (Classic: cat/dog/slime/ghost) and `PetCharactersExtra.swift` (Ocean/Space/Prehistoric). Each `PixelCharacter` has 5 frames: `idle`, `walkA`, `walkB`, `sleep`, `happy`. `walkA`/`walkB` alternate at ~5 fps from `PetView`.

### Editing sprite blocks safely

Many sprite blocks are large (5 × 32 strings each) and the `Edit` tool sometimes fails to match against them. When swapping out a full character/frame block, **prefer a small Python script** that finds the `static let <name> = PixelCharacter(` line and the matching closing `    )`, then splices replacement rows. Examples of this pattern are in git history (commits with "fix: cuter chibi … sprite").

After any sprite change, every row in every frame MUST still be the same length as the sprite's first row, or `PixelSprite.init` will hit a `precondition` and the app crashes silently at launch.

### Combat & skills

`Monster` (`Monster.swift`) is `@MainActor @Observable` with `hp`, `hurtFlash`, and a `MonsterKind` (bat/goblin/skeleton — HP/atk/xpReward scale per kind). `PetSkill` (`PetSkills.swift`) defines damage range, cooldown, level requirement, visual effect kind, and cast color.

Each combat tick:
1. `selectSkill()` picks the highest-damage skill that's off cooldown for the pet's level.
2. Damage = `roll(skill.damage) + stats.level`.
3. `activeSkillCast` is set so `PetView` renders the effect overlay (`SkillEffectView`).
4. Monster bites back into happiness/hunger.
5. On monster death: `endCombat(victory: true)` awards `xpReward` and may trigger `levelUpFlashTrigger`.

Combat-interrupting interactions (drag, click) MUST call `stopCombatLoop()` in `beginDrag`/`handleClick` and resume via `startApproach()` when monster is still alive — see the `endDrag` / `handleClick` branches.

### Adding a new character

1. Define the sprite as `PixelCharacter` in `PetCharacters.swift` or `PetCharactersExtra.swift` (5 frames, all same square size, only chars from `PixelPalette.map`).
2. Append to `PetCharacters.allEcosystems`.
3. If using a new color family, add its 2–3 shades to `PixelPalette.map`.
4. No menu wiring needed — the Character submenu iterates `allEcosystems` grouped by `PetEcosystem`.

### Adding a new skill

1. Add the `PetSkill` constant in `PetSkills.swift` and append to `PetSkills.all`.
2. Add a case to `SkillEffectKind` and render it in `SkillEffectView.body` (Canvas drawing) and `PetView.skillSpriteOffset` (sprite displacement during cast).
3. `selectSkill()` will automatically use it once `stats.level >= levelRequired`.

### Adding a new monster

1. Add a case to `MonsterKind` with `maxHP`, `attack`, `xpReward`, and a sprite in `MonsterSprites.swift`.
2. `MonsterKind.allCases.randomElement()` in spawn logic auto-picks it.

## Design spec

Full design doc: `docs/superpowers/specs/2026-05-28-macpal-design.md` (architecture, state machine, build, concurrency notes). Treat it as the source of truth when behavior is unclear.
