# Architecture

Status: draft v0.1. Keep minimal; add systems only when a milestone needs them.

## Principles
Ground-plane truth · data-driven `Resource` definitions vs runtime state · explicit signals/APIs, few autoloads · rules separate from UI and from visuals · seedable RNG · measure before optimizing.

## Coordinate spaces (authoritative: [specs/isometric-view.md](specs/isometric-view.md))
- **Ground space**: `Vector2` in *tiles* (float). +X = screen down-right, +Y = screen down-left. All gameplay.
- **Altitude**: separate `float z` (tile-height units). Never folded into ground position.
- **Screen/world-pixel space**: rendering and input only. Conversion only via `IsoProjection`.
- Grid cell = `Vector2i` = `floor(ground)`.

## Module map (created as milestones need them)
```
scripts/iso/       IsoProjection (pure static, no nodes), IsoPicking, SortAnchor
scripts/core/      ContentDefinition (base, id+validate), ContentDb (loads/validates data by id), GameSession (autoload, later), SeededRng helper
scripts/combat/    DamageService (pure), WeaponController, ProjectileSystem, TargetingService
scripts/cards/     CardDefinition, DeckDefinition, DeckRules (Resources); DeckState, CommandPoints, CardPlayService (pure, M2.1); later PlacementRules, CardEffects
scripts/missions/  MapDefinition, MissionDefinition, StartUnit, WaveEntry (Resources); MissionRules (pure win/fail, ADR-007); later: Objective subclasses, MissionDirector
scripts/save/      SaveService (autoload, M5)
data/              .tres definitions: cards, units, weapons, enemies, missions
scenes/battle/     Battle.tscn composes: GroundLayer (TileMapLayer), UnitsLayer (y_sort), AirLayer, FxLayer, Camera, HUD
tests/             headless test scripts
```

## Data flow (battle, target M2+)
```
Input (mouse) → IsoPicking → ground pos/cell
  → CardPlayController (checks DeckState + CommandPoints + targeting validity)
      → CardEffects[effect_id].execute(ctx) → DeploymentService / strike scheduler
UnitRuntime nodes → TargetingService → WeaponController → (hitscan | ProjectileSystem)
  → DamageService.apply(attack, target) → Health → died signal
MissionDirector listens to signals (core damaged, enemy died, timer) → evaluates objectives per tick → mission_ended
HUD presenters read state via signals; never mutate rules.
```

## Battle tick (as built, M1.4)
`BattleController.step(delta)`: (1) clock + wave spawns (seeded RNG), (2) enemies choose target/attack or advance and queue damage, (3) player units move/target/fire (hitscan) and queue damage, (4) apply all queued damage via `DamageService`/`Health`, then remove the dead, (5) `MissionRules.evaluate`. `_physics_process` calls `step` unless `auto_step` is false (tests step manually). Presentation reacts to signals (`shot_fired`, `enemy_died`, `battle_ended`, ...) and never feeds back into rules.

## Presentation (as built, M1.5)
`BattleFeedback` (a child of the battle) is the only presenter: it subscribes to controller signals and spawns transient effects on the controller's Fx layer, plays sounds through `SfxService`, shakes the camera and flashes/kicks entities. Rules never read anything it produces (verified by a test that runs the same battle with and without it). Entities carry only cosmetic helpers (`IsoEntity.flash`, `play_death`, `BattleUnit.kick`). Sound pooling is pure logic (`SfxVoicePool`).

## Key design choices
- **Pure logic classes** (`RefCounted`, no Node dependency) for IsoProjection, DamageService, DeckState, CommandPoints, objective evaluation → trivially headless-testable.
- **Definitions vs runtime**: `CardDefinition` (Resource, immutable) vs `CardRuntime`/`DeckState` entries (id + mutable lockout).
- **Projectiles**: data-oriented `ProjectileSystem` holding arrays of ground pos, velocity, z, vz; one `_physics_process`; rendered via one MultiMesh or `_draw` (decide in M1 by measuring). Not one node per bullet.
- **Physics**: ground-plane footprints (circles). Godot 2D physics used minimally (no physics in screen space). Hit detection = ground distance + altitude range overlap.
- **Layers** (CanvasItem z/y-sort): Ground tiles → shadows → ground entities (y_sort_enabled) → air entities → FX → HUD (CanvasLayer).
- **Hordes**: per-agent steering over a shared flow field is the leading candidate; decision deferred to M3 (A6). **M1 measurement:** straight-line waypoint walking for 100–500 enemies costs 0.5–1.9 ms per tick headless (see BALANCE.md), so path-following is not the bottleneck yet; the open problems are separation/overlap and real obstacle avoidance, which only matter once maps have non-trivial walls (M3+).
- **Autoloads (planned, max 4)**: `GameSession`, `SaveService`, `AudioService`, `SceneRouter`. None before they're needed.

## Testing seam
Anything with rules is a `RefCounted` class taking an injected `RandomNumberGenerator` and config; scene scripts are thin. See [TESTING.md](TESTING.md).

## Open items
Horde pathing/separation (A6, M3) · projectile render strategy (decided: none in M1 — hitscan only, D1; revisit with artillery/rockets in M2) · per-entity draw calls (~6 each; look at batching if hordes exceed ~500). Resolved earlier: occlusion = fade (validated in the spike), TileMapLayer layout = DIAMOND_DOWN + offset.
