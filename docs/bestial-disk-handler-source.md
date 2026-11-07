# Bestial Disk — ITEM080 source preparation

Definition80 `78-Bestial disk`, identity0x7FE7DB79, uses handler30 at0x97BD0. The Dawn gift metadata is already registered by STORY041; its gameplay use is not implemented. No earned Dreamstone or Bestial Disk has been produced by the current campaign chain.

`tools/verify_bestial_disk_handler.py` pins the original LOLG.DAT hash and replays0x97BD0..0x97C85 with explicit external-call boundaries. All255 non-use request bytes refuse. Request1 refuses when byte0x23C46 bit7 is set; all256 guard-byte values are covered. Admitted cases call77ACC(0x23348,0). A non-null result is passed to9B8F0(item,0), then its returned pointer is passed to5F830 with the pool selected by the original half-open address-range check. A null held-item result skips those latter calls but still succeeds. The verifier covers both range boundaries and a null primary pool, across all256 initial status-byte values:1791 handler cases total.

The handler ORs8 into byte0x23ABD, calls8619C(0x2375D,5), and returns1. The external removal calls are supplied returns, not an entered allocator/inventory implementation. The separate8619C argument5 replay covers six list states, including absent/present5. Each calls81820(0x23819,36) and returns1;81820 remains unentered. Calling8619C is therefore not itself proof that the disk casts a spell or changes a form. The object-relative reader is investigated below; the complete native effect remains unresolved.

Run headless on the lane CPUs:

```
LANE_NICE=19 tools/run_lane.sh 24-31 -- python3 tools/verify_bestial_disk_handler.py --game ~/lol2_runtime_root --out tmp/bestial_disk_handler.json
```

Result: PASS1791 handler boundary cases plus six8619C argument5 cases. These are source experiments with explicit machine-state fixtures, not seeded campaign saves, gameplay qualification, or ITEM080 completion.

## Object-relative reader and option3 source branch

The earlier direct-address sweep missed a relative reader. Function7C3D8 tests `[object+0x2A4]`; when supplied object0x23819, that aliases0x23ABD. `verify_curse_item_predicate.py` replays28,672 combinations of status, global0x2271F, choice and special flags. Choice3 returns1 exactly when bit8 is set and global0x2271F is not1. It does not consume the bit. Choices0/1/2 test the sibling bits; choice4 has separate flags. A live caller's object-register producer is not yet entered, so this is an explicit object-binding hypothesis, not a selected-input runtime witness.

The original initialized LE data maps group5 to base25. Option3 selects effect28, whose four bytes are64190001. Original code-object relocation at D24B5 points to table0x77E5C; entry28 relocates to D1F59. Eight branch replays show that with supplied player0x22574, form byte0 and player+0x228 bit4 set, this branch calls7C528(0x23819,3,30),7FE0C(0x23819,1),D6B20(player,1,60). Other supplied form/flag combinations enter the refusal-call branch. These calls remain external boundaries. The raw60 is not yet a proven duration in seconds.

Caller7D786 passes its EBX object and EDI option to the predicate when object+0x400 is5. The admitted continuation contains a further cost check before D0F2C(player0x22574,group,option). The input producer, object binding, cost/lifecycle semantics and actual form change remain unentered. This narrows the missing effect to an option-admission/dispatch chain; it does not make the disk an immediate transformation item or qualify ITEM080 as done.

Reproduce with the same lane wrapper and `python3 tools/verify_curse_item_predicate.py --game ~/lol2_runtime_root --out tmp/curse_item_predicate.json`. PASS28,672 predicate cases plus eight source branch cases; source-only fixtures, no earned-save edits.
