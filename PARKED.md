# This project is parked

*Lands of Lore II: Guardians of Destiny*, rebuilt in Godot 4. This folder is the code as it stood on **18 November 2026** (test build r19p4). Work stopped there. The project is parked and is looking for someone to continue it.

This snapshot is code and notes only. It has no history, no game files and no media. To run the game you need your own copy of the original game, from which you build the pictures, sounds and level data yourself.

## How far each act got

The rebuild follows the original game area by area. Each area below has a saved starting point (`scripts/lol2/playtest_starts.json`), made by playing the game, not by hand.

- **Act 1** (Draracle's cave, the Museum, the Huline Jungle, the Hive, the Monastery, the Dark Halls, to the Darker Jungle): the most finished part. It can be played from the cave to the end of the act. It was played through and tested many times in October and November 2026. The open points as of 13 October are in `docs/act-one-remaining-work.md`. That page was not updated after that date, so check each point against the code.
- **Act 2** (the Savage Jungle, the Dracoid Ruins, the Cemetery, the Claw Mountains, the Citadel of the Ruloi, the Huline Temple): every area can be entered and walked, and the main chain of items, doors and quests is wired through it. Players' tests in November still found faults: falls, walls that let the player through, and refusals that did not say why. Some fixes for these were never merged (see UNFINISHED.md).
- **Act 3** (the City of the Ancients, the Huline Caverns, Belial's Laboratory, the Birthing Chamber): every area can be entered and walked. The road through it was being guided and tested. The final fight's gate was being written when work stopped. It is not in this snapshot (see UNFINISHED.md).

None of this is a finished game. Some movement, combat and interface choices are modern on purpose. Each one is listed in `docs/DEVIATIONS.md`.

## How to build the assets from your own copy

1. Install Godot 4.7.2 (the version every test used) and Python 3.10 or later.
2. Install your own copy of *Lands of Lore II*.
3. The tools in `tools/prepare_*.py` read the original files and write pictures, sounds and data into `assets/lol2/generated/`, which git never tracks. `docs/act1-source-reproduction.md` gives the order and the inputs. The pipeline is not yet fully portable: some tools still expect folders from the original workspace. That page says which.
4. Open `project.godot`. Without the generated assets the project still opens and shows what is missing.

## What is NOT included, and why

- **No original game files and no media.** No pictures, sounds, videos or their Godot import files. They belong to the game's rights holder. You make your own from your copy (above).
- **No original bytes in the data files.** The data files described records of the original files as hex text. In this snapshot each such span is replaced by `omitted N bytes sha256:...`: the span's length and the SHA-256 of its bytes. You can check a span against your own copy, but it cannot be read from here. Part of the game and many tests read these spans while running. Until they are produced again from your own copy, those parts and tests fail. The way to do that is the `tools/prepare_*.py` step above, for the files it produces. A small tool that refills the spans at their recorded file offsets from your own copy is still to be written.
- **No saves or recordings of real players.** Saves and input recordings from playtests are private and were removed, together with their manifests. Tests that need them say so and are skipped or fail.
- **No history.** Older commits hold original media and private test files, so only this one tree is published.
- **Work in progress that never reached the test build.** See UNFINISHED.md.

## Where to start

- AGENTS.md: the rules, how to check work, and the mistakes made.
- UNFINISHED.md: the work in progress when the project was parked.
- `docs/DEVIATIONS.md`: every place where the rebuild differs from the original on purpose.
- `tools/run_regressions.py`: the test runner (`--list` shows the tests; `--suite portable` runs the ones that need no game files).
