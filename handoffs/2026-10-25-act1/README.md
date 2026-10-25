# LoL2 Act 1 handoff — 2026-10-25

This is an implementation handoff, **not a finished Act 1 release**. The public main branch predates the active local
candidate. These patches require the stated local source base; applying them directly to public main is not supported.
No original game media, original executables, personal saves, credentials, or private conversation logs are included.

## Source packages

- `private-runtime-and-chut.patch`: cumulative private work against local source
  `747ad9d294a9caaccf4eb61741bce45c9e74cf08`, ending at
  `3a4c92f48374effadfdb7a7270d2a65f72515324`. Includes player swarm/status scheduling, native-backed Damage Shield components and combat/save
  transport, automatic shield presentation, and the chief-hut death dialogue branch.
- `chut-death-implementation.patch` (`59f94b61ff3a896b59b017ab5e61237c71af4899`) and
  `chut-death-restart.patch`: independently reviewable chief-hut changes. Use these *instead of* applying that portion
  twice through the cumulative patch. Their tested parent includes the private status work; cherry-picking into a
  different candidate requires fresh validation.

## Integration applicability

An isolated-index apply check against r12g `bd9e31c` found context conflicts in
`docs/DEVIATIONS.md` and `tools/run_regressions.py` for the CHUT implementation patch.
Resolve these by retaining the candidate documentation and test list, adding the CHUT death-branch
deviation note and the `jungle_chut_dead_test` / `jungle_chut_dead_restart_test` entries.
Do not replace the candidate files wholesale with the private branch versions. This check did not
modify the running candidate; applying and requalifying the complete slice remains integration work.

## Verified scope

Results below are local receipts, not a new GitHub CI run.

- Original CHUT callback replay: 8 admission combinations, with external host functions stubbed/recorded.
  Kelsrick dead, flag150 clear, and flag153 clear lead to Huline alert, flag153, then original lines375–379.
- CHUT death branch plus existing peaceful visit: 2/2 headless checks passed, complete and source-stable.
- CHUT mid-dialogue/completed saves across a new OS process: 2/2 checks passed, complete and source-stable.
- Shield automatic presentation, early-area clocks and Jungle/Hive transport: 3/3 focused checks passed.
  Native timer/animation/cost evidence and further scoped tests are described by the included source and tests.
- The full earned village escape route passed in Opus's prior rendered run. Restart qualification is **not yet closed**:
  fourth run passed full route/reload but source changed during the run; the focused test failed. Fifth run is testing
  commit `c5a2fd056325e3b4f5034170a0d6e314c6217906` with corrected clock ownership and gate-relink assertions.

## Media and reproduction

Run `tools/prepare_chut_room_media.py --help` and `tools/prepare_damage_shield_frames.py --help` for original-media
preparation. These require a legally obtained original game and the documented companion decoder. Generated media is
not in this handoff. The CHUT generator pins the original archive and clips, and checks decoded frame/audio counts.

After applying to the matching local source and preparing assets, run:

```sh
python3 tools/run_regressions.py --test jungle_chut_dead_test --test jungle_chut_dead_restart_test
python3 tools/run_regressions.py --test jungle_chut_room_test
```

Use a private Godot custom user directory. The first CHUT test writes the two fixture saves consumed by the second;
the regression runner launches each test in a separate process. These are supplied-state tests, not an earned kill/entry
campaign. The project profile and owner launcher changes are deliberately absent from the patches.

## Required continuation

1. Finish the frozen Opus escape run; audit `source_stable`, save identity, broken-gap restart and post-relink MENT restart.
   Never suppress original gate relink behavior to satisfy a stale assertion. The focused test previously doubled
   alarm/gate/Confidante clocks by manual stepping plus their automatic callbacks.
2. Integrate source and generated-media manifests into the next candidate. Qualify the new CHUT branch through an
   earned Kelsrick death/room entry, rendered playback and restart. Its attack branch, stone hotspots and secondary
   effects remain unfinished.
3. Finish production swarm/shield bindings. The native beast boost timer's activation owner remains unresolved;
   no permanently false mapping is established. Default shield casting is not yet enabled. Difficulty, native entry
   gates, swarm display/audio policy and combined rendered expiry/combat still require qualification.
4. Run full affected regressions and earned standard/Dark Halls campaigns through darker-Jungle departure on frozen
   integrated source. Verify original-media manifest, packaged save/restart/build identity, owner-save preservation,
   representative rendering/audio/platform limitations, guide and owner acceptance.
5. Preserve the delivered intermediate r12f and r12e fallback. Grok remains stopped (usage exhausted); do not restart it.
   The owner is working on LoL1; this handoff assigns no LoL1 work.

The chief-hut hostile branch also needs further source work: static decoding distinguishes the Kelsrick-attacked
response (line365, alert and forced exit) from the direct attack response (soul change/flag150 and additional callbacks).
Old notes conflated these; do not implement them as a single unconditional sequence.
