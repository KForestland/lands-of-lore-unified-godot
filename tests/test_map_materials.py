#!/usr/bin/env python3
"""Tests for tools/lol2/map_materials.py; skips when the pinned local game root is absent."""
import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / 'tools' / 'lol2'))
import map_materials as mm  # noqa: E402

GAME_ROOT = Path('/home/bob/lol2_out/museum_capture_20260913/game')

pytestmark = pytest.mark.skipif(not GAME_ROOT.exists(), reason='pinned game root unavailable')


def test_texture_key_formula_matches_first_seven_profiles():
    inventory = mm.load_inventory()
    known = {'L1_DC': 2972657927, 'L3_DH': 3107535131, 'L4_HJ': 3711781155,
             'L5_HC': 3777974535, 'L7_DH': 3375978779, 'L8_SJ': 1162706722,
             'L9_DR': 3512559939}
    for area_id, expected in known.items():
        gk = mm.area_by_id(inventory, area_id)['source']['geometry_key']
        assert (gk + mm.TEXTURE_KEY_OFFSET) & 0xffffffff == expected


def test_museum_byte_for_byte_and_interface(tmp_path):
    report = mm.export_materials(GAME_ROOT, 'L3_DH', tmp_path / 'L3_DH')
    assert report['museum_validation']['byte_for_byte_match'] is True
    assert report['identity']['texture_entry']['key_source'] == 'formula'
    assert report['descriptor_count'] > 0
    assert report['extracted_count'] + report['rejected_count'] == report['descriptor_count']
    assert (tmp_path / 'L3_DH' / 'materials.json').exists()
    for m in report['materials']:
        assert (tmp_path / 'L3_DH' / m['image']).exists()
    for r in report['rejected']:
        assert set(r) == {'index', 'flags', 'reason'}


def test_structural_fallback_used_for_unformulaic_maps(tmp_path):
    report = mm.export_materials(GAME_ROOT, 'L13_RC', tmp_path / 'L13_RC')
    assert report['identity']['texture_entry']['key_source'] == 'structural_fallback'
    assert report['identity']['texture_entry']['formula_match'] is False
    assert report['extracted_count'] > 0
    from PIL import Image
    by_index = {m['index']: m for m in report['materials']}
    decal = by_index[83]
    assert decal['flags'] == 0x8b and decal['alpha_cutout'] is True
    base = tmp_path / 'L13_RC'
    rgba = Image.open(base / decal['image'])
    indices = Image.open(base / 'material_0083/mip_0_indices.png')
    assert rgba.mode == 'RGBA'
    assert 0 in set(indices.getdata()) and any(indices.getdata())
    assert all(pixel[3] == (0 if index == 0 else 255)
               for pixel, index in zip(rgba.getdata(), indices.getdata()))
    opaque = next(m for m in report['materials'] if m['flags'] == 0xe1)
    assert not opaque.get('alpha_cutout', False)
    assert Image.open(base / opaque['image']).mode == 'RGB'


def test_reproduces_previously_hand_curated_jungle_floor_variants(tmp_path):
    report = mm.export_materials(GAME_ROOT, 'L4_HJ', tmp_path / 'L4_HJ')
    by_index = {m['index']: m for m in report['materials']}
    expected_variants = {41: 7, 85: 1, 618: 9, 655: 1, 808: 5, 849: 5}
    for index, variants in expected_variants.items():
        assert by_index[index]['variant_count'] == variants


def test_reproduces_previously_hand_curated_hive_lava_variants(tmp_path):
    report = mm.export_materials(GAME_ROOT, 'L5_HC', tmp_path / 'L5_HC')
    by_index = {m['index']: m for m in report['materials']}
    assert by_index[13]['variant_count'] == 3
    assert by_index[171]['variant_count'] == 10


