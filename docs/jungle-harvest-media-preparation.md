# Jungle harvest media preparation

Run from the source checkout with original game data, the decoded L4_HJ texture from the fresh map-material pipeline, and a new output directory:

```sh
python3 tools/prepare_jungle_harvest_media.py \
  --game /path/to/game \
  --texture /path/to/L4_HJ/materials/texture.bin \
  --source scripts/lol2/jungle_harvest_source.json \
  --output-root /path/to/fresh-output
```

Python 3, Pillow and the published local map-prop/item-icon helpers are required. No external RE checkout or native audit is loaded. Use ordinary Python without optimization because shared readers retain assertion checks.

The command pins the source contract, Jungle archive and decoded texture. It checks the eight original selector records against the contract (descriptor, selector and trim bounds), decodes their images, and checks their recorded hashes. Aloe and sap icons use explicit original-game item decoding. The ten final PNGs go under `assets/lol2/generated/jungle_harvest`; intermediate decoded sprites stay under `tmp/jungle_harvest`. Original and generated media remain local.

Existing destinations, missing inputs, overlapping input/output paths and mismatched pins are rejected. A later icon or image failure can leave a partial fresh directory; preserve it and retry in a new directory. The historical `prepare_jungle_harvest.py` source-audit producer is unchanged. This command prepares media only; it does not regenerate event, timer or gameplay contracts.

Independent reconstruction and a second run through this command both reproduced all ten runtime files byte-for-byte. Existing output, wrong texture, missing game and overlapping output controls passed. The initial private review driver used the wrong namespace for `u32`; that failed attempt was preserved and corrected before this command was created. No runtime or R18 candidate changes are involved.
