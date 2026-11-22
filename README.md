# Lands of Lore 2 — Godot restoration

> **This project is parked.** The code stands as it was on 18 November 2026 (test build r19p4) and work has stopped. Read [PARKED.md](PARKED.md) first: how far each act got, how to build the assets from your own copy of the game, and what is not included. [UNFINISHED.md](UNFINISHED.md) lists the work that was in progress, and [AGENTS.md](AGENTS.md) is for whoever continues. No game files, media or original bytes are in this repository. The text below is the working page as it stood and has not been updated.

The current milestone is a playable Act 1 demo from Draracle’s cave through Museum, Jungle/Hive quests and departure to the darker jungle. The larger goal remains the complete game. Modern mechanics are permitted where they improve playability or delivery; story, quests and reliable saves remain central.

This checkout now contains the integrated R3 runtime, scenes, Godot tests and numeric fixtures, plus the reviewed three-spell Dawn combat update. The R3 binaries predate that update. R3 is a technical QA candidate, not an accepted demo. See [current progress and content gaps](docs/playtest-notes-20261007.md), [package checks](docs/act1-r3-package-checks.json) and [source/build instructions](docs/act1-source-reproduction.md).

Original game assets and executables are not included. Opening `project.godot` without generated assets shows setup information. Godot4.7.2 was used for verification. Building the game currently requires locally prepared original media and matching export templates; the clean-machine asset pipeline is still being made portable.

Both R3 platform exports completed. Linux passed ordinary movement, quicksave/load, restart and Jungle-resume checks. Native Windows runtime, representative GPU/audio checks, the owner’s playtest acceptance and R4 campaign/package checks remain open. The newer three-spell source passed all256 registered regressions with no source drift. Earlier patch files are preserved review history; their integrated runtime changes are already in this tree.