def test_unsupported_flags_are_reported_never_fabricated(tmp_path):
    report = mm.export_materials(GAME_ROOT, 'L3_DH', tmp_path / 'L3_DH')
    assert report['rejected_by_flags'].get('0x1246', 0) > 0
    decoded_families = {m['family'] for m in report['materials']}
    assert decoded_families <= {'a9_mip_chain', 'raw_variant', 'column_major_variant', 'column_rle'}


def _png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    assert data[12:16] == b'IHDR'
    import struct
    return struct.unpack('>II', data[16:24])


def test_l16_column_repeats_use_verified_native_decoder(tmp_path):
    report = mm.export_materials(GAME_ROOT, 'L16_CA', tmp_path / 'L16_CA')
    by_index = {m['index']: m for m in report['materials']}
    column = by_index[398]
    assert column['flags'] == 0xc7
    assert column['variant_count'] == 20
    assert column['mip_levels'] == 5
    assert len(column['animation_frames']) == 20
    assert column['column_decoder'] == 'native_12621c'
    assert 'rle_repeat_1_or_2' not in column
    # Top frame does not need a lead of 1 or 2; its RGB name stays the prior one.
    assert (tmp_path / 'L16_CA' / 'material_0398' / 'variant_0.png').exists()
    assert (tmp_path / 'L16_CA' / 'material_0398' / 'variant_0_indices.png').exists()


def test_l17_nonzero_phase_stays_inside_its_animation_group(tmp_path):
    report = mm.export_materials(GAME_ROOT, 'L17_HC', tmp_path / 'L17_HC')
    material = {m['index']: m for m in report['materials']}[378]
    assert material['field8_raw'] == 259
    assert material['variant_count'] == 3
    assert 'variable_frame_sizes' not in material
    assert material['phase_group']['frame_order'] == [378, 379, 377]
    assert 'shadow_blend_candidates' not in material
    folder = tmp_path / 'L17_HC' / 'material_0378'
    assert _png_size(folder / 'variant_2.png') == (128, 128)
    assert _png_size(folder / 'variant_2_indices.png') == (128, 128)
    assert _png_size(folder / 'variant_0.png') == (128, 128)
    assert (tmp_path / 'L17_HC' / 'palette_rgb.png').exists()
    assert _png_size(tmp_path / 'L17_HC' / 'shade64_remap.png') == (256, 1)


def test_decoded_layout_uses_native_storage_not_descriptor_high_bit(tmp_path):
    gaps_path = Path('/home/bob/lol2_out/all_maps_20260922/surface_descriptor_gaps.json')
    if not gaps_path.exists():
        pytest.skip('surface gap audit unavailable')
    import json as _json
    gaps = _json.loads(gaps_path.read_text())
    area = next(a for a in gaps if a['id'] == 'L17_HC')
    report = mm.export_materials(GAME_ROOT, 'L17_HC', tmp_path / 'L17_HC')
    by_index = {m['index']: m for m in report['materials']}
    seen = set()
    for ref in area['resolved']:
        material = by_index.get(ref['resource'])
        if material is None or material['flags'] == 0x80a9:
            continue
        if material['flags'] not in (0x80e1, 0x808b, 0x20e1, 0xc3, 0xc7, 0x80c7):
            continue
        seen.add(material['flags'])
        assert material['pixel_layout'] == 'row_major_export'
        expected = 'column_rle' if material['family'] == 'column_rle' else 'column_major_raw'
        assert material['source_pixel_layout'] == expected
    assert 0x80e1 in seen or 0x808b in seen or 0x20e1 in seen


def test_batch_covers_all_fifteen_pinned_areas(tmp_path):
    summary = mm.batch_export(GAME_ROOT, tmp_path / 'all')
    assert summary['map_count'] == 15
    assert summary['succeeded'] == 15
    assert summary['failed'] == 0
    assert (tmp_path / 'all' / 'batch_report.json').exists()
    assert json.loads((tmp_path / 'all' / 'batch_report.json').read_text())['map_count'] == 15
