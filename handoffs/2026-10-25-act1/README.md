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

`chut-r12g-compatible.patch` combines both CHUT commits against r12g `bd9e31c`, adapting only
the documentation row and headless test registration. Its isolated-index apply check passes.
Use it instead of the two separate CHUT patches on this base. Runtime tests on the integrated
candidate remain required; this is source applicability evidence only.

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
- Frozen fixA fifth rendered run completed: focused earned escape, continuous ordinary-input route and
  separate-process reload all passed (3/3), with `source_stable: true`. The route saves the broken gap,
  then crosses original region3896 to relink the leaves before the final MENT save.
  This qualifies the fixA escape scope only; the integrated r12h candidate still requires validation.

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

## Hostile chief-hut branch: continuation evidence

This branch is not implemented in the candidate. Do not conflate the Kelsrick-attacked response
(line365, alert, placement/facing and forced exit) with direct attack (soul change, flag150,
actor changes, stone hotspots and sound request). The original module and executable hashes are
pinned by the existing source verifier and local replay receipts.

- Original handler replay: 48 combinations of flags150/153, internal latches d74/d78 and soul0/1/10 pass.
  d74 takes priority; direct attack additionally requires d78. Soul0 passes raw -1 to the host;
  host clamping is not established by this replay.
- Setup-slice replay: 4 cases pass. Module data initializes d74=0, d78=1; setup clears d78 when
  flag153 is set and flag150 is clear. Whole-module lifetime across re-entry remains unverified.
- Callback9 replay: 16 combinations pass. With flag152 preset to suppress peaceful first visit,
  alive Kelsrick plus `Kelsrick_Attacked` and clear flags150/153 sets d74 internally and invokes
  the attacked response. Dead Kelsrick instead selects the death branch. External callbacks are stubbed.
- Original LE fixups resolve host-table offsets against table0xE92C:

| Offset | Native target | Verified effect and remaining limit |
| --- | --- | --- |
| 0x118 | 0xF1550 | Calls0x83158 with object0x23819 and0xFF; changes object byte+0x412 and invokes rendering/resource functions. Full presentation semantics unresolved. |
| 0x114 | 0xF1564 | Calls0x8309C on the same object; conditional byte+0x412 reset and rendering/resource calls. Do not assume an unconditional input unlock. |
| 0x30 | 0xEF20C | Four valid-speaker-slot replays pass: selected24-byte slot fields+0x10/+0x14 become0/-1; other fields and other slot unchanged. Field consumers and absent-speaker behavior unresolved. |
| 0xEC | 0xED364 | Sets0xDB4C8=1. Four movie-guard replays verify diversion to cleanup at0xEED3D. Setup statically clears the flag at0xED5AF. Full room lifetime unresolved. |

Local reproducible scripts and receipts are in `AI_COMMS/codex_act1_review_20261025`:
`verify_chut_attack_dispatch.py`, `verify_chut_attack_latch_setup.py`,
`verify_chut_callback9_attack.py`, `verify_chut_host_movie_guard.py`, and
`verify_chut_host_actor_slot.py`. These require the original game and retained local decoder dependencies;
they are not GitHub CI results. Native original media/executable bytes are not published here.

Next: resolve the two presentation helpers, actor-slot consumers, native direct-attack event and
re-entry lifetime; implement and test the complete hostile interaction in a separate candidate.
For the existing death branch, an earned ordinary-input kill -> inner gate -> region2750 -> CHUT
route is still required: supplied-state tests do not prove it. The entry group5084 tests local6==0;
record prior-visit history rather than bypassing that predicate.

`chut-hostile-annotation.patch` (private commit8b1e1d6) corrects the generator and source JSON
annotations that incorrectly combined hostile branches and named line1000. It applies cleanly
to r12h902b273 in an isolated-index check. This changes metadata only; apply after the frozen
qualification run. It is additional to the runtime CHUT patches above. Python/JSON parsing
and generator/metadata text agreement were checked; no runtime behavior changed.

## Subsequent private branch: attacked-Kelsrick arrival

`chut-attacked-r12h.patch` is an additional implementation slice against r12h
`902b273ec5494199564a99d016471721b37eb309`, from private commit
`702e2d6d43a70090164e47c91a608ee95730a555`. Apply only after the frozen qualification run.
It includes the annotation correction, so do not also apply `chut-hostile-annotation.patch`.
The isolated-index application check passes; candidate documentation and test-list contents are retained.

This implements the alive-Kelsrick/attacked-local52 arrival branch: write local33 through its
existing owner, raise alert, play original line365, place at(-1749,-5457), face native286 degrees
using the established facing adapter, and exit. Native flag150/153 are not invented.
Four headless checks passed on unchanged private source: admission/playback/save, fresh-process
restart, existing death branch, and peaceful visit. These are supplied-state checks.

