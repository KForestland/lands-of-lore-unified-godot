# Original HUD cluster (all areas)

**Reference.** The original manual, `manual.pdf`:
- sha256 `3c3cac3f02fb22771948c7cd9c997f2a2c2588d5535adaa0a4f8e0dfd5eb8f52`;
- lead evidence: `classic_review_20261007/lead/manual_hud_review`;
- Grok's role summary: `grok/original_hud_20261010/REPORT.md`.

The printed page number is the PDF page + 1.

**Art.** `tools/prepare_classic_hud.py` stages the cluster pieces from `GLOBAL.MIX` `intrface.shp` (sha256 1c03f2a0…,
144 shapes) with `basepal.pal` into `assets/lol2/generated/classic_hud/`. These are local original media and are never
published. It writes the geometry, measured from the decoded art, to `scripts/lol2/classic_hud_source.json`.

## What the manual establishes

- **Placement.** One cluster at the **bottom right** of the play view (printed 7, 10, 39). There is no button bar.
- **Cluster.** Luther's portrait in the oval, with the compass N at its top.
  - The upper ring is the **Attack Button**. It shows the equipped weapon, which changes on equip, and a hand when
    unarmed (printed 7, 39).
  - The lower ring is the **Magic Button**. It shows the loaded spell (printed 10).
  - Right-clicking the Magic Button cycles the spell groups (printed 39).
- **Spell Book.** The **Blue Button** next to the Magic Button slides out the **Spell Bar** of spell-group icons along
  the bottom, left of the cluster (printed 10, 39). Choosing an icon loads that group.
- **Health and magic** have two slots under the cluster (printed 39 screenshot).

## Geometry from the art itself (never from manual crops)

The enclosed transparent holes of shape 2 (85×73) are:

| Element | Hole (x, y) | Size | Matches |
| --- | --- | --- | --- |
| Portrait | (41, 7) | 38×52 | the portrait's exact size |
| Attack ring | (7, 9) | 21×21 | the 21×21 icon shapes |
| Magic ring | (7, 42) | 21×21 | the 21×21 icon shapes |
| Mana slot | (5, 66) | 25×4 | the blue 25×4 shape 59 |
| Health slot | (41, 66) | 39×4 | the red 39×4 shape 57 |

Shape 1 (349 opaque pixels) fills a ring hole exactly, so it is the ring disc. Shape 62 (159×30) has six 21×21 holes at
x = 15 + 24k. Everything is drawn at 2× nearest, anchored bottom-right with a 12-pixel margin.

## Port

`museum_interface.gd` is the one shell for the Museum, Jungle and Hive (`hive_interface.gd` is a thin subclass) and
for the Cave (`cave_interface.gd`, normal play only; the developer text HUD stays in developer mode).

- **Cluster.** Shape 2 with the portrait and blink.
- **Attack ring (`weapon_button`, `buttons[2]`).**
  - The equipped item's icon, or hand shape 6 when unarmed.
  - Click **attacks**, as in the manual. The port has no single attack API; each host's hit owners take an ordinary
    left click while the mouse is captured. So the click returns to play and delivers exactly one left press/release
    through the engine input pipeline (`attack_from_interface`). The existing handlers resolve the hit; combat is
    unchanged. It is refused while paused.
  - **Adapter:** the original keeps the cursor; the port returns to mouse-look.
  - Inventory/equipment is reached through the Character page's "Open inventory" button or the I key.
- **Magic ring.**
  - The loaded spell icon: Spark = shape 65, Heal = shape 63.
  - Left click casts through `starting_magic.cast_from_interface()`. That path waives only the mouse-captured and
    interface-cursor gates (the click happens in cursor mode). Pause, death, flying, modals (inventory, video, rooms,
    dialogues), conversations and locks still refuse, and the normal mana cost and cooldown apply.
  - Right click cycles Spark/Heal.
- **Blue Button** (shapes 25/26) toggles the **Spell Bar** (shape 62) with the Act 1 groups Heal and Spark. Clicking
  an icon loads that group.
- **Health and mana fills** (shapes 57/59) are sized from `starting_magic` health/30 and mana/maximum.
- **Compass** opens the atlas (`buttons[1]`; adapter). The **portrait** opens the Character page (`buttons[0]`).
- **Kept, modern:** the Character/Atlas sheet, the prompt line (bottom centre), Tab cursor mode, I, M, F5/F9.
- **Cave.**
  - Its prompts (fallen → loot → curse) go on the prompt line, and its status on the Character page.
  - The map is drawn from the `L1_DC` creature-navigation regions offset by `native_translation`.
  - Its notices use the prompt line.
  - It gains public `quicksave`, `quickload`, `open_inventory` and `save_feedback`.

## Adapters / not established

- **Role matches by size and look, not byte-proven:** the ring icons, the bar fills and the Blue Button.
- **Placement:** the Spell Bar and Blue Button positions are placed beside the cluster; their offsets were not
  measured.
- **Equipped weapon icon:** the existing item icon fitted into the ring.
- **Original keys (manual printed 8–10, 45–47) are not remapped:**

  | Action | Original | Port |
  | --- | --- | --- |
  | Attack | F | left click in the world |
  | Cast | S | Q |
  | Load Heal / Spark | F1 / F2 | 1 / 2 |
  | Automapper | Tab | M |
  | Options (save/load/resume) | Esc | F5/F9 |
  | Look up / down / centre | Q / Z / A | mouse look |

  The port's Tab is its cursor/interface mode.
- **Not hosted:** later spell groups, the skill-level shield/book flash, the Options/targeting cursor, portrait
  drop-to-use/equip, the Status bar (O).
