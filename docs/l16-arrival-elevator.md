# Ancient City arrival elevator source

STORY067 is not implemented or qualified. Original L16 bytes are pinned in `l16-arrival-elevator-source.json`.

Selector1 arrives at native(-3860,1341), region137, floor0. Nearby control78 template66 has kind5/value4 and5 events42098/42116 that set and enqueue control194 (template17). Its state branches49010/49034 change record bits; native door movement semantics remain unentered.

Beyond this doorway, region233 kind12 descriptor2 runs stream0 group564. It plays opcode21 movie27 on prop680, then opcode18 kind1 raw `120100002bf10df7000004080080000a0000`. The pinned movie table names27 `elevator.vqa`. The relocation words give native(-3797,-2291), Godot(-3797,2291); original destination floor343 is height0. This is a movie-backed source transition, not evidence for inventing a large moving platform. The physical route must reach the doorway/region233 before any relocation. Flags0x0804 establish native direct relocation on our b27a3534 build: signed+4/+6 are horizontal destination and+12 heading;0x0100 is clear, so+8=0 does not assign height. Trigger/movie hosting and floor grounding remain adapters, never a test shortcut. See the opcode18 evidence update in DEVIATIONS.md.

Original movie uniquely resolves in DAT/L16_CAI.MIX, SPHERE3\L16_CA\ELEVATOR.VQA, key1493230362, offset5715386, length5998298, SHA e1cbd9e3a97a695733efbb1d9122e99ff856ee14eb1b295701b85079654f62c2. Header255frames640x400 at15fps. No gameplay/rendered/listening claim.

Preparation PASS: `python3 tools/prepare_l16_elevator_movie.py --game ~/lol2_runtime_root` staged original17seconds under tmp/l16_elevator_staged. Encoded Ogg SHA2eb0f466095a24ebdf63256ae70a1b31f583efe1a13ec957a69e5d8ba1fcf18d. Use `--output assets/lol2/generated/l16_elevator` only after the source freeze ends. Decoder cache remains under tmp.
