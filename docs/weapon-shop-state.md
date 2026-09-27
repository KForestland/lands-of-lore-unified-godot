# Weapon shop state core

The detached WPNEXT/WPN state machine retains dialogue cursors, boundary effects, original admission predicates, once-only item grants and Power Orb knowledge. It includes the shorter response when orb knowledge was learned elsewhere, the Power Orb exchange for Firestorm, and the retained-dagger refusal. Callers receive effects and own inventory and presentation.

The headless check covers 128 recorded admission cases, state validation, partial JSON saves, event ordering, first/repeat item grants, previously known orb knowledge and delayed Firestorm grant. The callback plans were compared locally against both archived and loose original room scripts. This publication contains state code and numeric verification fixtures; it does not include original media or a playable room integration.

Run from the project root with Godot 4:

```sh
godot --headless --path . --script res://tests/weapon_shop_state_test.gd
```

Dialogue timing is supplied as prepared metadata and advanced through a modern clock adapter. The core does not establish original presentation, full shop parity or Act One completion.
