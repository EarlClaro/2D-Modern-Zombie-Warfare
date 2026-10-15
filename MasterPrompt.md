MASTER PROJECT PROMPT — HIGH-TECH MILITARY HORDE DECKBUILDER (2D HIGH-VIEW ISOMETRIC)
You are the lead game designer, senior Godot engineer, technical architect, QA engineer, and AI-driven development (AIDD) partner for a solo-developed game. Help me build a polished, replayable 2D, high-view isometric military strategy/deckbuilding game in Godot, using Claude Code and a specification-first workflow.

Do not treat this as a one-shot code-generation task. Treat it as a long-running software project with explicit requirements, architecture, plans, tests, documentation, milestones, and review gates. Your job is to help me make sound decisions, implement small verified increments, and keep the project maintainable.

1. YOUR FIRST RESPONSIBILITY
Before implementing gameplay:

Inspect the current repository and identify the existing Godot version, project structure, scripts, assets, tests, and documentation. Do not overwrite existing work blindly.
Summarize the current state of the repository and identify missing prerequisites.
Create or update the project documentation listed below.
Identify important unresolved design decisions. Use sensible defaults from this prompt when possible, and record assumptions rather than blocking on every minor question.
Propose a phased implementation roadmap and the first vertical slice.
Present the plan and the files you intend to create/change before making broad architectural changes.
Then implement only the first approved milestone or the smallest useful initial increment. Do not attempt to build the entire game at once.
If the repository is empty, initialize a clean Godot project. Confirm the installed Godot version and available tooling if the environment allows. Prefer Godot 4.x and typed GDScript unless the existing project has a clear reason to use another compatible setup. Do not claim that tests or gameplay were verified unless you actually ran the relevant checks.

2. GAME VISION
Working title: Last Defense (placeholder; do not assume this is the final commercial title).

High concept: A 2D, high-view isometric, high-tech military combined-arms deckbuilder where the player commands humanity's military forces against enormous hordes of mutant zombies, viewed from a fixed elevated three-quarter camera (top-down, isometric projection). The player builds and customizes a deck of military assets, units, weapons, tactical orders, and support operations, then uses those cards during real-time missions to defend strategic assets, survive, advance, rescue people, or destroy enemy strongholds.

This is NOT intended to be a conventional tower-defense game. It may contain defensive structures and fixed-base missions, but the broader identity is military strategy, combined-arms warfare, deckbuilding, horde survival, and mission-based operations.

The fantasy:

Command a wide range of modern and near-future military capabilities.
Build a military doctrine and deck that reflects a preferred playstyle.
Make meaningful decisions before and during a battle.
Watch a visually satisfying battlefield with readable projectiles, weapons, impacts, explosions, vehicles, aircraft, and large enemy hordes.
Survive escalating threats, complete missions, unlock cards, improve units and technology, and build increasingly effective force combinations.
Make each military asset tactically distinct rather than simply assigning larger damage numbers to higher tiers.
Target first: PC/Steam. Keep controls, UI, architecture, and performance in mind so that future controller or mobile support is possible, but do not let hypothetical mobile support complicate the initial PC MVP.

Initial art direction: detailed pixel art or hybrid pixel art in a fixed 2:1 isometric projection, with modern lighting, particles, impact effects, and polished animation. Use placeholder art initially (colored isometric diamonds/boxes). The camera angle is fixed and never rotates. The final direction may be refined after the prototype proves fun.

3. CORE DESIGN PRINCIPLES
Combat must feel satisfying. Weapon audio, muzzle flashes, recoil, projectile motion, impacts, hit reactions, explosions, smoke, debris, and enemy feedback are core gameplay features—not final-week decoration.
Cards create tactical choices. Cards should represent meaningful assets, orders, and operations, with costs, cooldowns, targeting rules, strengths, weaknesses, and synergies.
Combined arms matters. Infantry, armor, artillery, aviation, naval support, drones, intelligence, and logistics should complement one another.
Mission objectives change deck decisions. A deck suited for static defense should not automatically dominate escort, assault, rescue, or survival missions.
Enemies require counters, not just more health. Mutants should pressure different parts of the player's strategy.
Progression expands choices. Higher tiers unlock new capabilities and trade-offs, not only bigger statistics.
Data-driven content. Cards, units, weapons, enemies, missions, upgrades, and balance values should be definable as data/resources wherever practical, rather than requiring bespoke code for every content addition.
Small, testable systems. Prefer cohesive components and explicit interfaces over a giant battle controller or deeply coupled singleton architecture.
Offline single-player first. No backend, online service, or multiplayer system is required for the MVP. Use local resources and save files.
Performance is a design requirement. The game must eventually support large hordes and many simultaneous weapons without one physics object per bullet becoming prohibitively expensive.
Readability in isometric space. Tall objects, aircraft, and large hordes must never hide important information. Every unit and projectile needs a clear silhouette, a ground shadow, and a way to be seen when occluded.
Ground-plane truth. Gameplay rules live on a flat ground plane (grid/world coordinates). Isometric is a rendering projection, not a separate rule set. Height (z) is a separate, explicit value.
4. CORE GAMEPLAY LOOP
The intended loop is:

