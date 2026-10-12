#!/usr/bin/env python3
"""Tests for tools/lol2/map_props.py; skips when the pinned local game root is absent."""
import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / 'tools' / 'lol2'))
import map_props as mp  # noqa: E402

GAME_ROOT = Path('/home/bob/lol2_out/museum_capture_20260913/game')

pytestmark = pytest.mark.skipif(not GAME_ROOT.exists(), reason='pinned game root unavailable')


def test_museum_static_and_sequence_props(tmp_path):
    report = mp.export_props(GAME_ROOT, 'L3_DH', tmp_path / 'L3_DH')
    assert report['summary']['rendered_placements'] > 0
    # Current Museum exporter accounts for every placement without deferral.
    assert report['summary']['deferred_placements'] == 0
    summary = report['summary']
    assert (summary['rendered_placements'] + summary['nonvisual_placements']
            + summary['deferred_placements'] == summary['source_placements'])
    assert summary['accounted'] == summary['source_placements']
    assert (tmp_path / 'L3_DH' / 'props.json').exists()
    for path in report['materials'].values():
        assert (tmp_path / 'L3_DH' / path).exists()
    for frames in report['animations'].values():
        for f in frames['frames']:
            assert (tmp_path / 'L3_DH' / f).exists()
    for issue in report['issues']:
        assert {'record', 'template', 'selector', 'region', 'placement_offset',
                'placement_hex', 'reason'} <= set(issue)


def test_known_museum_sequence_descriptors_are_rendered_as_animations(tmp_path):
    report = mp.export_props(GAME_ROOT, 'L3_DH', tmp_path / 'L3_DH')
    for key in ['prop_187', 'prop_250', 'prop_279', 'prop_320', 'prop_363', 'prop_955']:
        assert key in report['animations'], key


def test_ordinary_multi_frame_state_is_rendered_as_animation(tmp_path):
    # Template2 in L3_DH has a single selector, flags0, and an 8-frame ordinary
    # state (descriptors 243,242,241,248,247,246,245,244); see module docstring.
    report = mp.export_props(GAME_ROOT, 'L3_DH', tmp_path / 'L3_DH')
    assert 'prop_243' in report['animations']
    assert len(report['animations']['prop_243']['frames']) == 8


def test_supported_flags_and_placement_selectors_are_preserved(tmp_path):
    report = mp.export_props(GAME_ROOT, 'L3_DH', tmp_path / 'L3_DH')
    rendered = {prop['template'] for prop in report['props']}
    for template in report['deferred_templates']:
        assert template['flags'] & ~3
        assert template['template'] not in rendered
    for prop in report['props']:
        placement = bytes.fromhex(prop['placement_hex'])
        assert prop['selector'] == placement[35]
        assert prop['top'] > prop['bottom']
    assert len({p['record'] for p in report['props']}) == len(report['props'])


def test_l5_null_region_lookup_uses_state_height(tmp_path):
    report = mp.export_props(GAME_ROOT, 'L5_HC', tmp_path / 'L5_HC')
    found = {prop['record']: prop for prop in report['props'] if prop['record'] in (615, 685, 767)}
    assert set(found) == {615, 685, 767}
    assert not any(issue['record'] in found for issue in report['issues'])
    expect = {615: (-1056, 7826, -9036), 685: (-429, 7494, -12242), 767: (-1068, 7262, 12054)}
    for record, prop in found.items():
        raw = bytes.fromhex(prop['placement_hex'])
        x, y, z = (int.from_bytes(raw[off:off + 2], 'little', signed=True) for off in (0, 2, 6))
        assert (x, y, z) == expect[record]
        assert int.from_bytes(raw[10:12], 'little') == 65535
        assert prop['region'] is None
        assert prop['position'] == [x, z, -y]
        state = bytes.fromhex(prop['state_hex'])
        frame = bytes.fromhex(prop['frame_hex'])
        assert prop['top'] == state[0x0F] - frame[6]
        assert prop['top'] > prop['bottom']


def test_unbound_regions_are_preserved_without_guessing_activity(tmp_path):
    report = mp.export_props(GAME_ROOT, 'L3_DH', tmp_path / 'L3_DH')
    for prop in report['props']:
        source = bytes.fromhex(prop['placement_hex'])
        region = int.from_bytes(source[10:12], 'little')
        assert prop['region'] == (None if region == 65535 else region)
    for issue in report['issues']:
        if 'sentinel 65535' in issue['reason']:
            assert issue['region'] is None
            assert 'region-height' in issue['reason']


