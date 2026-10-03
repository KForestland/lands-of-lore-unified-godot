# Live Hive warrior death and corpse persistence

Return warriors23–29 and the lower unfolding warrior33 now play source selector20 (13 frames, resource1591) on defeat, then retain selector21 (resource335) as a visible corpse. Corpses cannot be targeted and have no combat collision. Partial animation clocks survive JSON saves and Jungle travel; restoring an earlier living save restores the original sprite. Old defeated saves migrate directly to a corpse.

The implementation reuses the existing frame runtime and sprite presenter. Native selection/mask/corpse evidence is documented in [warrior selection](hive-warrior-selection.md). Host conversion at15fps, sprite size/anchoring, legacy migration and special index1 preview mapping remain adapters. Native audio, event11 side effects, special-mode cleanup, directional views and attack animation integration remain open. The feeding Executioner35 uses its existing separate presentation.

Validation: the91-check Hive suite passes, including the supplied-start quest walk in72.05seconds. Two focused rendered checks pass after the final removal of side-effectful assertions; that correction overlapped the full suite, so the full result is not claimed as a wholly fresh final-source run. A standalone death-clock test also passes. The live check covers partial-frame rollback, malformed-state rejection, pause, living restoration, legacy migration and corpse transport through Jungle saves.

An earned lower-warrior fight/return rerun passes in8.58seconds: two maximum Spark casts,27 strikes, final player health3, and actor33 saved as a corpse. Its actual input/output save hashes were checked against the earned approach and saved JSON. Earlier campaign legs are reused; this is not a fresh full Act One route.

Initial rendered runs failed with Godot self-list errors during rapid restore/screenshot operations. Waiting for a physics frame between living and corpse restoration fixes this test sequence; failed logs remain locally retained. This is not a claim to have fixed a general engine defect.

The implementation and original frames remain local. This progress PR publishes documentation and numerical verification summaries only. Full Act One remains open.