Reprepare CHUT media using the updated generator. The original line365 has103 frames and162434
audio samples. The complete local135-file SHA manifest is in
`AI_COMMS/codex_act1_review_20261025/chut_attacked_implementation_review.json`; no original media
is published here. New tests: `jungle_chut_attacked_test` followed by
`jungle_chut_attacked_restart_test`, each launched separately by the regression runner.

Direct room attack, stone hotspots, secondary/ambient effects and exact native conditional
weapon-icon lifecycle remain unfinished. The existing room modal combat gate is the documented
presentation/input adapter. Earned rendered attack-to-entry, integrated regressions and package
qualification remain required. Earlier hostile-section statements apply to the frozen r12h
candidate; this later patch implements only the attacked-arrival branch.

Stone pickup follow-up: 128 original handler0x594 replays cover flag150 and every combination
of flags154–159. Each admitted click sets the first unused flag and requests one
`66-Ancients stn`; only flag154's pickup also requests cue2/30/24. All six flags set means
no further grant. Two registered hotspots therefore do not mean two stones. The native handler
commits the flag before calling the grant function and ignores its return; actual inventory
capacity/failure semantics still need evidence. This is source replay evidence, not implemented
stone gameplay. Local receipt: `chut_stone_pickup_dispatch_review.json`.
## Continuation checkpoint

The frozen r12h affected suite was last observed with 181 completed tests and zero failures;
the aggregate was still incomplete. This is a progress snapshot, not qualification approval.
Opus retains integration and renderer ownership. Apply the attacked-arrival slice after that run.

The next implementation is direct room attack and six stone pickups. No code for this slice
has been started. Native hotspot bounds are (274,169)–(373,352) and (374,169)–(456,352).
The attack clip998 has63 frames at188×220, positioned(272,136); its audio must still be decoded.
The following cue100/17 has57408 samples, and first-stone cue2/30 has12992 samples, both22050Hz.
Soundbank extraction requires its trailer mapping. Local receipts are
`chut_stone_hotspot_shape_review.json` and `chut_direct_attack_media_review.json`.

Reuse the existing room attack and inventory paths after checking capacity handling. Test
full inventory, duplicate prevention, actor/hotspot persistence and fresh-process restart.
Native latch/re-entry lifetime remains unresolved. The detailed continuation instructions are
in local `AI_COMMS/act1_completion_20261017/OPUS_CODEX_HANDOFF_20261025.txt`.
Full Act1 acceptance remains open; delivered r12f and the r12e fallback are unchanged.

## Prepared direct-attack media and inventory integration findings

The missing original media is now staged privately, with source hashes and decoded counts
verified: attack clip998 has63 frames and103634 mono samples; cue100/17 has57408 samples
and cue2/30 has12992 samples, all22050Hz. The decoder returned success with demux warnings;
exact counts passed, while audible and in-game rendered fidelity still require review.
Local receipt: `chut_direct_media_staging_review.json`. These assets are not included in GitHub.

Both original CHUT.SHP hotspot images were decoded and visually inspected. They show adjacent
pieces of the seated chief, **not loose stone icons**. Preserve their original placement and
use the native handler's flags154–159 for the six rewards. Dimensions, indexed pixels, PNG
roundtrip and index0 transparency passed verification. Local receipt:
`chut_stone_media_staging_review.json`; native active-palette ownership remains untraced.

The generic room grant helper deduplicates identical item ids and capacity-checks only certain
existing rewards. It cannot grant all six stones unchanged. Add six distinct CHUT identities
to catalog lookup and enumeration with the existing ancient-stone use behavior; do not reuse
Cave/Hive/river identities or recycle consumed CHUT identities. Check capacity before committing
a pickup using the existing documented no-loss adapter. Native inventory-failure behavior
is still unverified. Local review: `chut_inventory_integration_review.json`.

Candidate remaining-work documentation also needs reconciliation after the frozen run:
Dark Halls is implemented and has intermediate campaign evidence; production swarm/shield
and final qualification remain open. Its old “not gameplay-integrated” and unknown-status
wording must not be used to assign duplicate work or claim completion. See local
`r12h_remaining_guide_reconciliation.json`.

## Reproducible direct-attack media tool

`chut-attack-media-tool.patch` adds a supplementary preparation tool and pinned numeric/hash
source contract (private commit `be11dcfe2406a64d4188135558fdf4e959ebdaf5`). Run
`python3 tools/prepare_chut_attack_media.py --game GAME --output-root FRESH`.
It uses the existing published decoders and ffmpeg; no companion reverse-engineering checkout
is required. Fresh output matches all nine independently staged media files byte-for-byte.
It writes `attack_media.json`, leaving room manifest/runtime integration as explicit next work.
Decoder demux warnings persist despite successful exit and exact frame/sample verification;
audible/rendered checks remain open. Original media is not published.
