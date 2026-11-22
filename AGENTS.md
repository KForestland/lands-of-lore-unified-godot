# Notes for whoever continues this work

This page is for a person or a program that takes over this project without the people who built it. It says what the project is, the rules it kept, how to check your work, and the mistakes that were made. It works with any editor, assistant or harness: everything here is plain files, git, Python and Godot.

## What this is

A rebuild of *Lands of Lore II: Guardians of Destiny* (Westwood, 1997) in Godot 4, made from a study of the original program and its data files. It is parked: see PARKED.md for the state and UNFINISHED.md for the work in progress. The project holds no game files. The tools read a person's own copy.

## The rules

1. **No game content in the project.** No game files and no pictures, sounds, videos or text taken from the game. Generated assets go to `assets/lol2/generated/`, which git ignores. Data files keep no copies of original bytes; a span appears as `omitted N bytes sha256:...`. `tools/check_publishable.py` refuses media, machine paths, players' saves and words on a private local list. Run it before anything leaves your machine.
2. **Follow the original, and record every difference.** Where the rebuild differs on purpose (modern controls, a hint, a safer fall), the difference gets a row in `docs/DEVIATIONS.md`. Without a row, it is a fault.
3. **Earned, not placed.** A test that claims a route works starts from a save written by playing the game (`scripts/lol2/playtest_starts.json`), not from a position or flag set by hand. If a test uses an aid, it says so.
4. **Players' saves stay private.** Saves and input recordings from playtests never enter the project. Tests that need one read it from an ignored `tmp/` folder and say so.
5. **Nobody approves their own work.** A change is reviewed by someone who did not write it, from a clean export of the exact commit (`git archive`), not from the writer's folder.
6. **Ask the owner** before any release, tag or announcement.

## How to check your work

Requirements: Godot 4.7.2, Python 3.10 or later, and your own copy of the game for anything beyond the portable tests.

```sh
python3 tools/run_regressions.py --suite portable --godot godot      # needs no game files
python3 tools/run_regressions.py --suite core --list                  # every registered test
python3 tools/run_regressions.py --suite core --godot godot           # needs generated assets
python3 tools/check_publishable.py . --owner-list <your private list>  # before anything leaves your machine
```

Each test has a registry file in `tests/registry/` with its suite, its mode (headless or rendered) and what it needs. A test with no registry file is not run. Run the suite on the exact commit you hand over.

## Ten mistakes we made, and how they were caught

1. **"Done" said by the one who wrote it.** A second reader found gaps more than once. A change is done when someone else has walked it.
2. **Tests that started from a hand-made save.** One edited save put the player in a state the game cannot reach, and a correct fix looked broken. Use saves the game wrote.
3. **Polishing before the route worked.** Lighting and sprites were tuned while the game could not yet be walked end to end. Make the route work first.
4. **The same fact in several places.** Counts and states typed by hand on pages drifted from the code. Let tools write counts.
5. **Fixes that moved a fault instead of removing it.** A fault in one room came back in another. Look for the whole class of the fault (every wall, every door), not just the one place.
6. **Long test runs on a stale tree.** A full run of several hours on an earlier commit proved nothing about the next one. Run on the exact head.
7. **Too many test copies of the engine at once** ran the machine out of memory. Limit parallel Godot runs.
8. **Screens that told the player to do something unsafe or impossible** (a hint that led into a blast, a key that did not exist). Check every hint by doing exactly what it says.
9. **Hygiene leaks:** machine paths, a private name and players' saves in tracked files. Caught by review and now by `tools/check_publishable.py`.
10. **Original bytes kept as hex text in data files.** That made the files easy to check, but it carried the game's content. Keep offsets and hashes, and read the bytes from the user's own copy.

Two habits caught most of these: an independent reader who did not write the work, and a walk of the real game by a person before anything was called finished.