- **One normal-play HUD (r3).** With the classic shell present and developer mode off:
  - the modern `starting_magic` panel (top right: spell, mana, Q/Shift+Q, Spark/Healing buttons) is hidden;
  - cast notices, the Lightning-aura timer and item status appear on the shared hint line, and the Character page
    lists health, mana, the loaded spell and its keys, the aura and item status;
  - a successful Magic Button cast in cursor mode shows its notice on the hint for 1.5 s, unless a save or area
    notice is already showing (that keeps priority);
  - the Hive Character page (its own override) also lists the aura and item status;
  - the Hive warriors' top-left label drops its permanent "Health · Left click: strike" text and keeps only target
    information and the Defeated prompt, like the other areas' population labels. It sits at y = 48 (the other areas'
    label height), below the top-centre coordinate overlay.

  Developer mode (F3 / `--developer-tools`) restores the modern panel.
- **Hint line.** It runs from the left edge to the cluster's left edge (or to the open Spell Bar's left edge), wrapping
  upwards, so it never overlaps the cluster or the Spell Bar and a long notice never runs off the bottom at 960×540 or
  1280×720. The lead's coordinate overlay (top centre) is unaffected.
- **One Character page (r4).** Every area uses the same page (the Hive override was removed):
  - `Health: h / 30 · Mana: m / M`;
  - `Form: … · Spell: … (Q to cast)`;
  - `Weapon: … · Armor: …` (`· Offhand: …` when one is equipped);
  - `Fighting: level n (x XP) · Magic: level n (x XP)`, read through `starting_magic.fighting_state()` /
    `magic_state()` from the owner each host already uses (Museum fighting packet, Hive checkpoint, Cave/Jungle
    quests);
  - the aura/item status lines, then area extras (the Cave's sample/Aloe counts; its duplicate form line is dropped).

  The body wraps to the sheet width; Inventory, Save and Load share one row; the sheet grows both ways from the centre
  and the atlas height follows the window, so both pages stay inside 960×540 clear of the cluster, hint and
  coordinates. The open page refreshes every frame (casts, rewards and loads show at once).
- **r4 fixes found by the four-area click test:**
  - the Blue Button art was invisible in normal play: it was a `Button.icon`, which Godot dims while the button is
    disabled (all of normal play). It is now drawn as a child texture like the rings;
  - the open Spell Bar (y 468–528 at 960×540) covered the hint line;
  - the Character page measured 547×478 and the Atlas page 480×461 at 960×540, covering the hint line;
  - the Cave never refreshed the Attack ring after equip/load/form change. The shell now refreshes when the equipped
    weapon/armor or form changes, in every host;
  - the Cave inventory lacked `return_to_game`, so Tab inside it left cursor mode on, unlike the other areas.
  - a Cave load left cursor mode on; like the other areas it now returns to play.

## Tests

**`tests/classic_hud_live_test.gd`** (rendered, run with `--demo-interface`) covers:

- **Cave:**
  - one shell, the developer label hidden;
  - the cluster bottom-right, with no modern bar;
  - the health fill;
  - Heal/Spark loading, right-click cycle, Spell Bar toggle and pick;
  - Tab, M atlas (polygons, player on the map), Esc, I, F5/F9 notices;
  - the fallen prompt; the Character page.
- **Cave→Museum:** the real transfer leaves one shell.
- **Museum, Jungle, Hive:** the same per-area checks.

**`tests/classic_hud_actions_test.gd`** (rendered, real viewport clicks on the private display) covers:

- **Magic Button:** Heal gives health +6 and mana −2; the cooldown, pause, death, the inventory modal and a disabled
  button (outside cursor mode) all refuse with no change.
- **Attack Button:** it lands a normal hit on a Hive return warrior through `hive_warriors.strike`; paused is refused.

**`tests/classic_hud_layout_test.gd`** (rendered) checks Cave, Museum, Jungle and Hive at 960×540 and 1280×720:

- the modern panel is hidden;
- the cluster, hint and coordinate overlay are on screen and don't overlap;
- the Hive label carries no modern health text;
- the Healing notice appears on the hint;
- developer view restores the panel;
- a Hive targeted-warrior label clears the coordinates and the cluster at both sizes;
- the aura status appears on the Hive Character page;
- screenshots are saved, including Hive with an enemy targeted.

**`tests/classic_hud_acceptance_test.gd`** (rendered, r4) runs Cave, Museum, Jungle and Hive at 960×540 and 1280×720
with real viewport clicks/keys: one shell and the Blue Button drawn; Tab; Blue Button → Spell Bar → Spark/Heal (ring
icon follows); Magic Button Heal (+6/−2, fills follow); portrait → Character page content (health, mana, form, spell,
weapon/armor, fighting/magic level and XP) on screen without overlap; compass → Atlas page on screen without overlap;
Save button writes the area's existing format, Load button restores (no semantic difference via
`player_continuity.gd`); Inventory is modal (cast and page refused), Escape closes it; an equipped weapon shows on the
Attack ring and Beast form hides it and refuses the cast; Attack click returns to play with one ordinary click.
Supplied: Museum introduction skipped, Hive rescue-return fixture, health/mana values, a carried Stalagmite, Beast form
assigned directly. Screenshots: `user://tests/hud_acceptance/`.

**Updated for the new layout:** `hive_interface_test` (registered) and `jungle_interface_test` (unregistered). The
portrait button now has one child, and the click goes to its centre. Inventory is now opened through the shell path
rather than the Attack Button, here and in the unregistered `museum_equipment_test` (the Character page's Inventory
button, `inventory_button`).

**History.** Revision r2 fixes the r1 (5ae9c4b) blocker found in lead review: the r1 Magic left click could never cast,
because `world_active` refused the visible cursor, and the r1 Attack ring opened the inventory.