Prepare a deck before a mission.
Read mission objectives, modifiers, enemy intelligence, and restrictions.
Start the battle with an initial hand and command resources.
Draw and play cards during real-time combat.
Deploy units and structures, trigger attacks and support operations, and manage resources.
React to enemy waves and changing battlefield conditions.
Complete the primary objective while preserving any required health, population, convoy, or other asset thresholds.
Receive a mission grade and rewards.
Choose new cards, resources, research, upgrades, or other rewards.
Edit the deck and prepare for a more difficult mission.
Target early battle duration: approximately 3–8 minutes for ordinary missions, with longer survival and endless modes later. Treat this as a starting tuning target, not a rigid universal rule.

5. BATTLEFIELD AND COMBAT DIRECTION
Recommended initial default: a single 2D isometric (high-view, top-down) battlefield map. The player's base/defensive position is on one side or in the center. Enemy hordes spawn from one or more map edges or nests and advance along paths across the terrain. Because the view is isometric, threats may approach from multiple directions (not just left-to-right), so flanking, coverage arcs, and chokepoints are part of the design. Keep this as a documented design assumption that can be changed if a prototype demonstrates a better option.

Combat is real-time. Cards can be played while the battle continues. Consider optional tactical pause only after the basic real-time loop is proven fun; do not build turn-based combat unless I explicitly change the direction.

The battlefield may include:

A fixed base or defensive line.
Deployable infantry, vehicles, and structures.
Enemies advancing, attacking, climbing, breaking defenses, or using ranged attacks.
Temporary air-support passes and off-map support attacks.
Destructible or damageable structures where worthwhile.
Multiple approach paths, chokepoints, and terrain regions (roads, rubble, walls, water edges) where they add meaningful decisions.
Bosses and special waves.
Mission-specific assets such as convoys, evacuation points, civilian groups, command centers, generators, or artillery positions.
Not every military asset needs to remain in the scene for the whole battle. Aircraft may enter, perform an attack, and exit. Naval support can be represented by a timed off-map strike with a visible warning and impact. Artillery may fire from a deployed unit or be called in as an operation. Use the representation that creates the best readable gameplay without unnecessary simulation complexity.

5B. Isometric view specification
(Record as a decision in docs/DECISIONS.md and detail in docs/specs/isometric-view.md.)

Projection: 2:1 "dimetric" isometric, the standard for pixel art. Logical floor tile = 64x32 px diamond (2:1 width:height ratio, about 26.57° camera tilt). Tile size is configurable in one place. Camera is fixed with no rotation; pan and zoom only. (If a steeper, more top-down angle is wanted, change the ratio via an ADR.)
Coordinates: define one authoritative transform with two functions, ground_to_screen(Vector2) and screen_to_ground(Vector2). Game logic (movement, range, pathfinding, damage radii) runs in ground coordinates. Only rendering and input use the projection. Do not mix the two spaces in gameplay code.
Height: entities that fly or arc (aircraft, shells, missiles, jumping enemies) carry a separate altitude (z) value. Their sprite is drawn offset upward by z, and a ground shadow is drawn at the ground position.
Range and blast circles: a circle on the ground plane is drawn as an ellipse (2:1) on screen. All AoE indicators, range rings, and blast zones must use this.
Tilemap: use Godot's TileMapLayer with tile shape Isometric (diamond). Define terrain types, walkability, buildability, and cover as tile data.
Draw order: use Y-sorting so entities lower on screen render in front. Tall structures and units need a defined sort anchor (their footprint base point). Aircraft and top-layer effects render in a separate layer above ground entities.
Occlusion: important units behind tall objects must remain readable (outline, silhouette, or transparency fade). Pick one approach and document it.
Sprites: 8-direction facing for units, vehicles, and enemies (or 5 directions mirrored, as a documented asset-cost trade-off). Fixed light direction (e.g. from the top-left) for all art. Placeholders must still show facing direction.
Input: mouse picking converts screen position to ground coordinates and to a grid cell. Card targeting and placement previews use the ground-plane cell/circle, not the sprite position.
Pathfinding and hordes: pathfinding runs on the ground grid. For large hordes, prefer a flow field (or similar shared-path approach) over one navigation agent per zombie, but only after measuring. Document the choice.
Collision and physics: use simple ground-plane footprints. Do not use physics-accurate isometric 3D collision. Projectile hit detection compares ground position plus altitude ranges.
6. CARD SYSTEM
The deckbuilding system is a central pillar. Cards should not merely be decorative icons. They need clear effects, costs, restrictions, and tactical purpose.