def test_materials_cross_check_against_map_materials_output(tmp_path):
    sys.path.insert(0, str(REPO_ROOT / 'tools' / 'lol2'))
    import map_materials as mm
    materials_out = tmp_path / 'materials' / 'L3_DH'
    mm.export_materials(GAME_ROOT, 'L3_DH', materials_out)
    report = mp.export_props(GAME_ROOT, 'L3_DH', tmp_path / 'props' / 'L3_DH',
                              material_root=materials_out)
    assert report['materials_cross_check'] == dict(
        texture_bin=str(materials_out / 'texture.bin'), byte_identical=True)


def test_batch_covers_all_fifteen_pinned_areas_never_crashes(tmp_path):
    summary = mp.batch_export_props(GAME_ROOT, tmp_path / 'all')
    assert summary['map_count'] == 15
    assert summary['succeeded'] == 15
    assert summary['failed'] == 0
    assert (tmp_path / 'all' / 'props_batch_report.json').exists()
    for entry in summary['maps']:
        assert entry['ok'], entry


def _texture(area_id: str):
    import map_materials as mm
    inventory = mm.load_inventory()
    area = mm.area_by_id(inventory, area_id)
    mix = (GAME_ROOT / area['source']['file']).read_bytes()
    entries = mm.parse_mix(mix)
    identity = mm.identify_entries(mix, entries, area['source']['geometry_key'])
    blob, _info = mm.decode_lzo_container(mix, identity['texture_entry'])
    return mm, blob, mm.sections(blob)


def test_colour_filenames_stay_stable_and_masks_are_grayscale(tmp_path):
    from PIL import Image
    report = mp.export_props(GAME_ROOT, 'L3_DH', tmp_path / 'L3_DH')
    assert report['initial_remap']['length'] == 256
    assert report['initial_remap']['offset_rule'] == 'sections[4] + 0x4000'
    assert len(report['initial_remap']['remap_hex']) == 512
    colour_names = set()
    saw_shadow = False
    for sprite in report['sprites']:
        assert sprite['image'].endswith('.png')
        assert '_colour' not in sprite['image']
        colour_names.add(sprite['image'])
        for path_key in ('image', 'index', 'shadow'):
            path = tmp_path / 'L3_DH' / sprite[path_key]
            assert path.is_file()
        assert Image.open(tmp_path / 'L3_DH' / sprite['index']).mode == 'L'
        shadow = Image.open(tmp_path / 'L3_DH' / sprite['shadow'])
        assert shadow.mode == 'L'
        assert set(shadow.getdata()) <= {0, 255}
        if sprite.get('omitted_index1_pixels', 0) > 0:
            saw_shadow = True
            assert 255 in shadow.getdata()
    assert saw_shadow
    for animation in report['animations'].values():
        assert len(animation['shadow_frames']) == len(animation['frames'])
        assert len(animation['index_frames']) == len(animation['frames'])
    assert any(Path(name).name == 'prop_243.png' for name in colour_names)


def test_hive73_bane70_and_82c6_sequences_match_source_spans(tmp_path):
    import struct
    cases = (
        ('L5_HC', 81, 0x2C6, 73),
        ('L20_BB', 52, 0x2C6, 70),
        ('L4_HJ', 162, 0x82C6, 10),
    )
    for area_id, descriptor, flags, variants in cases:
        mm, blob, sec = _texture(area_id)
        palette_offset = struct.unpack_from('<I', blob, 4)[0]
        rgb = mm.rgb_palette(blob[palette_offset:palette_offset + 768], 6)
        image = mp.build_image(descriptor, blob, sec, rgb, tmp_path / area_id / 'sprites',
                                tmp_path / area_id, {})
        assert image['descriptor_flags'] == flags
        assert image['kind'] == 'sequence'
        assert len(image['frames']) == variants
        assert len(image['shadow_frames']) == variants
        assert len(image['index_frames']) == variants
        assert image['image'].endswith(f'prop_{descriptor}_frame_0.png')
        assert image['shadow'].endswith(f'prop_{descriptor}_frame_0_shadow.png')
        assert (tmp_path / area_id / image['shadow']).is_file()


def test_animation_keys_do_not_collapse_different_frame_sequences():
    animations = {}
    first = mp.animation_key('prop_1382', ['a', 'b'], animations, 34, 0)
    animations[first] = dict(frames=['a', 'b'])
    same = mp.animation_key('prop_1382', ['a', 'b'], animations, 99, 0)
    other = mp.animation_key('prop_1382', ['a', 'c'], animations, 35, 0)
    assert first == same == 'prop_1382'
    assert other == 'prop_1382__t35s0'
    assert other != first


def test_animation_key_does_not_mark_a_static_first_image_animated():
    animations = {'prop_1382': dict(frames=['a', 'b', 'c'])}
    still = mp.static_material_key('prop_1382', animations, 7, 1)
    assert still == 'prop_1382__t7s1'
    assert still not in animations
    animations = {}
    static_keys = {'prop_1382'}
    animated = mp.animation_key('prop_1382', ['a', 'b'], animations, 8, 0, static_keys)
    assert animated == 'prop_1382__t8s0'
    assert animated not in static_keys


