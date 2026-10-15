# Last Defense (working title)

A 2D, high-view isometric, high-tech military combined-arms **deckbuilder**. Command humanity's forces against mutant zombie hordes in real-time missions: build a deck of units, weapons, orders and support operations, deploy them on an isometric battlefield, complete mission objectives, and grow your arsenal.

**Status:** Milestone 0.5 (isometric spike) complete; Milestone 1 (combat vertical slice) next. No gameplay yet. See [docs/ROADMAP.md](docs/ROADMAP.md).

## Prerequisites
- Godot **4.7.2** (4.x; typed GDScript). Installed via WinGet on the dev machine.

## Run
```
godot --path . scenes/dev/iso_spike.tscn   # isometric spike scene (no main scene yet)
godot --headless --path . --import --quit   # import/parse check
godot --headless --path . --script tests/run_tests.gd   # run tests
```
(Use the full path to the Godot console binary if it is not on PATH — see [AGENTS.md](AGENTS.md).)

## Controls
None yet. Planned: mouse for card play/placement, pan and zoom camera (no rotation).

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