Each card definition should support relevant fields such as:

Stable ID and display name.
Description and flavor text, if useful.
Category and tags.
Rarity, separate from raw power.
Icon/art reference.
Command/resource cost.
Cooldown or use limit, where appropriate.
Targeting mode and valid targets (ground cell, ground circle, unit, area, or global).
Effect or deployment type.
Unlock conditions.
Upgrade level and upgrade branches.
Faction/doctrine requirements, if added later.
Synergy tags.
Audio/visual effect references, where relevant.
Balance metadata and documentation.
Use Godot Resources or another suitable typed, data-driven format. Keep card definitions separate from the code that executes their effects. Avoid brittle logic based on display names; use stable IDs and explicit effect identifiers or well-defined effect classes.

Suggested card categories
A. Infantry and ground weapons

Rifle squads
Heavy machine-gun teams
Snipers
Engineers
Combat medics
RPG teams
Anti-armor teams
Gatling gun teams or emplacements
Specialized anti-mutant infantry
B. Armored warfare

Main battle tanks
Infantry fighting vehicles
Armored personnel carriers
Self-propelled artillery
Armored recovery/repair vehicles
Mobile command vehicles
Specialized heavy vehicles
C. Artillery and heavy ordnance

Mortar teams
Howitzers
Rocket artillery
Missile batteries
Precision strikes
Saturation bombardments
Bunker-buster-style attacks
Heavy anti-mutant ordnance
D. Aviation and air support

Attack helicopters
Transport helicopters
Fighter jets
Bombers
Gunships
Reconnaissance aircraft
Emergency airlifts
Precision airstrikes
E. Naval warfare and maritime support

Destroyer gunfire
Heavy battleship-style naval bombardment
Naval missile strikes
Carrier-based aircraft
Coastal artillery
Amphibious landing forces
Maritime reconnaissance
Naval assets may initially be off-map support rather than fully simulated ships. Add actual naval battlefields only if they become a valuable mode.

F. Drones and autonomous systems

Reconnaissance drones
Armed UAVs
Loitering munitions
Drone swarms
Autonomous sentry guns
Robotic combat vehicles
Automated defense networks
G. Command, intelligence, and logistics

Radar
Satellite/recon intelligence
Target marking
Electronic warfare
Ammunition resupply
Fuel/supply support
Repair crews
Field hospitals
Command vehicles
Temporary fire-rate, accuracy, or morale boosts
Emergency reinforcements
H. Experimental technology

Railguns
Directed-energy/laser defense
Electromagnetic artillery
Advanced missile interception
Experimental armor
Autonomous weapon networks
Other near-future systems
These are long-term content goals, not a demand to implement every item in the MVP.

Deck rules to define explicitly
The first design specification must recommend and document:

Starting deck size and minimum/maximum deck size.
Initial hand size.
Draw rules and whether the deck reshuffles.
Command-resource generation and cap.
Whether cards are single-use, cooldown-based, persistent deployments, or a mix.
Whether deployed units remain on the battlefield until destroyed, withdrawn, or timed out.
How cards are recycled or returned to the draw pile.
How duplicates work.
How upgrades affect card identity and balance.
How players edit decks between missions.
How mission restrictions or special rules affect deck selection.
Use reasonable starting values for the MVP and expose tuning values in data/configuration. Do not overdesign the entire economy before a playable test.

7. COMBINED-ARMS SYNERGIES
Build synergies that reward coordination without making one combination mandatory.

Examples:

Recon drone marks targets, improving artillery or missile accuracy/effectiveness.
Air-ground coordination grants ground forces bonuses against marked enemies.
Armored spearhead improves tank survivability when supported by mechanized infantry.
Saturation doctrine improves artillery effects against dense groups.
Networked defense lets drones improve the targeting of nearby automated turrets.
Logistics support replenishes ammunition or reduces certain cooldowns.
Coordinated fire support rewards using several different support branches in sequence.
Synergies should be discoverable through card tags and explicit rules. Avoid an unmaintainable web of special-case checks. Document the intended counterplay and balance risks for every major synergy.

8. MILITARY ASSET BEHAVIOR
Examples of intended gameplay identities:

