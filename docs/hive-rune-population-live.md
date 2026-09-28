# Saved rune-dependent population

Local Hive integration now copies HIVEW templates22 then21 into retired source slots, reusing shared combat, animation and reward code. The restored pool is finite: slots23–29,32–36. This is a partial twelve-slot adapter, not the entire37-actor native pool. Copies retain slot identity, generation and destination inventory; unavailable slots produce no actor.

Retirement waits for death presentation and a saved counter (HIVEW5, EXEC3), mapped to seconds. A shared saved fractional clock admits at most one cleanup per tick. Native scheduler timing and global cleanup-gate reset are not reproduced. Nonempty inventories conservatively block cleanup pending original loot-disposal integration. Guardian death presentation remains the existing simplified adapter. Region284 entry and Hive arrival call the rune-gated copy operation; the saved inside latch prevents repeated triggers while remaining in the region. Exact native event scheduling remains an adapter.

Hive saves validate the whole packet, require schema-marked data, reject reusable slots whose originals remain alive, and restore without running arrival events. Jungle carries the packet. Legacy disk loads initialize an empty copy pool. Death retry now preserves defeated guardians to avoid resurrecting an original after its slot has been reused.

Validation: four focused state/animation tests pass through the standard runner. A headless live-scene test passes finite admission, template order, spell damage, aura target registration, delayed retirement, immediate lethal-hit state validity, partial-clock disk restore, malformed/missing packet rollback, region284 entry, repeat generations, Jungle handoff and legacy loading. It uses a test-only active-world adapter because headless Godot cannot capture the mouse; production input admission and rendered appearance are not covered. The full rendered suite could not start because sandbox restrictions prevent Xvfb sockets. Previous106-test results predate these changes and are not evidence for this version.

Opus and Grok were each given bounded90-second advisory requests; both timed out without findings. Local tests found and fixed a JSON float/template-ID validation error; review also fixed the lethal-hit phase transition before a save.

Publication includes only portable state helpers, their numeric animation contracts and the focused test. Full scene wiring, rendered fixtures and original media remain local. ActOne content completion and the fresh continuous cave-to-departure acceptance run remain OPEN.
