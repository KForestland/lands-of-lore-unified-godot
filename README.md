# Lands of Lore — Godot restoration research

Recent update: [Executioner combat component and asset-free test](docs/executioner-combat-core.md).

This repository contains the experimental Lands of Lore 2 cave scenes, geometry
exporters and collision checks. The full recovered static layout has been explored
locally in Godot. Standalone cave walkthrough exports are now prepared locally for Linux and
Windows; see [packaging and validation](docs/standalone-demo.md). This is a
walkthrough proof of concept, not a complete game remake.

Read [restoration status](docs/RESTORATION_STATUS.md) for current results,
controls, validation limits and the local extraction dependencies.

Original game assets are not included. Opening the project without generated
assets shows setup information. With those assets present, run
`tools/lol2/run_full_cave.sh` for the full experimental cave.

Godot validation used version 4.7.2. Python tools require the dependencies noted
in their source and the external evidence artifacts documented in the status file.

Next priorities: portable asset generation, native wall geometry and material
mapping, special openings, interactive objects and original-game behavior.