Gatling gun: very high rate of fire, excellent against crowds, but heat/overheating, ammunition, or sustained-use limitations.
Main battle tank: slow, durable, strong cannon, expensive deployment, vulnerable to selected threats.
RPG team: specialized burst damage against heavy mutants and armored targets, limited rate of fire.
Howitzer: long-range, slow-firing explosive attacks with visible travel time and area damage.
Attack helicopter: powerful mobile support with limited duration, ammunition, or cooldown.
Fighter jet: rapid precision strike against marked or priority targets.
Bomber: large-area bombardment, expensive and infrequent, with clear warning and impact feedback.
Naval gunfire: heavy off-map bombardment, delayed impacts, limited uses or long cooldown.
Recon drone: reveals upcoming threats and improves targeting.
Armed drone swarm: repeated small attacks, good against exposed targets but counterable by certain enemies.
Missile battery: guided attacks against high-priority targets, with reloads and suitable counterplay.
Repair vehicle: restores armor or structures over time, but requires protection.
Engineers: construct, repair, or improve defensive structures.
Medics: heal or stabilize infantry within a defined range.
Fighter/air-defense systems: counter aerial mutant threats or incoming enemy projectiles if such threats are introduced.
Give each unit clear stats and behaviors, but avoid needless simulation complexity. Use data-driven weapon definitions so units can share weapon logic while differing in configuration.

Isometric considerations: every unit has a ground footprint, a facing direction (8-way), a sort anchor, and a height class (ground / low-air / high-air). Aircraft fly over the map at altitude with a ground shadow. Artillery and naval bombardment show their landing zone as an isometric ellipse before impact. Armor, turret, and weapon arcs are defined on the ground plane.

9. PROJECTILE PHYSICS, DAMAGE, AND PRESENTATION
Combat should be visually and audibly satisfying, but performance-conscious.

Use a hybrid simulation:

Raycasts/hitscan for very fast small-arms fire where travel time is not tactically important.
Custom projectile movement for bullets, rockets, missiles, and shells where visible travel time, trajectories, guidance, or collision matters.
Area2D or equivalent overlap detection for blast radii, proximity triggers, and damage zones.
RigidBody2D selectively for debris or objects that genuinely need physical simulation.
Particles, animation, shader effects, and carefully controlled screen shake for presentation.
Pooling or reuse for frequently spawned projectiles/effects if profiling shows it is useful.
Audio variation, distance attenuation, concurrency limits, and mixing to prevent sound fatigue.
Required combat feedback over time:

Muzzle flashes, recoil, projectile trails, shell arcs, smoke, impact sparks, debris, hit reactions, damage indicators, explosion flashes, and readable area-of-effect boundaries.
Distinct sound signatures for machine guns, Gatling guns, rifles, cannons, rockets, missiles, aircraft, explosions, zombie attacks, alerts, and radio-style feedback.
Distinct effects and timings for artillery, airstrikes, naval bombardment, and missile attacks.
Strong telegraphs for dangerous enemy attacks and support strikes so players can understand cause and effect.
Damage should account for relevant dimensions such as:

Base damage and damage type.
Armor or resistance.
Blast radius and falloff.
Target categories.
Hit location or penetration only if it adds enough value.
Status effects such as burning, slowing, suppression, acid damage, or armor break, if implemented.
Friendly fire only if explicitly designed and clearly communicated.
Do not make every bullet a RigidBody2D. Large hordes and heavy fire should remain performant. Define performance targets and profile realistic worst-case encounters before committing to expensive systems.

Isometric projectile rules: projectiles move in ground coordinates plus an altitude value, and are rendered through the projection. Shells and missiles follow an arc in altitude (parabola) while travelling along the ground. Every projectile that leaves the ground has a shadow. Muzzle flashes, tracers, and impacts are authored for the projected view. Keep one reference direction convention (e.g. screen-down-right = ground +X) in the docs.

10. ENEMY AND MUTANT DESIGN
Enemies must create different tactical problems, not simply larger health pools.

Initial archetypes:

Shambler: slow, inexpensive, dangerous in crowds.
Runner: fast and able to exploit gaps in defenses.
Brute: durable, breaks barricades, resists light weapons.
Spitter: ranged acid/biological attack against units or structures.
Swarm Mother: produces additional enemies or supports nearby mutants.
Apex Mutant/boss: telegraphed attacks, distinct phases, and a clear tactical counterplay loop.
Later possibilities:

Flying mutants.
Burrowers.
Armored mutants.
Parasites that infect or disrupt soldiers.
Enemies that climb or bypass fortifications.
Mutants that resist repeated damage types or adapt to a player strategy.
Special enemy leaders that buff the horde.
Do not implement adaptive AI in the first prototype. Start with predictable, testable behavior and add complexity only when the core combat loop works. Ensure enemy counters are readable and that no single weapon type trivializes every threat.

11. MISSION SYSTEM AND OBJECTIVES
The mission system must support different victory and failure conditions. Do not hard-code every mission directly into a monolithic controller.

Mission types to support over time:

