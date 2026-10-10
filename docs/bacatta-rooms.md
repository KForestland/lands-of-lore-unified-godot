# Village and Bacatta first visit

Normal Jungle region3501 now opens the original village room. Its first entry
plays the148-frame TAVERN introduction, with saved progress and flag41 set on
completion. Source hotspot2 at(244,220)–(386,310) enters CAN when flag267 is clear.
The original background, Bacatta's idle, speech patches and audio-only Luther
replies play through the shared room compositor.

[Source audit](bacatta-room-source.json) pins both archives/DLLs, original media
names and geometry ownership. Reproduce with `python3 tools/audit_bacatta_rooms.py`.
`python3 tools/prepare_bacatta_rooms.py` stages two backgrounds,838 speech frames,
148 introduction frames,109 idle frames and six audio-only replies. All speech
and intro audio sample counts are checked; AUD output sizes match their source
headers. Original payloads remain local/ignored. Native room execution has not
been replayed; the source DLL calls drive functional emulation.

CAN setup installs Bacatta and writes `GV_MET_BACATTA=1`, except when local
`Left_Village==3` and flag34 is nonzero. The initial conversation requires clear
flags34/45, sets45 at start, and references lines625–636. Speakers13/1 distinguish
Bacatta movies from Luther AUD replies. Flags32/33 are written after628/632;
flag37 is set after636. The first farewell sets34, clears37, resets
`GV_BACATTA_RELATIONSHIP` and plays Luther637/638 then Bacatta676/677 before
returning to the village. The native temporary host effects and final wait are
not fully bound. Later visits (second visit, the maid betrayal raising the Huline alert) are now hosted: see
[Tavern return](tavern-return.md). Hostile/click branches remain open.

Room transitions preserve the earlier monastery save bank. Intro, audio-only
lines and farewell resume from disk; invalid room/speech combinations are
rejected before mutation. Bacatta now earns the actual prerequisite used by
Dawn. The joint test reaches Julian's flute grant without injecting that flag.
The test supplies two area positions; this alone does not prove the connecting
walk. It also verifies flag267 admission, all staged frame/sample durations,
intro replay prevention and saved return behavior. The room capture
`tmp/bacatta_room.png` has been visually inspected.

Verification: `tmp/regressions/20260924T192744659166Z/report.json` passes the
Bacatta and prior monastery regressions. Later capture run also passes with the
village background restored after its introduction. Admission/presence checks
pass in `tmp/regressions/20260924T193050855384Z/report.json`; Hive/Jungle save
checks pass in report20260924T193022347020Z (its earlier admission parse failure
was corrected and rerun). No full Act1 acceptance is claimed.

The extended `hive_quest_walk_test.gd --continue-monastery` now passes the
continuous rescue→village→Bacatta→Dawn→Julian/flute route. It uses a supplied
initial Hive spawn/sword, then no further position or quest-flag injection.
The new legs cover7 and149 source regions. Conversations complete by runtime
clocks; the existing fixture uses time_scale4/physics240 and does not establish
native audio/timing parity. [Result and file hashes](act-one-flute-walk-checks.json),
`tmp/act1_flute_walk.log`. The actual walk ends with the Iron Flute in inventory.

Reproduce with the project's Godot invocation and
`--script res://tests/hive_quest_walk_test.gd -- --continue-monastery` (allow600s).
The remaining21 Hive/Jungle regressions pass
`tmp/regressions/20260924T193403156866Z/report.json`, excluding the shorter walk
already covered by this extended run. Required quests, combat,
forms, later room branches and departure remain tracked in
[Act1 completion](act-one-completion.md).
