# Museum ivory chips — 2026-10-12

Post-R14 source addition: hit either source urn with an equipped weapon/beast melee or basic Spark, then aim at the revealed chip and press E. Each urn has its own item identity. Picking up one cannot grant, consume or overwrite the other. The shared inventory displays both, and existing area handoffs carry them onward. Neither chip is a new departure prerequisite.

## Original evidence

`tools/prepare_museum_ivory.py` verifies the inventory-pinned L3_DH archive and geometry, binds exact 37-byte item rows17/18 at the geometry item-section offset, and matches prop189/195 placement and event records. It verifies GLOBAL definition107, identity70126601 (`105-Ivory chip`), and exports the original icon and urn sprites from local original media.

| Owner | Source event | Admission | Observable commands |
| --- | --- | --- | --- |
| Prop189, region55, position(57,10,-753) | kind9, group3502 | Wildcard hit masks, threshold1/mode3 | Select owner sprite0; activate item17. |
| Prop195, region149, position(250,0,-1609) | kind9, group3662 | Same filter; predicate14 requires owner state0 | Select sprite0; activate item18; set owner state1. |

Both placements carry initial durability2 at byte30. A bounded replay of the pinned executable's AE2C8 hit scanner passes500 cases: admission requires supplied before>1 and after<=1; prop195 additionally requires a true predicate return. Context values and predicate results are supplied; full native damage calculation is not replayed. The source JSON retains every command, placement, source hash and replay limitation. Source report and all three exported PNGs reproduce byte-for-byte.

The port uses positive melee damage1 and existing Spark damage8. Either crosses the source threshold on the first hit. Exact native damage, non-Spark spell impacts, original sounds, property8/18 flag internals and sprite-state internals are not replicated. Both decoded selector images are identical; the port hides the spent urn to give clear break feedback. Original item coordinates are retained; icon placement, billboarding, aim/reach and the hit-only collision volume use existing port conventions.

## Save and travel contract

Museum `checkpoint.museum_ivory` stores version1 and two stages: intact0, revealed1, collected2. A collected receipt must agree with exactly one matching inventory ID. Malformed, nonfinite, extra-field and contradictory receipts are rejected before a disk load mutates the host. Missing legacy receipts default to intact; legacy saves could not own these newly introduced identities.

A full inventory or occupied hand leaves the revealed item available. Repeated attacks/pickups do not duplicate it. The new world receipt stays in the Museum checkpoint; player inventory moves through the existing catalog and area handoffs. No new parallel player-state owner is introduced.

## Verification and limits

Focused9/9 and an additional archived-R13 compatibility reload check1/1 passed with stable source; both older Museum/Jungle saves reload. All16 integrated paths match reviewed hashes, and the complete tested runtime/test snapshot matches main except the isolated project name.

- `museum_ivory_state_test`: distinct identities, invalid/duplicate/full-capacity actions, strict receipt validation and JSON roundtrip.
- `museum_ivory_live_test`: actual mouse/Q/E input, cursor/busy-hand/capacity rejection, uncollected and completed disk rollback, invalid-save rejection without mutation, two inventory entries, Museum→Jungle→Hive→Jungle→darker handoff and disk saves. Player vantages and sword are supplied; these transfers use the production handoff APIs, not walked exits.
- `museum_ivory_restart_test`: a separate process reloads five hash-linked saves, including the uncollected Museum item and all downstream areas.
- `museum_ivory_walk_test`: collision-walked detour from a supplied main-corridor position to both source rooms, default door/quest state, actual Q/E and a saved result. No intermediate teleport or item/unlock injection. It does not chain the arrival-to-corridor journey. An initial final waypoint clipped an obstacle; the corrected in-room waypoint passes, with failed evidence retained.
- Focused shared HUD, continuity contract, Cave→Museum→Jungle travel/new-process reload and existing Prism checks protect the shared integration.

Local evidence: `AI_COMMS/classic_review_20261007/lead/museum_ivory_review_20261012`. No original-game interactive run, full new campaign/export qualification, later-area chip use, or whole-game completion is claimed. This source addition is not included in immutable R14 binaries.

Local preparation:

```sh
python3 tools/prepare_museum_ivory.py \
  --output scripts/lol2/museum_ivory_source.json \
  --asset-dir assets/lol2/generated/museum_ivory
```

The generated original PNGs and playtest saves stay local.
