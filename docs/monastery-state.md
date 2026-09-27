# Monastery state core

Julian records translation knowledge at office entry. Leaving on the translation visit plays the rune farewell; revisiting after translation plays a different sequence, and the subsequent exit grants one Power Orb after the specified dialogue boundary. The state core preserves visit counters, partial speech saves, the orb grant and older saves.

Morgan's pure orb planner consumes and returns the orb around two dialogue lines and a20-point current-health increase capped at maximum. It preserves the dead/disabled gates, same-visit refusal and next-visit absence. The live host owns health, inventory, media and presentation; this publication does not include that integration or original game assets.

Run the asset-free checks with Godot4:

```sh
godot --headless --path . --script res://tests/moff_revisit_state_test.gd
godot --headless --path . --script res://tests/morgan_orb_blessing_test.gd
```

The Julian test covers first/repeat visits, delayed grant, partial JSON saves, invalid states and older saves. Morgan's numeric fixtures contain400 health cases, orb callback cases and64 presence cases independently compared locally against the original executable. Unverified non-orb class-query branches and original binary bytes are excluded from this fixture. Native presentation flags, original timer cadence, full room integration and Act One completion are outside this change.