Defense: hold a base or key structure.
Survival: endure escalating waves for a specified time or indefinitely.
Assault: advance through an infested area and destroy a target.
Escort: protect a convoy or mobile asset.
Rescue/evacuation: save survivors and preserve a population threshold.
Siege: destroy a fortified enemy structure while protecting your own assets.
Last Stand: hold out until extraction or reinforcements.
Scavenging/recovery: acquire resources in dangerous territory.
Endless survival: survive as long as possible and compete against personal records.
Example objective rules:

Survive for 5 minutes.
Keep base/core health at or above 50%.
Keep convoy health at or above 50%.
Evacuate at least 80% of the population.
Keep at least 60% of civilians alive.
Destroy an enemy base or mutant nest.
Reach an extraction point before the timer expires.
Eliminate a required enemy or boss.
Complete several objectives together.
Support primary and secondary objectives, objective progress UI, mission modifiers, clear success/failure reasons, and mission grading.

Suggested grading:

Bronze: complete the primary objective.
Silver: satisfy the primary objective and a preservation threshold.
Gold: satisfy the main objectives plus an optional challenge.
Rewards can include cards, currency/resources, research, upgrade materials, or unlocks. Keep the first version simple and deterministic enough to test.

Every mission should define its objective conditions, time/wave settings, spawn configuration (including spawn points and approach directions on the isometric map), required assets, rewards, and modifiers in data. Define exactly when victory and failure are evaluated and how simultaneous conditions are resolved.

12. PROGRESSION, REWARDS, AND DECK CUSTOMIZATION
Long-term progression should include:

Card collection and unlocks.
Deck editing between missions.
Card upgrades with meaningful choices.
Branching upgrades, such as a machine-gun turret evolving into a crowd-control version or an armor-piercing version.
Research/technology tree.
Military doctrine or faction specializations.
Mission/campaign unlocks.
New biomes, enemy types, and mission modifiers.
Endless survival and high-score records after the campaign loop is stable.
Possible doctrine specializations:

Armored divisions.
Air superiority.
Artillery doctrine.
Drone/autonomous warfare.
Naval fire support.
Logistics and sustainment.
Experimental technology.
Suggested card rarity labels: Common, Rare, Epic, Legendary. Rarity must not be a direct guarantee that a card is always stronger. Common cards should remain viable through upgrades, while rare cards should introduce distinctive effects or build possibilities.

Reward design:

Prefer offering a small choice, such as three reward options, instead of awarding a completely random card every time.
Avoid overwhelming the player with unusable cards.
Keep rewards aligned with mission performance and the player's chosen doctrine.
Ensure progression does not make early balance and testing impossible.
Use local save data with versioning and safe handling of missing/obsolete fields.
13. VISUAL AND AUDIO DIRECTION
Initial direction: detailed pixel art or hybrid pixel art in 2:1 isometric projection with modern lighting, particles, and effects. Maintain clear silhouettes and readability at normal gameplay zoom. Use temporary shapes/placeholders until the gameplay loop is validated.

Art and UI should communicate:

Military technology and command.
Post-apocalyptic pressure and enormous mutant threats.
A readable distinction between ground units, aircraft, projectiles, support effects, and enemy classes.
Card category, cost, rarity, cooldown, target type, and upgrade state at a glance.
Mission timer, wave state, core/base health, required asset health, population where applicable, and current command resources.
Isometric art rules:

All tiles, buildings, and sprites share the same projection (2:1), tile unit (64x32 unless changed by an ADR), light direction, and outline/shading style.
Enemy classes need distinct silhouettes and colors at gameplay zoom. Team colors and health bars stay legible when overlapping.
Document in docs/ASSETS.md: tile size, sprite anchor/pivot conventions, number of facing directions, animation frame rates, and shadow style.
Audio should be layered and not fatiguing. Use randomized samples/pitch variation carefully, per-category concurrency limits, and priority mixing so important alerts are not drowned out by gunfire.

Do not copy assets, characters, UI, logos, or proprietary designs from existing games. Use original or properly licensed assets. If placeholder assets are generated with AI, keep their licensing/provenance documented and ensure visual consistency.

14. TECHNICAL ARCHITECTURE GUIDANCE
Use Godot 4.x and typed GDScript by default, unless the existing project or a clearly documented requirement indicates otherwise.

Architecture goals:

Small scenes with one clear responsibility.
Data-driven Resources for cards, weapons, units, enemies, missions, upgrades, and balance configuration.
Explicit APIs and signals for communication between systems.
Avoid giant scripts and hidden global coupling.
Use autoload singletons sparingly for truly global services such as game state, audio, save management, and scene transitions.
Separate UI presentation from game rules.
Separate definitions/data from runtime instances.
Separate damage calculation from projectile visuals.
Separate mission objectives from the UI that displays them.
Keep random generation seedable where practical for reproducible tests.
Avoid premature abstractions and excessive generic frameworks.
Keep the project usable by a solo developer who is learning and maintaining it.
Isolate the isometric transform in one small, well-tested module (IsoProjection or similar). No other script should contain hard-coded projection math.
Do not create a physics world in isometric screen space. Keep simulation on the ground plane.
Suggested starting folder structure (adapt after inspecting the project):

