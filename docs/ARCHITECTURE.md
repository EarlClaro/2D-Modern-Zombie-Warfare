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
scripts/cards/     CardDefinition, DeckDefinition, DeckRules (Resources); DeckState, CommandPoints, CardPlayService (pure, M2.1); PlacementRules (pure, M2.2), CardTargeting (pure selection + preview state, M2.3); later CardEffects
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

## Battle tick (as built, M1.4; cards M2.2)
`BattleController.step(delta)`: (1) clock, **card economy (`DeckState.tick`, `CommandPoints.tick`)**, wave spawns (seeded RNG), (2) enemies choose target/attack or advance and queue damage, (3) player units move/target/fire (hitscan; weapons with `blast_radius` queue falloff damage on every enemy in the ground circle, no friendly fire) and queue damage, then **(3b) `ProjectileSystem.tick`: each shell that lands queues the same kind of blast** (M2.4), (4) apply all queued damage via `DamageService`/`Health`, then remove the dead, (5) `MissionRules.evaluate`. `_physics_process` calls `step` unless `auto_step` is false (tests step manually). Card plays happen between ticks via `play_card(slot, cell)` (validate, spend, discard, lockout, spawn units); the deck has its own seeded RNG so playing cards never shifts spawn jitter. Presentation reacts to signals (`shot_fired`, `blast_landed`, `card_played`, `enemy_died`, `battle_ended`, ...) and never feeds back into rules.

## Unit behaviours (as built, M3.3)
Placed units decide for themselves (ADR-013); the player gives no move orders. `UnitBrain` (`scripts/combat/`, pure, no randomness) turns facts supplied by the battle into a `Decision` (stay, or move to a spot): `guard` (anchor + leash: go after the nearest enemy near the anchor, take a firing spot at 90 % of weapon range clamped to the leash, return to the anchor when idle), `advance` (go toward the enemy closest to the core, clamped to `advance_limit` from the core), `support` (stand next to the nearest friendly fighter), and HOLD (nothing). Every behaviour stops the moment something is in weapon range, because units fire only while standing. `UnitDefinition` carries `behavior`, `leash`, `advance_limit`, `follow_range` and `effective_behavior()` (fixed units and structures always hold). `BattleController._think_and_move` asks the brain, `_carry_out` validates the walk (`_walk_is_clear`: walkable terrain, not the core cell, not scenery; otherwise the unit stays) and issues the move through `BattleUnit.order_move`, which only the brain and the sortie flights use now. `BattleUnit.anchor` is the cell centre where the unit was placed. Sortie aircraft skip the brain. The enemy phase also records the enemy closest to the core (`_front_pos`) for ADVANCE units. Known limits: units walk straight lines (no routing around obstacles until the flow field, 3.11), do not avoid each other, and the Support behaviour only follows (healing and repair arrive with the support cards in 3.5).

## Enemy index and target queries (as built, M3.2)
`EnemyIndex` (`scripts/combat/`, pure apart from holding `BattleEnemy` references) is a 2-tile uniform grid over the map built with linked lists in packed arrays. `_enemy_phase` clears it, moves each enemy, then adds it at its new position; `_unit_phase` and `_queue_blast` query it (`nearest(origin, range)`, `box_candidates(centre, radius)`), and `_index_ready()` rebuilds it from `enemies` if it was marked stale (spawn, removal, restart). Answers equal a full scan: smallest squared ground distance, exact ties to the lowest id, blast candidates in `enemies` order with the caller applying the exact falloff. The enemy phase itself no longer builds target objects: it keeps the ground units' positions in reused packed arrays and rejects enemies that are too far from every target before comparing distances (same nearest-wins, lowest-id-on-ties rule as `TargetingService.pick`, which stays as the reference the tests compare against).

## Projectiles and operations (as built, M2.4)
`ProjectileSystem` (`scripts/combat/`, pure) keeps shells as parallel packed arrays, not nodes: a straight ground line `from`->`to`, altitude as a parabola on top (`altitude_profile`), a negative age = launch delay, cap 256, lands exactly once (1e-6 tolerance so a 0.9 s flight lands on its 54th 1/60 s tick). Ground position never depends on altitude. Measured: 256 shells in flight cost 0.46 ms per tick incl. per-shell queries. `OperationDefinition` (`data/operations/`, referenced by `CardDefinition.effect_id`) holds the barrage parameters and the even-spread (Vogel spiral) scatter + shuffled firing order from a dedicated seeded RNG. `BattleController` turns a played Operation card into queued shells plus a `Strike` telegraph (`strikes`), emits `strike_called` / `blast_landed`; views `StrikeTelegraph` (ground, `Decals` layer) and `ProjectileView` (one node drawing every shell + its ground shadow, new `Air` layer) only read that state. Blasts share one path (`_queue_blast`): armor, then distance falloff, enemies only.

## Sorties and missiles (as built, M2.5)
A Sortie card flies one aircraft along a `SortiePlan` (pure: nearest map edge -> station over the target -> opposite edge, entry/exit 5 tiles off the map) driven by `SortieFlight` (pure state machine ENTERING -> ON_STATION for `station_time_s` -> LEAVING -> DONE; the controller issues the move orders and removes the aircraft at DONE, which is not a loss). `BattleAircraft extends BattleUnit`: its node sits at the lifted screen position (ground position + altitude) on the unsorted `Air` layer, while `ground_pos` stays ground-plane truth and the `IsoShadow` stays on the ground. Ground enemies never target aircraft; aircraft never block build cells or fade the core. Weapons gained `ammo` (0 = unlimited), `can_fire_moving`, and real `PROJECTILE` delivery (`projectile_speed` = average speed, `projectile_accel` rocket-motor acceleration, `projectile_drop` launch dip). A unit may carry a `secondary_weapon_id` with its own cooldown/ammo: the helicopter fires its missile load (alternating wing pylons, firing on the move without turning off its flight line) on the way in, then hovers and uses the machine guns. Missiles are `ProjectileSystem` entries (kind MISSILE, launch altitude descending to the target, eased progress) that land through the same `_queue_blast` as shells. `ProjectileView` draws missiles as finned rockets with a motor flame, a continuous smoke trail and lingering puffs; `Explosion` (ground-radius fireball + shockwave + scorch + smoke) shows every area blast at its true radius.

## Card UI (as built, M2.3)
`CardTargeting` (pure) holds the selected hand slot and builds a `Preview` (valid?, why not, weapon range, blast radius, where units would stand) for the cell under the mouse; `BattleController` exposes `select_slot` / `cancel_selection` / `confirm_at(cell)` and the current `preview`, and emits `card_rejected`. `HandUi` (`ui/hand_ui.gd`) draws the five slots, CP pips, draw timer, pile counts, refusal toast and a cursor tooltip, and sends clicks back through the controller; `CardPreview` draws the target cell, range/blast ground circles and the deploy zone through `IsoProjection`. Both only read state; rules never live in them. Layout maths (`HandUi.slot_rect/slot_at/capture_rect`) is static and tested.

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
