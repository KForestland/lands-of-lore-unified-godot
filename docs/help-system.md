# In-game help (banner + help page)

Owner reports 2026-10-17 10:57:04 and 2026-10-20 11:11:50 ("the 2D point and click is not activating"). The
original shows a top-left banner, "Press [icon] for help on targeting." / "Press [icon] for miscellaneous help."
(longplay 8:15 and 10:30–10:35), while play continues. The icon opens a 2D help page.

## Native rule (LOLG.DAT)

- **Gate:** each op2 player sub needs player+0x22A bit0 (help enabled). It test-and-sets one bit at player+0x20C
  (topic t, bit `1 << (t-1)`), then calls `73FF0(t)`.
- **73FF0(t):**
  - stores the topic (`[0x96794]`);
  - loads `helptext.trr` and `help.pcx` (`70BF8(2)`);
  - runs the help UI `15BB18`. Its layout is not decoded.

| Sub | Handler | Topic | Banner (`helptext.trr`) | Page id |
|---|---|---|---|---|
| 0x29 | D86B6 | 1 | Press for help on using your inventory. | 0 ^Inventory |
| 0x2A | D828A | 2 | … using the automapper. | 1 ^Automapper |
| 0x2B | D82CD | 3 | … casting magic. | 2 ^Using Magic |
| 0x2C | D8310 | 4 | … combat. | 3 ^Weapon Combat |
| 0x2D | D8659 | 5 | … movement. | 4 ^Movement |
| 0x2E | D8352 | 6 | Press for miscellaneous help. | 5 ^Miscellaneous |
| 0x32 | D8607 | 7 | … looking around. | 8 ^Looking Around |
| 0x33 | D8395 | 8 | … targeting. | 9 ^Targeting |

- Subs 0x2F, 0x30 and 0x31 are other operations, not help.
- **`helptext.trr` format** (LOCALLNG.MIX entry 3, key = `ww_hash_v1("HELPTEXT.TRR")`):
  - u32 count n, n u32 ids, n+1 u32 offsets;
  - string i is the NUL-terminated text at offset[i] + 4.
  - Ids 7 + 6 read "Press " + key + " to leave or enter the help system."
  - Ids 0x13–0x27 are per-area Draracle hint pages (not hosted).

## L1_DC triggers (`scripts/lol2/cave_help_source.json`, pinned byte for byte)

| Topic | Native record(s) | Port |
|---|---|---|
| 1 inventory | crystal clusters props 144–149, 641 (kind4 use); Stone control75 (kind4); captain56 kind3; 21 actor groups with no direct owner (loot) | hooked: the count of those carried items rises (`cave_help.trigger_items`) |
| 2 automapper | prop927 kind5 (first sighting), predicate42 | hooked: frustum + clear ray within 1600 |
| 3 magic | actor56 (captain) kind5 | hooked: captain present and alive, sighted |
| 4 combat | prop422 kind2 timer; started by its kind6 value265, whose producer is untraced; stopped by region1231 | **not hosted** |
| 5 movement | none in L1_DC / L3_DH / L4_HJ / L5_HC | none |
| 6 miscellaneous | prop1219 kind5, predicate44 | hooked: sighting |
| 7 looking around | region1077 kind4 value0 (grounded entry) | hooked: polygon + floor |
| 8 targeting | prop1363 kind5 | hooked: sighting |

## Port

- **`scripts/lol2/help_system.gd`** (shared HUD, `museum_interface.gd` → `help`):
  - `request(topic)` applies the native gate.
  - **Banner:** top-left, "Press [icon] …", shown for 8 s.
  - **Opening the page:** F1, or clicking the icon in cursor mode (Tab), opens it. The world pauses and the mouse is
    freed.
  - **Closing:** F1 or Esc closes the page; T switches help messages off and on.
  - **Page text:** the page shows the original text with `@` replaced by this version's keys, plus one line listing
    this version's controls.
- **`scripts/lol2/cave_help.gd`** polls the triggers above once per physics frame while the world is active. After a
  load it takes a new baseline, so restored items never count as pickups.
- **Saving:** the Cave save carries `help` = {version 1, enabled, seen}. Legacy saves start with help on and nothing
  seen.

## Adapters (docs/DEVIATIONS.md)

- **Missing art:**
  - `help.pcx` is referenced by the executable, but no MIX entry or loose file exists in the GOG data.
  - The longplay's red-eye icon is not in any shipped shape or WSA.
  - The page therefore uses the original `PRCHUNRL.PCX` (unrolled parchment scroll, blue key colour transparent),
    and the icon uses `intrface.shp` shape 119.
  - The text is placed in the scroll centre.
- **Help toggle:** "help enabled" is switched on the page (T) rather than in an options menu.
- **Seen bits:** they live in the Cave save, since only Cave records raise help in Act 1. Other areas start fresh.
- **Sighting:** uses the same frustum/ray adapter as the Jungle kind5 producers.

Producer: `python3 tools/prepare_help_system.py --game GAME` writes `assets/lol2/generated/help_system/`
(`texts.json`, `page.png`, `icon.png`) and `scripts/lol2/cave_help_source.json`. Test: `tests/help_system_test.gd`
(headless, `-- --demo-interface`).