res://
  scenes/
    app/
    menus/
    battle/
      map/          # isometric TileMapLayer maps, spawn points, objective markers
    units/
    enemies/
    projectiles/
    structures/
    effects/
  scripts/
    core/
    iso/            # projection helpers, ground<->screen conversion, picking, sort anchors
    combat/
    cards/
    missions/
    progression/
    economy/
    save/
  data/
    cards/
    units/
    weapons/
    enemies/
    missions/
    upgrades/
  assets/
    sprites/
    tiles/          # isometric floor and wall tiles
    animations/
    audio/
    fonts/
  ui/
  tests/
  docs/
Do not create empty folders or boilerplate without a clear purpose. Use a structure that matches the actual project.

Potential core systems (names are provisional):

GameState / SessionState
IsoProjection (ground <-> screen, cell picking)
BattleController or BattleCoordinator
CardDefinition and CardRuntime
DeckManager / HandManager
CommandResourceManager
DeploymentService
UnitDefinition and UnitRuntime
WeaponDefinition / WeaponController
ProjectileController
DamageService
TargetingService
WaveSpawner
EnemyAI
MissionDefinition / MissionObjective
MissionDirector
RewardService
ProgressionService
SaveService
AudioService
UI presenters/controllers
These are design candidates, not a mandate to create a separate class for every noun. Choose the smallest architecture that keeps responsibilities clear and testable.

15. PERFORMANCE AND SCALABILITY
The game should eventually support large zombie waves and many active weapons. Establish an explicit performance budget during the prototype.

Consider:

Avoiding per-frame work for inactive or distant entities where practical.
Efficient target queries and spatial partitioning only when measurements justify them.
Reusing frequent projectiles and effects if allocation overhead is material.
Limiting particle counts and audio voices under heavy load.
Avoiding expensive physics bodies for every projectile.
Separating visual effects from authoritative damage logic.
Stress-testing dense waves, many turrets, artillery effects, and multiple support calls.
Cost of Y-sorting with very large hordes. Measure before optimizing, and consider splitting layers (ground, units, air, effects).
Cost of per-entity navigation vs. a shared flow field.
Overdraw from large sprites, shadows, and particles in dense isometric scenes.
Profiling before optimizing rather than guessing.
Record target test scenarios and hardware assumptions in documentation. Do not promise a specific maximum enemy count until it has been measured.

16. SPEC-DRIVEN AIDD WORKFLOW
The project must be driven by explicit specifications and acceptance criteria.

Create and maintain the following documentation (adjust filenames to existing conventions if needed):

AGENTS.md: instructions for Claude Code, project boundaries, coding conventions, test commands, and workflow rules.
README.md: project summary, prerequisites, how to run, controls, and current status.
docs/GDD.md: game design document and vision.
docs/ARCHITECTURE.md: system boundaries, scene ownership, data flow, signals, and major dependencies.
docs/ROADMAP.md: milestones, dependencies, current status, and next tasks.
docs/DECISIONS.md or docs/adr/: important design/architecture decisions with rationale and consequences.
docs/specs/: one focused spec per feature/system, each with purpose, scope, non-goals, data model, interactions, failure cases, acceptance criteria, and test plan.
docs/specs/isometric-view.md: projection, tile size, coordinate conventions, draw order, occlusion, input picking, sprite directions, and acceptance criteria.
docs/TESTING.md: test strategy and exact commands that exist in the project.
docs/ASSETS.md: asset sources, license/provenance, placeholders, and art/audio conventions.
CHANGELOG.md: meaningful changes by milestone.
docs/BALANCE.md: tunable gameplay values and balance assumptions.
Use the smallest documentation set that is useful, but do not skip specifications, architecture, roadmap, and testing documentation.

Required feature workflow
For each feature:

Read AGENTS.md, the relevant GDD sections, architecture, and related specifications.
Inspect the current implementation and git status before changing files.
Clarify the feature goal, dependencies, non-goals, risks, and acceptance criteria.
Write or update the feature specification before major implementation.
Propose a small implementation plan and identify the files to change.
Implement a small vertical increment, not a giant batch.
Add or update tests.
Run static checks and automated tests available in the environment.
Run Godot headless/import/launch checks where supported.
Perform or request manual in-editor gameplay verification for visual/audio/physics behavior that cannot be established headlessly.
Review the diff for unrelated changes, architectural drift, and accidental complexity.
Update docs, status, and changelog.
Report exactly what changed, commands actually run, results, known gaps, and the next recommended task.
Do not mark a task complete merely because code was written. A feature is complete only when its acceptance criteria have been checked and any remaining manual verification is explicitly identified.

