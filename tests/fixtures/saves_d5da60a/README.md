These files were written by the actual, unchanged d5da60a save writers on Sol's
isolated foundation branch, before any production edits. manifest.json pins their
bytes and the observed health, form, equipment and independently saved cooldowns.

Generation used LOL2_WRITE_D5_FIXTURES=1 and health_saved_fixture_test. The generator
sets up wounded health and equipped inventory where valid, then invokes each scene's
quicksave. It does not construct or rewrite save packets. Cave/Museum have empty
weapons to preserve their existing collection invariants. Generation reports are
under AI_COMMS/sol_lane/foundation_20261111/fixture_generation_02; their intentional
fixture writes make source_stable=false. Qualification runs never enable generation.

These are compatibility fixtures and declared setup, not evidence of earned routes.
