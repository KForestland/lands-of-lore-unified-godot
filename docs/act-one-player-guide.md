# Act 1 player guide

The demo starts in Draracle's Caverns and continues through the Museum, Huline Jungle, connected rooms and Hive quests to the darker-jungle departure. The departure preserves a continuation save; the later campaign is not playable yet.

## Starting the game

Keep the executable beside its matching PCK. Launch `Linux/LoL2-Cavern.x86_64` on Linux or `Windows/LoL2-Cavern.exe` on Windows. At the opening screen, browse to `LOLG.EXE` in your original game installation. The game remembers this location and checks the file again at each launch. An unsupported or changed executable leaves the opening screen visible.

Choose the new-game entry or an available area-resume entry. Area resumes appear when their corresponding save exists. To start at a story point instead, press F2 (or click Playtest starts) on the opening screen and pick a title: each is a real save earned by the automated playthrough tests, opened through the normal resume; your own saves are not changed until you save. Use the package's build identifier and verification notes to identify the exact revision you are playing; this guide alone does not certify a build.

## Controls

| Action | Control |
| --- | --- |
| Walk and look | W/A/S/D and mouse |
| Jump | Space |
| Release mouse | Escape; click the game view to resume |
| Interact with nearby objects or people | E; follow the displayed prompt |
| Attack | Left mouse button while looking around, or the HUD weapon button. Without a weapon Luther strikes with his hand. The same attack strikes chains when you aim at them. |
| Open inventory | I, or Inventory in the Character panel. In the grid, double-click to equip or use, right-click to use, drag an item onto an equipment slot to wear it, and click a worn slot to take it off. |
| Character/interface | Tab, or the portrait; Tab returns to the game |
| Local map | M, or the compass; scroll to zoom and drag to move |
| Select starting spell | 1 for Spark, 2 for Healing; the spell book also provides selection |
| Cast selected spell | Q, or the HUD spell button |
| Save/load in the current area | F5/F9, or Save/Load in the Character panel |
| Report a problem | F10, type what went wrong, then Ctrl+Enter or Save report; Escape cancels |
| Copy current location | F8 |
| Playtest starts (opening screen only) | F2; pick a story point, F2 or Esc closes the list |

Use inventory selections and the on-screen hints for equipping, consuming or offering an item. A refused spell says why on the hint line, for example "Already at full health" or "Not enough mana". Room conversations use clickable choices. Follow the death screen's recovery/load prompt; loading restores your saved state and can discard progress made since that save.

## Reporting a problem

Press F10 as soon as you notice a problem. The game captures the view before the form appears and pauses while you type. Describe what you did, what you expected, and what happened. Saving the report resumes the game and copies its folder path, location and your comment to the clipboard. The report contains the build, area, native player position, camera, diagnostics and a screenshot. Reports stay on this computer; they are not automatically sent to a chat. Paste the copied details into the lead chat when you want a report investigated.

The October 17 launcher stores reports in `~/AI_COMMS/playtest_feedback_20261017`. A failed write keeps your note open for retry. Reporting does not create or replace a game save.

## Saves

Saves live outside the executable directory. The October 17 launcher uses its own `userdata` directory; see the accompanying launcher README for the exact save path. It does not overwrite earlier playtest profiles. Historical builds used these default locations:

- Linux: `~/.local/share/godot/app_userdata/LoL2 Cavern Walkthrough/saves/` (or the corresponding directory beneath your `XDG_DATA_HOME`).
- Windows: `%APPDATA%\Godot\app_userdata\LoL2 Cavern Walkthrough\saves\`.

An isolated playtest launcher can override this location. For example, the existing R16 launcher uses `~/lol2_playtests/r16/userdata/godot/app_userdata/LoL2 Cavern Walkthrough/saves/`. Follow the notes beside the launcher you actually use. Source/editor and Flatpak development runs can use different locations.

The area files are `cavern_quicksave.json`, `museum_quicksave.json`, `jungle_quicksave.json`, `hive_quicksave.json` and `darker_jungle_quicksave.json`. Keep backups before moving saves between builds. The startup file selection is stored separately in `original_game.cfg` beside the `saves` directory. Each area's quicksave is replaced by subsequent saves for that area.

## Known limits to include with the next candidate

- Read the delivered build's qualification receipt for its main-route results. This guide alone is not a pass certificate. Owner acceptance remains open.
- Combat tuning and the reported cave-puzzle/inn-trigger problems remain deferred. Passing the campaign does not resolve those unlocalized reports.
- Some LIZ quips/ambient callbacks, later shop offers and optional room outcomes remain incomplete or unverified. Core wax, knowledge and repair interactions are implemented.
- Secondary effects for Museum controls, Long Arm and Reaver remain tracked. Beehive status/hit side effects and Snare use are unresolved; wax harvesting is implemented.
- Museum crystal recharge is implemented, but the current Act 1 route has no ordinary return with a spent crystal. Do not assume every tested fixture is reachable in ordinary play.
- Native Windows execution, clean-machine media preparation and representative GPU/audible-playback acceptance must be recorded for the delivered revision. Historical checks of other builds do not satisfy these gates.

When reporting a problem, include the build identifier, area, action, expected result, actual result and the save used. Preserve that save before further attempts.