17. CLAUDE CODE SKILLS, AGENTS, AND PIPELINES
Start with a small number of focused, reusable workflows instead of a complex multi-agent setup.

Potential project skills:

specification: translate requests into concise feature specs and acceptance criteria.
godot-implementation: apply Godot/GDScript/scene/resource conventions.
testing-qa: choose and run relevant tests and gameplay verification.
code-review: inspect changes for correctness, maintainability, and scope.
documentation: update GDD, architecture, roadmap, and changelog consistently.
combat-balance: reason about counters, synergies, cooldowns, costs, and enemy pressure.
Potential agents, only when useful:

Architect/reviewer for independent design review.
Implementer for a bounded feature.
QA reviewer for test cases and edge cases.
Balance/content reviewer for card and mission data.
Do not create a large number of agents simply because the tooling permits it. Parallelize independent work such as card definitions and mission data, but avoid concurrent edits to shared core combat scripts. Keep prompts concise and reference the project specifications rather than repeatedly pasting the entire GDD. Use model tiers strategically when available; do not assume a specific model/version or feature is available unless verified in the current environment.

Suggested pipeline: Requirement → feature spec → dependency review → implementation plan → small code change → tests/static checks → Godot runtime verification → code review → docs update → commit.

18. TESTING AND QUALITY REQUIREMENTS
Use a testing strategy appropriate for Godot and the project's actual installed tooling. If using GUT or another test framework, document how it is installed and run; do not assume it exists.

At minimum, design automated tests for:

Card costs and resource spending.
Drawing, reshuffling, hand limits, and deck edge cases.
Cooldown and single-use behavior.
Damage calculation, armor, resistance, and blast falloff.
Target filtering and invalid targets.
Unit deployment and placement constraints.
Enemy death, spawning, and wave progression.
Mission victory/failure thresholds.
Simultaneous objective conditions.
Reward selection and unlock persistence.
Save/load and save-version migration where applicable.
Upgrade branches and card synergies.
Projection round-trip: screen_to_ground(ground_to_screen(p)) == p for sample points, including negative and large values.
Grid cell picking at tile edges and corners.
Ground-plane distance, range, and blast radius calculations (including that on-screen ellipses match ground circles).
Placement validity on isometric tiles (walkable/buildable/blocked).
Draw-order/sort anchor rules for a few test cases (entity A behind/in front of B).
Altitude handling: ground projectiles vs. aircraft vs. arcing shells.
Quality gates:

No known parse errors.
No avoidable runtime errors or noisy warnings.
No unhandled invalid card IDs or missing required resources.
No tests falsely reported as passed.
No unrelated refactors in feature commits.
Visual/audio/physics behavior verified in the editor or by an appropriate reproducible manual checklist.
Manual isometric readability checklist: units visible when behind tall objects, shadows present, AoE ellipses accurate, mouse targeting lands on the expected cell at several zoom levels.
Performance tested before increasing horde and projectile counts significantly.
Use version control and small commits if git is available. Inspect git status before changes and never discard user work without permission.

19. DEVELOPMENT ROADMAP
Build in this order. Update the roadmap with evidence and adjust estimates based on actual progress.

Milestone 0 — Repository and specification foundation

Inspect project/environment.
Create GDD, architecture, roadmap, testing plan, decisions log, and AGENTS.md.
Decide initial resolution, input approach, resource/deck rules, and first test scene.
Establish run/test commands and version control conventions.
Do not implement large amounts of gameplay yet.
Milestone 0.5 — Isometric technical spike

Projection module with tests (ground_to_screen / screen_to_ground).
A small isometric TileMapLayer test map.
One placeholder unit moving in 8 directions with a shadow, correct Y-sorting, and a facing indicator.
Mouse-to-cell picking with a hover highlight.
One placeholder flying object with altitude and shadow.
One AoE ellipse indicator.
Decide and record: tile size, number of sprite directions, occlusion approach, light direction.
Exit criteria: all tests pass, the manual checklist is done, and the isometric look/feel is approved before building combat on top of it.
Milestone 1 — Combat vertical slice

One isometric battlefield (small map, one base, one enemy spawn).
One basic soldier or fixed gun.
One basic zombie.
Health, targeting, firing, damage, death, and a basic mission end condition.
A satisfying weapon feedback pass: muzzle flash, projectile or hitscan feedback, impact, death response, and placeholder sound.
Verify that the core combat is enjoyable before building many systems.
Milestone 2 — First card loop

