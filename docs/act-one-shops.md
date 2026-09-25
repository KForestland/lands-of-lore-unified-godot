# Missing Huline Jungle shops

The source audit identifies two missing Act1 interactions: Rashar's magic shop
and the weapon-shop exterior/interior. They belong to L4_HJ, before the darker
jungle milestone. Existing cave-to-departure route proofs bypass these locations;
those proofs do not establish complete original Act1 content.

[Source report](act-one-shops-source.json) binds46 room names through the original
LOLG.DAT object5 pointer table atEA6C and its LE relocations. This avoids guessing
room IDs from string order. Scanning both command streams in all15 source areas
finds five direct entrances for room15/MAGIC and43/WPNEXT, all in L4_HJ:

| Room | Source region | Command group | Event |
| --- | --- | --- | --- |
| MAGIC | 2636 | 4858 | region2 |
| WPNEXT | 1722 | 3468 | region2 |
| WPNEXT | 1723 | 3498 | region2 |
| WPNEXT | 1753 | 3528 | region2 |
| WPNEXT | 2127 | 4020 | region2 |

The report retains complete groups, source owners, polygons and floor corners.
MAGIC has repositioning and five opcode9 commands before the room command;
these effects need binding before claiming faithful normal entry. WPNEXT has a
return-position command after room entry. Its hotspot0 conditionally calls
`wpn_` at image633; its admission checks remain to be implemented. Static source
ownership is not a live traversal or admission proof.

Rashar's entry callbackC9F is replayed for all32 combinations of flags52/55/56/57/58.
Flag52 suppresses dialogue. With55 set and56 clear, lines440–441 play. Otherwise
56 set and57 clear returns without dialogue. Otherwise58 suppresses the initial
sequence; with58 clear it sets58 and plays400–414,416–422. It sets53 after404 and
54 after409. Before419, if52 remains clear, it invokes a1000-point mana debit.
This is not damage, payment or an experience reward: DLL initializer binding
maps slot1214 to hostEF44C, which negates1000 and passes it toD6A88 for player22574.
Seven native wrapper cases verify clamping current mana at zero, including
values above1000. Current/max fields145/141 agree with the separately verified
[player initialization](player-progression-initial-checks.json).

After the sequence, slot1230 starts a timer and stores its current counter+600
atDB4B8. Counter cadence and its room-update use remain open; do not replace this
with a guessed reward or duration. Movie callback completion and any intervening
state changes must retain their original ordering.

The broken Thohan offer branch9F5 sets `GV_KNOWLEDGE_OF_POWER_ORB=1` between lines427
and428, after423–427. Three bounded native branch cases verify the held-name check,
ordered movies and global write. This slice is reached only after the earlier
flag52/dead and flag49/fixed-item checks; it is not an exhaustive offer-handler
or item-acquisition proof. The global setter is bound through the reordered DLL
initializer and executable callback table, rather than assuming DLL slot order.
Thirty distinct dialogue VQAs, the29-frame room background and30-frame idle patch
are verified in MAGIC.MIX. They are now decoded into local Godot assets; live
shop interactions remain unimplemented. [Media preparation](magic-shop-media-checks.json)
checks2,009 dialogue frames and3,283,950 PCM samples, plus the background and idle.
The rendered media check exercises all30 patches at start/middle/end and checks
source dimensions, placement and audio lengths. The composed idle screenshot
`tmp/magic_shop_idle.png` was inspected. This is media verification, not normal
shop traversal or quest acceptance.

The archived WPN script also writes the same knowledge global at88F. Its loose
`WOMS/WPN_.WOM` differs from the archived copy, with a corresponding writer at86A.
Runtime override precedence and complete writer admission are still unresolved.
This is a second original producer, not evidence that the global should be
supplied automatically on entry to Julian's office.

[Entry-flag replay](magic-shop-entry-flags-checks.json) resolves the five opcode9
requests to subcommand10, clearing object flags bit0x20000. All256 input byte
values preserve the other bits and adjacent bytes. Requests select kind3 IDs
484/485/428/429 and kind16 selector100; the latter must not be treated as a
literal prop index. Resolved owners and the flag's observable meaning remain
open, alongside repositioning and the room callback timer.

The media check exposed a shared compositor defect: TextureRect's default
minimum size retained a previous larger patch. Setting EXPAND_IGNORE_SIZE lets
each source clip determine its own dimensions, including smaller next clips.
This changes the shared room renderer, not source assets.

Save restoration had a related low-risk cursor issue. `apply_save` previously
asked the general interface to capture the mouse before `MonasteryRooms.restore`
had loaded the saved room; on X11 this produced `NO GRAB` and made the regression
runner classify an otherwise passing test as failed. The interface now leaves
cursor ownership to the monastery restore step whenever that layer exists. The
clean rendered offer regression passes, as do the media, room-media and Jungle
save checks.

Next implementation: bind MAGIC's remaining entry-group effects and callback
timer, integrate the room/visits/items into normal Jungle travel
and persistence, then connect a genuinely earned orb-knowledge return to Julian.
Audit WPNEXT/WPN admission and edition precedence alongside that work. Preserve
the existing earned departure path. Neither shop is marked implemented or
accepted by this audit; required/optional quest classification remains open.

Reproduce:

```sh
PYTHONPATH=/home/bob/lol2_out/native_codec_deps python3 tools/audit_act_one_shops.py
```

The report contains35 room-script replays and seven native mana-wrapper cases.
Host flag/item queries, ambient-timer return and media playback are explicit
boundaries. Media checks verify archive references/header counts, not decoded
playback or rendered appearance. No new gameplay acceptance follows from them.
