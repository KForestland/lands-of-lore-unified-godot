# Kelsrick Fine Longsword loot

Original Jungle actor64 receives one definition5 Fine Longsword in arrival group31170, command `03024000be4082e104000000`. The item property is 4, not a quantity. The pinned archive bytes and definition identity were independently checked; artwork reuses the original Fine Longsword icon. See `kelsrick-loot-source-checks.json`.

The modern adapter retires the visible corpse after five active world seconds, then displays an aimed, unobstructed E pickup. Inventory identity `jungle:kelsrick:Fine_Longsword` is distinct from the Museum sword. A full inventory leaves the drop available. The optional `loot_taken` receipt preserves legacy saves and is checked against death, elapsed time and carried inventory. Jungle and Hive saves and area handoffs reject mismatched receipts before mutation.

The rendered regression uses real population damage and the engine physics callback for death/retirement, checks paused and inactive worlds, partial and taken disk reloads, an actual dispatched E pickup, equipment and Hive transport. Actor death, camera placement and the final timer boundary are supplied fixtures, not an earned campaign route. Native retirement timing and save-list layout are not claimed.
