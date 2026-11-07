# Item definitions (items chunk 1, 2026-10-25)

All 170 original item definitions (GLOBAL.MIX entry 3984507021) are staged by `tools/prepare_item_definitions.py --game ROOT`
into `assets/lol2/generated/items/` (generated, original media, never committed): `definitions.json` and `icons/NNN.png`
(165 decodable; rows 152-156 are ghost/projectile placeholders with no picture). `--docs` refreshes
`docs/item-definitions-source.json` (fields only).

Runtime: `scripts/lol2/item_definitions.gd` (read-only data) and `scripts/lol2/item_catalog.gd`:
- `definition(id)` / `definition_name(id)`: every Act 1 carried identity resolves to its original definition (196 of 197;
  the unidentified cavern sample has none).
- `item:defNNN`: generic carried ids for every carriable definition, admitted only in scope "world" (later acts).
  Label = original name, icon = original icon, slot from the class byte, defense from +0x41.
- `use_hint(id)`: refusal text for items without a traced use.

Proven from bytes: names, identities, handler index and code address, mask word, defense, descriptors, selector counts,
icons. Adapter: class-byte slot (DEVIATIONS). Not decoded: the other varying record bytes (kept raw as `undecoded`),
price, weight, damage, description text. Behaviours (handlers) come later, grouped by kind; until then items refuse.
Census and plan: `AI_COMMS/act1_completion_20261017/ITEM_CENSUS_AND_PLAN_20261025.md`.
Test: `tests/item_definitions_test.gd` (headless).

## Inventory icons (2026-10-28)

`icons/NNN.png` above are GROUND sprites (LOCAL flags 0x28E: the item lying in the world). The inventory uses separate
24x24 icons (flags 0x48E, relative-mode LCW + zero-run RLE), staged by `tools/prepare_item_inventory_icons.py --game ROOT`
into `assets/lol2/generated/items/inventory_icons/NNN.png` + `inventory_icons.json` (165 carriable definitions; ghost
rows 152-156 none; deterministic). Link: the LOCAL descriptor tag shared with the ground sprite (164), the Stalagmite's
adjacent resource 23 (likely). Runtime: `item_definitions.inventory_icon(index)`, `item_catalog.inventory_icon(id)`
(falls back to the ground sprite only for the cavern sample, which has no definition), `player_equipment.inventory_icon`
(HUD weapon ring). `item_catalog.icon(id)` stays the ground sprite for world billboards. Test:
`tests/item_inventory_icons_test.gd` (headless). Deviations: DEVIATIONS 2026-10-28.

Native slot-mask follow-up (2026-10-28): `8FD40` tests definition `+0x3F & (1 << slot)` while considering original slots 0 through 5. Cocos Cap definition 167 (`0x43`) selects slot 0, or slot 1 when 0 is occupied, subject to handler category uniqueness. Original-code entry replay confirms this through the slot store. The modern slot mapping remains an adapter; original slots 0/1 and event-10/11 accessory effects are still unimplemented. Evidence: `AI_COMMS/act1_completion_20261017/COCOS_CAP_IMPLEMENTATION_CONTRACT_20261028.json`.
