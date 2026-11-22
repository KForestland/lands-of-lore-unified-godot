# L10 oil opening regression

The robot on60147ae found a player fault. It cast at(-1435,32,-3192), on upper region1596. The old collapse removed that entire floor polygon even where no catacomb floor existed below. Its next W step fell into void and triggered recovery to the mirror arrival. The older v4 sitting retreated before the cast and entered farther south over the real lower floor, so it missed this case.

The approved modern clipping rule retains the original upper floor and art over unsupported areas. Only the overlap with the25 existing catacomb floor polygons becomes an opening; their original floors-90..-85 remain the landing. The35 selected source floors, removed controls, state packet, spell/range/blast and recovery rules stay unchanged. Geometry remains in the oil owner's own existing bodies. No landing platform or main-terrain triangles are added.

Convex half-plane subtraction keeps inner cuts open: polygon-difference inner contours must not be rendered as additional filled polygons. Every resulting cut retains its source UV mapping and triangulates.

Committed input fixtures are unchanged game-written saves: `l10_robot_oil_entry_20261113.json` is the robot full-run autosave at its second Cemetery return (SHA2566eccba51f5bbb179d8bc331cc659bfb905e30a57e647d3209efda1d1cbe24c1a). The actual red reproduction walked that save through109/switch/barrel and wrote `l10_robot_oil_stand_20261113.json` byF5 before casting (SHA256abb72467dfbd8000380c1e95e78954973eef1a3b38dfb4a2bdfeab645237854c). No pose, health or quest fields were edited.

Targeted rendered gates: `generic_l10_robot_oil_fall_test` repeats that full continuation with the robot4/240clock. `generic_l10_oil_rim_input_test` repeats from the reached close-casting stand, walks the north/east rim byW, descends, then reloads for the v4 retreat/cast/descent at ordinary1/60. Both use realF2/F9/Q/W/F5. Their clocks and checkpoint installations are disclosed source sites. `l10_oil_opening_geometry_test` checks1345samples across all selected floors, the known rim/descent points and all cut triangulation. Run with affected `l10_oil_earned_test` and `l10_map_test`, using the guarded Dummy launcher and the normal staged inputs; no ignored new input is needed. See `generic-l10-testing.md` for the runner/display setup.

The final post-flash hole frame and dense separate4x/1x traces are published under AI_COMMS/sol_lane/l10_oil_fall_20261113/final_proof/runtime_outputs/.
