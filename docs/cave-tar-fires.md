# Cave tar pits: ignition, spreading fire and the guard pit

`tools/prepare_cave_tar_fires.py` pins the records from the original `L1_DC` archive and checks every record and command byte for byte. It writes `scripts/lol2/cave_tar_fires_source.json` and stages the original index frames and sound request 462 into `assets/lol2/generated/cave_tar_fires/`. It refuses to overwrite existing output. `scripts/lol2/cave_tar_fires.gd` hosts the pits in the Cave.

The recovered prop preview omits animated props, so none of the 27 tar props was drawn before this change. The first pit was a bare black pool (playtest report 10:59:16), and guard-pit tar appeared only as the scenic owner's selector-2 fires.

## Source

**Tar props** (templates 34/35/36/89) have three selectors:
- 0: bubbling tar (descriptor 449, 20 frames);
- 1: ignition (907, 35 frames);
- 2: burning loop (126, 7 frames).

The sprite bounds come from each selector's first frame. The top is `state_height - top_trim`.

**Hit (kind9)**
- Applies at owner state 0, with masks 0x0011/0x0000 and threshold 99, mode 4.
- AE2C8 admits the hit when the hit context shares a mask bit: Spark context 1/1, or bit 0x10, which op19 below uses for fire hits.
- Melee context 2/4 shares no bit and is refused.

**Ignition group**
- **First pit** (props 465–471, 640): op9 self property 19 = 9, then op5 prop464 selector 1, op6 self sub-op 1, op5 self selector 1, op16 state 1, op20 sound 462.
  - Property 19 (B5420) writes the object's durability byte (+0x26).
  - op6 sub-op 1 (9F584) restarts the animation.
- **Guard pit** (props 440–446, 575–586): op19 prop223, then op5 prop439 selector 1, followed by the same tail.
  - op19 (66130) delivers a hit to prop 223 with masks 0x0010/0x0000 and damage 5.
- **Exceptions:**
  - Props 583 and 584 have no op19.
  - Prop 577's first record, the one AE2C8 runs, leaves out the sequencer advance. Its second record (local12 == 0 AND state 0) is never reached first.

**Animation end:** kind6 value 3 at state 1 runs op5 self selector 2. Prop 466 also sets state 2.

**Sequencers:** props 464 (first pit) and 439 (guard pit), template 82. Neither is drawn: prop 464 sits at height +435.
- **Timer (kind2), flags 0:**
  - B8AC4 reloads with `random(20..30) << 8` (12415C).
  - The countdown (word 8) is in 1/256 native ticks.
  - The record countdowns are 23 and 27 ticks.
- **On expiry at owner state 1:** op5 self selector +1. Byte 5 = 1 is relative: the record structure needs it to reach kind3 values 2..N.
- **kind3 value 1:** op14 sub-op 3 starts the timer and op16 sets state 1.
  - Sub-op 3 (B485C) with argument 0 keeps the countdown and does nothing on a running timer.
- **kind3 values 2..N:** op19 hits the next tar prop with masks 0x0011/0x0001.
  - Damage mode 0x70 leaves a pointer-sized value, which admits mode 4.
  - Prop 464's order: 467, 469, 468, 640, 471, 466, 465, 470.
- **Last kind3 value:** op14 sub-op 4 (B494B) stops the timer.
- **Prop 464, kind6 value 9:** the cave-arrival scanner (op14 sub-op 4) stops the timer. Prop 439's timer record starts stopped.
- **Spread:** every ignition resets its sequencer to selector 1, so the fire spreads prop by prop. Prop 464 lights all 8 and then stops at selector 10.

**Prop 223** is placed absent; stream 0 group 560 (the region-969 sighting) sets property 3 on it. Its op19 fire hits are delivered to `cave_scenic_guard` (`receive_prop223_hit`), which runs groups 2326/2732; see `cave-prop223.md`.
- Its own kind9 (masks 0x0011/0x0000, threshold 2, mode 0x83) runs group 2326, the explosion of group 5926 without:
  - the prop1031 property-21 magic reward;
  - the second sound;
  - the actor55 op13/state commands, which burn guard 55.
- **Only prop 574's Spark burns the guard.** That is group 5926, hosted by `cave_scenic_guard_effects.gd`.

## Port

- **Drawing:**
  - Indexed layer-2 billboards, mirrored into the layer-4 occluder pass, at 10 frames/s.
  - Guard-pit selector 2 is handed to the existing scenic fire meshes (`cave_scenic_guard_effects` `selectors`). This owner hides its own sprite while the scenic mesh shows.
  - The scenic prop574 explosion also selects those meshes directly.
- **Hits:**
  - The Spark ray reaches a `spark_receiver` box: selector-0 sprite width × template height (byte 28) × template depth (byte 30). This is the rule the scenic prop 574 box follows (255 × 159 × 8).
  - Sequencer hits call the same AE2C8 replay.
- **Clock:** 60 native ticks/s while `world_active()`. The timer replays B8C16 with a fixed step of 256 units: decrement, or reload with carry.
- **Save:** `cave_tar_fires` is validated by `walkthrough_save.gd`. Only the ignition clock (selector 1, whose end raises kind6 value 3) is persisted; the looping selector-0/2 phases save as 0, so a reload restarts those loops at frame 0:
  - `{"version":1, "props":{id:{selector, state, durability, clock}}, "sequencers":{id:{selector, state, enabled, left, seed}}}`;
  - selector/state pairs are 0/0, 1/1, 2/1 or 2/2.

## Adapters and limits

- **Timer reload:** uses a saved port PRNG; the native 12415C generator state is not replayed.
- **Animation:** the rate is 10 frames/s; native sequence timing is unverified. Event 3 fires at every cycle end of the shown selector.
- **Spark damage:** 8, the existing port adapter; the native damage calculation is not replayed.
- **Hit volumes:** follow the existing scenic rule; native prop collision is unproven.
- **Not hosted:**
  - the property-17 flag (0x4000), set by the explosion, whose consumer is unidentified (the hit receiver B4298 tests 0x400);
  - the fire crystal's mask (the port's `crystal_fire()` doesn't reach Spark receivers);
  - prop 597 (template 40; hit at state 1);
  - prop 577's local12.
- **Arrival:** the cave-arrival stop on prop 464 is applied as the initial state only. A loaded save keeps its timer.

## Tests

`tests/cave_tar_fires_test.gd` (rendered, production Cave):
- **10:59 pose:** shows the tar. Melee context and Beast-form Q (Beast cannot cast) are refused.
- **Human Q from the owner pose** (aimed by turning view) ignites prop 467:
  - sound 462, durability 9, and sequencer 464 starts;
  - after 3.5 s it shows the burning loop;
  - the fire spreads progressively to all 8 props;
  - the timer stops at selector 10.
- **Saves:** mid-spread and pre-ignition disk loads restore; malformed packets are rejected.
- **11:04 pose (Beast):** Q is refused.
- **Guard pit:**
  - Seen from the owner side, the prop 574 box covers the tar behind it.
  - Human Q on prop 584 ignites it, and the fire spreads to all 19 props through the scenic fire meshes, with 17 op19 fire hits on prop 223 and no prop 574 explosion.
  - Prop 574 Q still starts the hosted explosion.
