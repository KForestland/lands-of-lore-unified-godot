# Colored globe use: replacement and yellow request production

Source-only evidence; ITEM099 is not hosted yet. All checks use the pinned original LOLG.DAT and GLOBAL.MIX. No campaign save is modified.

`tools/verify_globe_replacement.py` resolves static dictionary entry37 (data C610, eight-byte entries) to `96-E Globe`, identity F38DCC87, original definition98. The shared colored handlers read dictionary offset128/+4. The verifier replays the item iterator62694, the constructor6255F search/store suffix and the complete9EB5C definition lookup, including a missing-identity case. The name hash is a transcription of154880; hash sorting and the constructor prefix remain outside the replay. Original records and LE relocations are pinned. This establishes an empty-definition replacement, not a discard or a same-color replacement.

`tools/verify_yellow_globe_handler.py` runs255 refused request bytes and1536 request1 cases through handler93 (9AF08..9AFB5), with explicit external call returns. It reads the empty definition, writes the selected slot, calls77ACC, resolves an aimed target, allocates106 bytes, calls10BB28 and sets status bit80. Target null and type3 select the null-target branch. Allocation failure still returns1. The size106 is not an effect kind. Constructor10BB28 installs class6184.

Three bounded packet-producer cases at10BF40..10BFDD establish that constructor variant0 sends `(kind1, selector1, value80)` followed by `(kind256, selector4, value20)` to the target's vtable80 callback. Nonzero variants send `(1,1,15)`. The source/target/effect pointers and packet bytes1/80 are checked. These values are effect requests, not proven HP damage. The target callback, effect lifetime, null-target secondary effect and visible presentation remain unhosted.

Reproduce from the worktree:

```
python3 tools/verify_globe_replacement.py --game ~/lol2_runtime_root --out tmp/globe_replacement_evidence.json
python3 tools/verify_yellow_globe_handler.py --game ~/lol2_runtime_root --out tmp/yellow_globe_handler_evidence.json
```

No gameplay adapter or DEVIATIONS entry is added by these source proofs. Receptacles and chargers continue to use mechanism_transaction.gd.

Actor-receiver prefix extension: `tools/verify_yellow_receiver_prefix.py --game GAME --out REPORT` verifies the original LE relocation for constructor installationA22DE to table58D0 and its slot80 binding toA6AE0.180 original-code cases take the three produced yellow packets through the ordinary active actor prefix to calculation62728. It passes `(packet, actor+A7, [actor template,NULL])`, copies current actor word88 into packet22/26, writes max(1,template83) into packet1A and leaves requested value16 unchanged. Actor health is unchanged at this boundary. The test supplies the ordinary actor state fields explicitly; it does not witness which live aimed target class was selected, replay special-state branches, execute62728, complete the receiver or prove final HP loss. This narrows the receiver boundary; it does not turn80/20/15 into fixed damage amounts or mark ITEM099 complete.