def test_empty_flags0_descriptor_is_nonvisual_evidence(tmp_path):
    report = mp.export_props(GAME_ROOT, 'L3_DH', tmp_path / 'L3_DH')
    assert report['nonvisual_props']
    assert all(entry['reason'].startswith('nonvisual descriptor 0:') for entry in report['nonvisual_props'])
    assert all('impossible' not in entry['reason'] for entry in report['nonvisual_props'])
    sample = report['nonvisual_props'][0]
    assert {'record', 'template', 'selector', 'placement_offset', 'placement_hex',
            'reason', 'descriptor_hex'} <= set(sample)
    assert sample['descriptor_hex'] == '00' * 56
    assert not any(issue['reason'].startswith('nonvisual descriptor') for issue in report['issues'])
    summary = report['summary']
    assert (len(report['props']) + len(report['nonvisual_props']) + len(report['issues'])
            == summary['source_placements'] == summary['accounted'])


def test_block_negative_and_nested_families(tmp_path):
    from PIL import Image
    block = mp.export_props(GAME_ROOT, 'L3_DH', tmp_path / 'L3_DH')
    rendered_blocks = [prop for prop in block['props'] if prop['template'] in (39, 29)]
    assert len(rendered_blocks) == 2
    for prop in rendered_blocks:
        assert prop['frame_flags'] & 0xC0 == prop['frame_flags'] & 0xC0
        sprite = next(s for s in block['sprites'] if s['image'].endswith(f"prop_{prop['material'].split('__')[0].split('_')[1]}.png")
                      or s['key'] == prop['material'] or s['image'] == block['materials'][prop['material']])
        assert sprite['kind'] == 'block'
        assert sprite['descriptor_flags'] == 0x1246
        shadow = Image.open(tmp_path / 'L3_DH' / sprite['shadow'])
        assert set(shadow.getdata()) == {0}
        assert Image.open(tmp_path / 'L3_DH' / sprite['index']).mode == 'L'
    flipped = [prop for prop in rendered_blocks if prop['frame_flags'] & 0x40]
    assert flipped
    assert flipped[0]['frame_hex'][4:6] == '40'

    # Inactive movie selectors now resolve to their original fallback selector.
    # These three placements were formerly deferred; retain exact identities.
    fallback_visual = [prop for prop in block['props'] if prop.get('fallback_chain')]
    fallback_empty = [prop for prop in block['nonvisual_props'] if prop.get('fallback_chain')]
    assert {prop['record'] for prop in fallback_visual} == {216, 226}
    assert {prop['record'] for prop in fallback_empty} == {163}
    for prop in fallback_visual + fallback_empty:
        assert prop['fallback_chain'] == [0, 1]
        assert prop['source_selector'] == 0 and prop['displayed_selector'] == 1
    assert fallback_empty[0]['descriptor'] == 0

    nested = mp.export_props(GAME_ROOT, 'L10_DC', tmp_path / 'L10_DC')
    sequenced = [prop for prop in nested['props'] if prop.get('state_frames')]
    assert len(sequenced) == 1
    state_frames = sequenced[0]['state_frames']
    assert len(state_frames) == 4
    assert all(frame['kind'] == 'sequence' for frame in state_frames)
    assert len(state_frames[0]['frames']) == 11
    anim = nested['animations'][sequenced[0]['material']]
    assert anim['frames'] == state_frames[0]['frames']
    assert len(anim['frames']) < sum(len(frame['frames']) for frame in state_frames)


def test_every_placement_is_rendered_nonvisual_or_has_an_explicit_issue_reason(tmp_path):
    summary = mp.batch_export_props(GAME_ROOT, tmp_path / 'all')
    assert summary['total_nonvisual_placements'] == 1276
    assert summary['total_rendered_placements'] + summary['total_nonvisual_placements'] + summary['total_deferred_placements'] == summary['total_accounted']
    for entry in summary['maps']:
        report = json.loads((tmp_path / 'all' / entry['area_id'] / 'props' / 'props.json').read_text())
        counts = report['summary']
        assert (len(report['props']) + len(report['nonvisual_props']) + len(report['issues'])
                == counts['source_placements'] == counts['accounted'])
        assert counts['rendered_placements'] + counts['nonvisual_placements'] + counts['deferred_placements'] == counts['accounted']
        for issue in report['issues']:
            assert issue['reason']
        for entry_nv in report['nonvisual_props']:
            assert entry_nv['reason'] and entry_nv['placement_hex'] and entry_nv['descriptor_hex']