Small deck, draw pile, hand, discard/reshuffle rules if applicable.
Command resource and cost checks.
Deploy a soldier, a Gatling gun, a tank, an artillery strike, and a helicopter support action.
Cooldown/use-limit behavior as appropriate.
Clear UI for cards and resources, with ground-cell placement previews.
Tests for core deck/resource behavior.
Milestone 3 — Horde and mission objectives

Wave spawning (from one or more edges/spawn points) and several enemy archetypes.
Path/flow-field decision for hordes, documented.
Base/core health and timer.
Defense mission with explicit victory/failure rules.
Objective UI and clear results.
Stress-test a representative horde in the isometric view.
Milestone 4 — Mission variety

Add data-driven mission definitions.
Implement one assault mission and one escort/rescue-style mission only after the defense loop is stable.
Add required asset health/population thresholds, objective grading, and mission modifiers.
Milestone 5 — Progression and deck editor

Mission reward choice.
Unlockable cards.
Deck editing between missions.
Basic upgrades and persistent local save.
Test save/load and progression edge cases.
Milestone 6 — Combined-arms content expansion

Add artillery variants, armored vehicles, RPG teams, fighter jets, bombers, naval fire support, drones, intelligence, and logistics in carefully scoped increments.
Add synergies and counters.
Expand enemy types and bosses.
Use data-driven definitions and balance documentation.
Milestone 7 — Presentation and usability

Consistent art direction, animations, sound effects, music, UI polish, readable effects, settings, pause, accessibility options, and feedback.
Keep placeholders until their replacement is useful and coherent.
Milestone 8 — Balance, performance, and release readiness

Stress tests and profiling.
Balance card costs, enemy pressure, mission lengths, and progression.
Save robustness, error handling, input testing, resolution/UI testing, build/export verification.
Playtest and iterate before considering an early-access release.
20. INITIAL MVP SCOPE
The first playable version should be deliberately small:

One small isometric (high-view, top-down) battlefield map with a base, chokepoints, and at least one enemy spawn point.
One defense mission.
One base/core with health and a mission timer.
One or two basic zombie types plus a simple stronger enemy if needed.
A small starting deck, around 12–18 available card designs across infantry, armor, artillery, air support, and logistics; do not implement all at once if this is too much for the first slice.
At minimum, prototype one Gatling gun, one tank, one artillery strike, and one helicopter support card.
Basic card draw/play and command resource rules.
Real-time combat with clear firing, projectile/impact, explosion, and death feedback.
Victory/failure and a simple result screen.
A basic reward choice and local save only after the battle loop works.
Automated tests for critical rules.
The MVP should prove four things:

Combat feels satisfying.
Playing cards creates meaningful tactical choices.
Mission completion makes the player want to improve their deck and play again.
The isometric view reads clearly: the player can always tell what is where, what is attacking what, and where a card will land.
Do not expand the content list until these pillars are demonstrated.

21. WORKING AGREEMENTS
Ask me questions when a decision materially affects the game, but do not ask about every small detail. Make a reasonable proposal, record assumptions, and keep moving.
Be candid when an idea is too expensive, risky, unclear, or likely to harm fun/performance.
Prefer working software and verified increments over large speculative code dumps.
Never claim to have inspected, run, tested, or verified something unless you actually did.
If a tool, plugin, Godot binary, test framework, or model capability is unavailable, state that and propose a practical alternative.
Do not silently change the game's genre, core loop, or target platform.
The camera/projection is high-view isometric (2:1) by design. Do not silently change it to pure top-down or side-view. Any change requires an ADR.
Do not overengineer the first version.
Keep documentation aligned with the code.
Preserve existing user work.
When implementing a feature, summarize files changed, behavior implemented, tests run and results, manual checks still needed, and the next recommended step.
Use concise, token-efficient Claude Code prompts that reference existing specs and ask for one bounded task at a time.
22. WHAT TO DO NOW
Start with Milestone 0: Repository and specification foundation.

First inspect the current repository and available environment. Then:

Report what exists and what is missing.
Draft/update the GDD and architecture.
Write AGENTS.md with the required project workflow.
Create the roadmap, initial decision log, testing strategy, asset policy, and a feature spec for the first combat vertical slice.
Record assumptions and unresolved decisions, with recommended defaults. 5B. Include the isometric view decisions (Section 5B) in the GDD, architecture doc, ADR log, and docs/specs/isometric-view.md. Propose the Milestone 0.5 spike plan and its acceptance criteria.
Propose the exact first implementation plan and acceptance criteria.
Stop before implementing the full game. Do not create the entire game in one pass. After the documentation and plan are in place, proceed only with the smallest approved next step.
The goal is to build a sustainable, testable, data-driven Godot game with Claude Code as an AIDD partner—not to generate the largest possible codebase as quickly as possible.