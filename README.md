# Last Defense (working title)

A 2D, high-view isometric, high-tech military combined-arms **deckbuilder**. Command humanity's forces against mutant zombie hordes in real-time missions: build a deck of units, weapons, orders and support operations, deploy them on an isometric battlefield, complete mission objectives, and grow your arsenal.

**Status:** Milestone 1 (combat vertical slice) is built — a playable defend-the-core battle with feedback effects, generated placeholder sounds, a result screen and a 100-zombie stress scenario — and awaits the owner's go / tune / no-go. Cards/deck are not implemented yet (Milestone 2). See [docs/ROADMAP.md](docs/ROADMAP.md).

## Prerequisites
- Godot **4.7.2** (4.x; typed GDScript). Installed via WinGet on the dev machine.

## Run
```
godot --path .            # runs the battle (main scene)
godot --path . -- --mission=s1_stress_horde --seed=3   # 100-zombie stress scenario (FPS shown top-right)
godot --path . -- --mission=m2_card_defense   # card mission: keys 1-5 play the hand slot on the cell under the mouse (interim input until 2.3)
godot --path . scenes/dev/iso_spike.tscn   # isometric spike scene
godot --headless --path . --import --quit   # import/parse check
godot --headless --path . --script tests/run_tests.gd   # run tests
```
(Use the full path to the Godot console binary if it is not on PATH — see [AGENTS.md](AGENTS.md).)

## Controls
Battle: **LMB** move the soldier (click a walkable cell), **R** restart, **WASD/arrows** or **middle-mouse drag** pan, **wheel** zoom (toward cursor). The MG nest and core are fixed; combat is automatic. Cards come in Milestone 2.

## Documentation
| Doc | Purpose |
|---|---|
| [MasterPrompt.md](MasterPrompt.md) | Original project brief |
| [AGENTS.md](AGENTS.md) | Rules for Claude Code |
| [docs/GDD.md](docs/GDD.md) | Design document |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Systems and data flow |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Milestones and next tasks |
| [docs/DECISIONS.md](docs/DECISIONS.md) | ADR log |
| [docs/specs/](docs/specs/) | Per-feature specs |
| [docs/TESTING.md](docs/TESTING.md) | Test strategy and commands |
| [docs/ASSETS.md](docs/ASSETS.md) | Asset conventions and provenance |
| [docs/BALANCE.md](docs/BALANCE.md) | Tunable values |
| [CHANGELOG.md](CHANGELOG.md) | Changes by milestone |
