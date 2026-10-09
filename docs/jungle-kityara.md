# Kityara's Jungle follow-up and knife

Learning about Daniel in Kityara's weapon-shop intro (`GV_LUTHER_KNOWS_ABOUT_DANIEL`) used to cut off the exit-guard
arm (region4437, g17748) and the Bacatta link (region1921, g3894). Both need `kityara_gave_knife` (local41), and the
port had no producer for it. The original producer chain is now restored.

## Source chain

All of this is pinned in `scripts/lol2/jungle_kityara_source.json` by `tools/prepare_jungle_kityara.py`.

- **First meeting.** The original WPN room initialization (callback1, `WPN_.WOM` 0x672..0x67F) sets `Met_Kityara`
  (local35)=1 on every path. Entering her shop therefore earns it; `weapon_shop_state.enter_room()` applies it.
- **Presence.** After the runes are translated, p150/p151 regions link her at one of two locations: control0 near
  (808,-1802) or control83 near (-3765,-2551). Unconditional regions unlink her again.
- **Start.** Start regions under p151 (local21==0, local35==1, runes translated, `GV_KITYARA_DEAD`==0) do the
  following. Locations: control0 regions 1257/1315/1324; control83 regions 870/876/892/899/900/914/915.
  - set local21 (Has_Kityara_been_triggered);
  - start the 19 s kind2 timer on prop65/66;
  - hold and reposition Luther;
  - play E066E.VQA segment 1.
- **Knife.** The timer, or the segment-1 end, raises prop65/66 event20. That sets local41=1, sets the prop's owner
  state to 1 and grants identity 3959297008 exactly once. The segment end also sets `GV_LUTHER_HAS_WARBLADE` and
  releases Luther into her idle loop.
  - The item is GLOBAL definition29, source name "30-Empty hand", handler 0 (no inventory use). It is catalogued as
    `jungle:kityara:Empty_hand` for stable persistence, with its original inventory image. The player label is
    "Kityara's blade" and it uses the existing modern melee weapon slot/tuning. No native damage bonus is claimed.
    [Crash's player walkthrough](https://rpggamers.com/walkthrough/lands-of-lore-2-guardians-of-destiny) also describes
    her gift as a sword for Daniel; the raw internal definition name is retained above.
- **Offers.** Kind4 mode3 offers need the exact held identity, and the first eligible record runs:
  - the Power orb, only without Firestorm: Kityara_Given_Orb=1 and the orb is consumed;
  - Amber;
  - Ironwood sap.
- **Hit.** A hit (melee or basic Spark) costs 1 soul, sets `GV_KITYARA_DEAD` and plays the death segment. She then
  leaves and the dropped knife prop64/67 appears. Using it grants the same knife once, even with local21 still 0,
  which is a valid source state.

## Ownership

- `jungle_kityara_state.gd` owns local21 and the control, prop and timer state.
- Locals 23/35/41/54 stay in the existing weapon-shop room bank under their source names, which the shop's own
  admission already reads. After the knife, the shop's original exterior rule closes it.
- Shared globals go through the monastery globals bank.
- The host's exit/Bacatta context now reads local41 from that bank instead of a hard-coded 0.

## Modern adapters

- Region edges are not evaluated while she holds Luther.
- A clip started on an absent control makes it present. The source start groups assume the surrounding presence
  regions were crossed; this avoids an invisible speaker holding Luther.
- While she is present and silent, the plane shows segment 0's first frame.
- One clip callback runs per update.
- The body box and aim reach are modern.
- While she holds Luther, `world_active()` is false, so creatures and other world owners freeze. Her owner keeps its
  clip clock through `movie_world_active()`; pause still stops it. Without this lock a dinosaur took Luther from
  30 to 20 health in 3 s of the 34 s hold.

## Not implemented (reported)

- Control event5 values 0/2/20: the sight setup (props 5567/5631 property10, region1318 op197) and the two
  animation-endpoint death triggers. The hit path covers death.
- Op9 properties 13/17/18 on the controls, player property 4, and the death sound 455.
- The original in-shop kill (WPN callback7) and the post-death shop knife (callback3 arg3, flag253).

## Checks

- `jungle_kityara_state_test` (supplied contexts):
  - presence and admission gates; one-time start;
  - the knife exactly once from the timer, with a silent clip end;
  - mid-conversation save; offers; leave with no relink;
  - hit, then dropped knife once, at both locations, with save round trip and local21 still 0;
  - direct start without a presence region; malformed states.
- `jungle_kityara_live_test` defaults to a portable, explicitly supplied translated-runes/met-Bacatta fixture.
  `--earned-save=PATH` instead loads an actual pre-shop translated-runes continuation; both modes supply approach positions:
  - leaves the saved monastery room; production shop entrance contact, Enter and intro (earned Met_Kityara and
    Daniel knowledge);
  - exit arm refused;
  - presence and start regions, hold, 19 s knife once;
  - mid-conversation disk rollback with no duplicate;
  - exit arm and Bacatta local41 restored; release; completed reload;
  - actual inventory Equip action, completed disk reload, invalid packets and equipped Jungle→Hive→Jungle transport.
- `jungle_kityara_hostile_test` (supplied conversation state): an adjacent dinosaur is harmless during the hold, her
  clock advances and pause freezes it; the knife is granted once; the world and the dinosaur resume afterwards.

The outdoor death and blade globals are shared with the weapon-shop bank. Older packets with only the
monastery copy reconcile on shop restoration. Returning after her outdoor death shows the room without her
actor overlay and disables living dialogue/offers; Back still works. This empty-room presentation is a modern
adapter, not the unimplemented in-shop kill/loot sequence. `jungle_kityara_shop_death_test` covers the source
pre-conversation death/drop state on a real host, room return, no living response, save/load and exit.

The final campaign driver now visits WPN before MAGIC and translation, then requires the follow-up and retained
blade during the repair leg. Run its audit with `--require-kityara` to enforce those earned states through departure.
The separate focused fixture tests do not establish a fresh campaign.
