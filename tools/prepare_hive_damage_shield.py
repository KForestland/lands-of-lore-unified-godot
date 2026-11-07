#!/usr/bin/env python3
"""Prepare the existing damage-shield resource contract from pinned original LOCAL.MIX.

The identity local index133 + first block336 is established by the historical
native witness docs/hive-damage-shield-record.json. This tool re-reads that exact
record and preserves the runtime contract; it does not rerun the native witness.
"""
import argparse
import hashlib
import json
from pathlib import Path
from lol2_source_format import parse_mix, u32
ARCHIVE_SHA = 'd0783146cad8823b3cbc540373fc85cd80482dff4375eaab7bc2a352e97fa278'
ASSET_SHA = '36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93'
RECORD_SHA = '4b48c8191f66882134b6ac3718326ab027f0769300c7dd42794d7523625b8270'
def sha(data): return hashlib.sha256(data).hexdigest()
def prepare(archive, output):
    archive, output = archive.resolve(), output.resolve()
    if output.exists(): raise ValueError('Output root must be fresh')
    if archive == output or output in archive.parents: raise ValueError('Output overlaps input')
    data = archive.read_bytes()
    if sha(data) != ARCHIVE_SHA: raise ValueError('Unsupported LOCAL.MIX hash')
    entries = [e for e in parse_mix(data) if e['key'] == 4018716831]
    if len(entries) != 1: raise ValueError('Expected one pinned texture entry')
    entry = entries[0]
    blob = data[entry['offset']:entry['offset'] + entry['size']]
    if sha(blob) != ASSET_SHA: raise ValueError('Texture entry hash mismatch')
    second = u32(blob, 0x298)
    start = second + u32(blob, second + 16)
    first_count, second_count = u32(blob, 0x2a8), u32(blob, second + 0x2a8)
    if (first_count, second_count) != (336, 3663): raise ValueError('Unexpected texture block counts')
    offset = start + 133 * 56
    record = blob[offset:offset + 56]
    if offset != 3393494 or sha(record) != RECORD_SHA or record[8] != 16:
        raise ValueError('Damage shield identity mismatch')
    result = dict(version=1, name='dam_sh.flc', resource=first_count+133, limit=record[8],
                  source_sha256=sha(data), asset_sha256=sha(blob), entry_key=entry['key'],
                  record_asset_offset=offset, record_sha256=sha(record))
    # Validate all inputs before creating output. Fresh output may remain on I/O failure.
    output.mkdir(parents=True, exist_ok=False)
    target = output/'assets/lol2/generated/hive_attack_adjustment_resource.json'
    target.parent.mkdir(parents=True)
    target.write_text(json.dumps(result, indent=2)+'\n')
    return target

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    try: print(prepare(args.archive,args.output_root))
    except (OSError,ValueError) as error: parser.exit(2, str(error)+'\n')
if __name__=='__main__': main()
