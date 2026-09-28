# Saved Hive boulder audio

The local encounter plays the three original cues: close sound704 (`stone4.aud`)
at prop234, exit sound701 (`stone6.aud`) at prop77, and persistent sound709
(`stonel1.aud`) owned separately by actors30/31. Rolling voices stop when the
corresponding actor consumes its terminal stop. Their PCM clocks and the two
finite cues survive saves and Jungle transport.

The exit cue lasts2.159455782 seconds, longer than the surface's2-second terminal
clock. Audio therefore has its own small save packet rather than deriving all
playback from the surface phase. New packets require every clock and the saved
surface/actor owners; invalid data rejects before scene mutation. Old saves
suppress past one-shots and restart still-rolling owners at zero because no
previous PCM offset exists. This is an explicit compatibility policy.

## Original-source evidence

`hive-boulder-audio-source.json` pins the archive/bank, exact source command
payloads, prop positions, three bank names and decoded sample counts. The local
preparation tool checks every AUD chunk and WAV round trip. The source close
clip declares one extra sample; encoded nibble counts own the output, with no
synthetic padding. This reuses the validation approach already used for the
bridge warning voice. The first strict header-count attempt failed and was
corrected after inspecting the chunks.

`hive-boulder-audio-native.json` records native x86 replay of12 command dispatch
cases,256 pool-selection branches,76 configuration copies,128 full owner-removal
scans through19 playing slots and256 persistent records, and32 persistent
completion/restart cases. The sound opcode passes its resolved owner and four
configuration bytes. Mask0x02 selects the persistent pool. Operation16 requests
channel shutdown and removes only records matching that owner. Persistent
completion retains ownership; an eligible selected nonplaying record requests
playback again. Allocator, queue copy and low-level audio calls are explicit
boundaries, not emulated devices.

A further2,000 native distance/fade cases cover both source ranges:48–144 for
rolling and192–288 for the surface cues. The shared portable state helper matches
every numeric fixture, including the original approximate distance and nonzero
fade byte at the exact far boundary.

## Remaining adapters

Godot supplies waveform looping, stereo panning, independent voice mixing,
listener placement, volume conversion and host-time scheduling. The native
manager can select/merge competing same-sound owners; that complete scheduling
and mixing policy is not implemented. Native save-format playback restoration
and device-buffer timing are also not claimed. Simulation pauses, conversations,
death, flying mode and zero time scale suspend the local audio clocks/streams.
Player contact damage and full Act One acceptance remain open.

## Validation and model review

The pure state check covers saved continuation, coarse phase crossings, the exit
tail beyond the surface cap, separate owner shutdown, malformed clocks, legacy
no-replay and2,000 native spatial fixtures. The rendered test checks the actual
original streams, midroll and exit-tail disk restore, pause/resume, zero time
scale, malformed rollback and Jungle transport. Existing boulder/surface and
normal/small route checks pass in the focused six-test run.

Opus5.5 and Grok provided bounded advice from supplied facts. Grok's proposed
actor-phase/cue timing was not adopted: it conflicts with the source surface
commands and the longer audio tail. A second Opus review read the implemented
state/controller and found two concrete audio-thread timing issues. Both are
fixed and covered: completed one-shots cannot restart their tails on a later
physics tick; rolling drift uses circular distance across the loop boundary.
The final focused state/live pair passes.

The earned continuation uses the actual hash-verified lower-fight save, rides
lift5/6, jumps/walks the source route, triggers the live trap and exits with both
actors stopped and all audio clocks complete. It writes a new
`act1_boulder_audio_earned_exit.json`, preserving earlier movement-only saves.
Earlier campaign legs are reused and contact damage is disabled; this is not a
fresh complete campaign or complete hazard test. Detailed source/report hashes
and the final broad-run qualification belong to `hive-boulder-audio-checks.json`.

Publication includes code, numeric fixtures and reports. Full scene/save wiring
and original media staging remain local. Original AUD/WAV files and personal
saves are not included in the public repository.

Validation closure: full101/101 Hive checks pass, including the71.65-second supplied-start quest walk. That run overlapped the final audio-thread timing fixes and native spatial integration; the final-source state/live pair and earned continuation8.29s also pass. All model and test processes are terminal.
