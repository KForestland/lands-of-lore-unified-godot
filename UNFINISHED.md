# Work in progress when the project was parked (18 November 2026)

None of this is in this snapshot. The work is kept in a private backup of the full repository and can be handed over to whoever continues. One line each: what it was for, and how far it got. "Ready" means it was written and tested on its own, but was not yet merged into the test build r19p4.

## Ready, waiting for the next test build

- **Act 3, final fight gate:** the new attacks at the end are allowed only when the saved chain of the story is complete. The refusal names the three weapons that work. Ready, with a robot walk of the gate prepared.
- **Act 3, road directions:** the road note now reads the key that the pillars really save. Before, it read a key nothing wrote, so the direction never moved on. Ready.
- **Act 3, door pair:** removes a hint that told the player to open a door pair that cannot be opened that way. Ready.
- **Act 1, refusals:** when an action is refused, the screen says what is missing. The review comments were answered. Ready.
- **Act 2, Claw Mountains globe:** the collision check for the globe was corrected, and a player's river test was staged. Ready.
- **Act 1, Dark Halls chest:** spacing restored in one text. Ready (small).
- **Items:** four item-list checks re-pinned after a change to locks. One test now matches the current "Not enough mana" message. Both are test-only.

## Written, not yet run

- **Replaying a player's recorded keys:** a tool that loads a save and replays recorded keys and mouse motion, to repeat a player's fault exactly. Written; never run.
- **Speed:** stops reading the carried items again on every frame where that is not needed, and adds a frame meter to test builds. Written; never measured.
- **One known unstable test:** a note on a magic shop test whose voice check sometimes fails after a quick load. Notes only.

## Older branches (14 to 17 November)

About sixty branches from these days hold fixes for falls, walls, item names, refusals and the Act 2 and 3 areas. Most were merged into r19p4, often in a changed form. They must be compared with r19p4 before use. Two preview branches for the Huline Temple sky and stairs were trials only.

## Uncommitted changes in work folders

55 work folders had changes that were never committed. They are kept as patch files in the private backup.

- **About 35 of them are leftovers from test runs:** check files rewritten by a run, or the project file touched by the editor. Nothing to continue.
- **The rest are real work:**
  - shared rules for world input (one rule for when E and the mouse act);
  - the body fitting narrow passages in Acts 2 and 3;
  - generic objects in the Cemetery and other areas;
  - items given in Acts 2 and 3;
  - readable item names;
  - safe falls;
  - fixed-damage tests;
  - validation of saved positions;
  - a first-run converter for the game files;
  - script fixes for Dark Halls doors and the City's dragon room;
  - test inputs for saved floor cells, with a change to how object rooms are drawn;
  - two notes on Act 3 doors.

  Each one is a draft. Its state is that of the day it stopped.
