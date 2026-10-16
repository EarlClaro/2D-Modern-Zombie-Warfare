# Decision Log (ADRs)

Format: ID · Status · Decision · Rationale · Consequences. Statuses: Accepted (stated in master prompt), Proposed (needs user approval), Superseded.

## ADR-001 — Engine and language · Accepted
Godot 4.x, typed GDScript. Installed: 4.7.2-stable. Rationale: master prompt default; solo-dev friendly. Consequence: no C#/GDExtension unless a measured need arises.

## ADR-002 — Fixed 2:1 isometric camera · Accepted
Logical floor tile 64x32 px diamond (~26.57°). Tile size is a constant in one place (`IsoProjection`). Camera pan + zoom only, no rotation. Change requires a new ADR.
Consequences: art authored at 2:1; 8-direction sprites; ellipse AoE indicators.

## ADR-003 — Ground-plane truth, altitude separate · Accepted
Gameplay in ground coordinates measured in **tiles** (float); altitude `z` is a separate float; projection used only for rendering/input via `IsoProjection.ground_to_screen / screen_to_ground`. Convention: ground +X = screen down-right; ground +Y = screen down-left.
Consequences: ranges/radii in tiles; no projection math elsewhere; a ground circle of radius r is an axis-aligned screen ellipse with semi-axes `r·TW/√2` × `r·TH/√2`.

## ADR-004 — Y-sort and layering · Accepted (details in spec)
Footprint base point is the sort anchor. Layers: ground → shadows → ground entities (y-sorted) → air → FX → HUD. Aircraft never share the ground y-sort group.

## ADR-005 — Occlusion approach: fade occluders · Accepted (2026-10-15)
Tall structures/props fade to ~40% alpha when a unit/enemy/placement preview is behind them on screen. Chosen over silhouette shaders for simplicity with placeholder art and robustness at horde density. Validate in Milestone 0.5; fallback is outline-silhouette shader. Look/feel is re-confirmed by the user at spike exit.

## ADR-006 — Test framework: minimal custom headless runner (no GUT yet) · Accepted (2026-10-15)
`godot --headless --path . --script tests/run_tests.gd` runs `tests/test_*.gd` (each exposes `test_*` methods, uses a tiny assert helper, exits non-zero on failure). Rationale: no external dependency, trivial to verify, pure-logic classes need little tooling. Revisit GUT if we need mocking/scene tests. Implemented in Milestone 0.5 step 1 (`tests/run_tests.gd`, `tests/test_case.gd`); verified it exits 1 on a failing assertion.

## ADR-007 — Mission end resolution · Accepted (2026-10-15)
Objectives evaluated once per tick after damage/death resolution; if win and fail are true on the same tick, **fail wins**. Ends mission once; further events ignored.

## ADR-008 — 8-direction sprites · Accepted (2026-10-15)
Units/vehicles/enemies use 8 facings (placeholders show facing). Fallback: 5 mirrored directions if art cost is too high; requires updating ASSETS.md.

## ADR-009 — Display baseline · Accepted (set in project.godot)
1920x1080 base viewport, `canvas_items` stretch, nearest texture filtering for pixel art. Revisit in Milestone 7 for UI scaling.

## ADR-010 — Multi-cell structure sort anchor = footprint centre · Accepted (2026-10-15)
Y-sort anchor for a multi-cell structure is the centre of its ground footprint (not the front corner). Entities on the +X/+Y sides of the footprint sort in front, beyond the far edges behind; verified in `test_iso_entities.gd`. Known limit: very large footprints can mis-sort against units diagonally adjacent; split such objects into several sorted pieces if it becomes visible. Confirmed at spike exit.

## ADR-011 — CP regeneration 3.0 s · Accepted (2026-10-16)
The economy spec's first draft was +1 CP per 1.5 s. The M2.6 sweep (`tools/tune_cards.gd`, [BALANCE.md](BALANCE.md)) showed that rate made the card mission about 25x too easy for the card power; keeping 1.5 s would have needed hordes of roughly 1,600 or more zombies per mission. Shipped value: **+1 CP per 3.0 s** (`data/config/deck_rules.tres`), with Rifle Squad cost 3. It is a tuning value, not a rule: expect it to move again when the enemy roster grows. Deferred, not decided: the tank being the carry card (prefer a cost/lockout change over damage or blast, which is a cliff), making artillery and the helicopter stronger per CP, and the roster/design caveats (melee-only Shamblers, ranged hitscan without ammo or overheat, units that never expire). Re-run the sweep once the Runner/Brute roster is in the mission.

## ADR-012 — Horde movement (A6): shared flow field, lane offset, optional separation · Accepted (2026-10-16)
Measured in M3.1 ([BALANCE.md](BALANCE.md), "Horde movement and the cost of a step"). **Proposal:** (1) enemies in a mission that opts in (`routing = flow`) steer down one **flow field** computed at setup from the core over cells that are walkable terrain and not covered by scenery (8-neighbour, no corner cutting); player units, structures and the core do not block (spec D2). (2) Each enemy refreshes its steering direction every 4th tick (staggered) and samples the field at its position plus a fixed per-enemy **lane offset**, so a column spreads sideways at no extra cost: the same overlap as today's waypoints, where a field without it stacks the horde into columns. (3) **Separation** (hash rebuilt and pushes refreshed every 4th tick, 8 neighbours) is optional: it costs about 1.1-1.7 ms at 1000-2000 alive (16-22 % of a tick) and cuts near-overlap from 31 % to 4 % at 8 spawns/s, but only from 78 % to 52 % at the shipped 25/s, which is denser than bodies can pack. (4) Waypoint walking stays available (default) so no shipped mission changes.
Rationale: the field finds routes the straight waypoint rule cannot (the straight line is blocked on `x2_outskirts`; the field's own route was 60.7 and 59.4 tiles against 68.0 and 66.6 for the hand-placed waypoints), removes the authoring rule that scenery must stay off the path, and costs about 1.4-1.6x the waypoint movement step (at most 1.9 ms at 2000 alive in the quieter run). Per-agent navigation (`NavigationAgent2D`) was not benchmarked: it works in screen space and costs per agent, against the master prompt's shared-path preference.
Consequences: a new pure `FlowField` and a lane/steering refresh in `BattleEnemy` (3.2); `ContentDb` must reject a spawn that cannot reach the core; field build is 0.1 s on a 64x48 map and about 0.5-1 s on an empty 128x128 (a bucket queue is the fix if a large map needs it). **Separate finding that changes the plan:** the whole simulation step already costs about 26 ms at 1000 alive and passes the 16.7 ms tick at roughly 600-700 alive, mostly from per-tick candidate allocation and all-pairs target search (not movement). The spec's 1000-alive target (D7) needs a step-cost increment before the stress run: **accepted by the user, added as increment 3.2** (movement becomes 3.3). User also decided: separation is included and on by default for flow missions.
