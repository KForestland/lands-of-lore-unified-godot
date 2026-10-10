#!/usr/bin/env python3
"""Tests for the 0x342 movie-MIX inventory. Game-root checks skip when the capture is absent."""
import json
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'tools' / 'lol2'))
import map_video_inventory as inv  # noqa: E402

GAME = Path('/home/bob/lol2_out/museum_capture_20260913/game')
PROPS = Path('/home/bob/lol2_out/all_maps_20260922')
game_missing = pytest.mark.skipif(not GAME.exists(), reason='pinned game root unavailable')
props_missing = pytest.mark.skipif(not (PROPS / 'L3_DH/props/props.json').exists(), reason='props reports unavailable')


def test_inventory_path_is_outside_the_repo_tree():
    assert inv.INVENTORY_PATH == Path('/home/bob/AI_COMMS/map_first_20260922/video_map_inventory.json')
    assert REPO not in inv.INVENTORY_PATH.parents


def test_reason_parse_and_state_comparison_without_asset():
    parsed = inv.parse_reason(
        "external 0x342 resource 'hrglass.vqa' (raw 42034001c80016006872676c6173732e767161000000); not a texture-family sprite")
    assert parsed['filename'] == 'hrglass.vqa'
    assert (parsed['flags'], parsed['width'], parsed['height'], parsed['tail_u16']) == (0x342, 320, 200, 0x16)
    issue = dict(
        record=226, template=25, selector=0, region=680, placement_offset=1,
        placement_hex='3405970200800a00a246a802f208600327032800be000800ffff0002000001001900000003',
        frame_hex='dd0100171c00000000000000', source_frame_count=-1,
        later_state_frames='not claimed')
    compared = inv.compare_placement(parsed, issue, {})
    assert compared['dimensions_equal'] is None
    assert compared['state_consumes_one_frame'] is True
    assert compared['placement']['position'] == [1332, 10, -663]
    assert compared['frame']['descriptor'] == 477
    assert 'world_quad' not in compared


def test_resolved_fallback_keeps_movie_reference_without_duplicate_issue(tmp_path):
    directory = tmp_path / 'L3_DH' / 'props'
    directory.mkdir(parents=True)
    reference = dict(record=226, descriptor=477,
                     reason="external 0x342 resource 'hrglass.vqa' (raw 42034001c80016006872676c6173732e767161000000); not a texture-family sprite")
    path = directory / 'props.json'
    path.write_text(json.dumps(dict(video_references=[reference], issues=[reference])))
    rows = list(inv.iter_external_placements(tmp_path))
    assert len(rows) == 1 and rows[0][2]['filename'] == 'hrglass.vqa'
    path.write_text(json.dumps(dict(video_references=[reference], issues=[])))
    assert len(list(inv.iter_external_placements(tmp_path))) == 1


@game_missing
def test_hourglass_hash_hits_museum_movie_mix():
    found = inv.lookup_movie(GAME, 'L3_DH', 'hrglass.vqa')
    assert found['status'] == 'exact'
    assert found['key'] == 2686739476
    assert found['logical_name'] == 'SPHERE1\\L3_DH\\HRGLASS.VQA'
    assert found['archive'] == 'DAT/L3_DHI.MIX'
    assert found['vqhd']['width'] == 320 and found['vqhd']['height'] == 200
    assert found['vqhd']['count'] == 300
    assert len(found['blob']) == found['length']
    assert found['sha256']


@game_missing
def test_watrwall_is_the_unique_sphere2_entry():
    found = inv.lookup_movie(GAME, 'L9_DR', 'watrwall.vqa')
    assert found['status'] == 'exact'
    assert found['binding'] == 'unique_hash_header_witness'
    assert found['logical_name'] == 'SPHERE2\\L9_DR\\WATRWALL.VQA'
    assert found['key'] == 3670366617
    assert found['length'] == 548906
    assert found['archive'] == 'DAT/L9_DRI.MIX'
    assert found['vqhd']['width'] and len(found['blob']) == found['length']
    assert [hit['prefix'] for hit in found['candidates'] if hit['wvqa']] == ['SPHERE2']


@game_missing
def test_sphere_prefix_keeps_separate_ud07_and_l8_bc08():
    l8 = inv.lookup_movie(GAME, 'L8_SJ', 'bc08.vqa')
    l4 = inv.lookup_movie(GAME, 'L4_HJ', 'bc08.vqa')
    l10 = inv.lookup_movie(GAME, 'L10_DC', 'ud07.vqa')
    l16 = inv.lookup_movie(GAME, 'L16_CA', 'ud07.vqa')
    assert l8['status'] == 'exact' and l8['key'] == 3230549187
    assert l8['logical_name'] == 'SPHERE2\\L8_SJ\\BC08.VQA'
    assert l4['key'] != l8['key']
    assert l16['status'] == 'exact' and l16['key'] == 403742933
    assert l16['logical_name'] == 'SPHERE3\\L16_CA\\UD07.VQA'
    assert l10['status'] == 'exact' and l10['sha256'] != l16['sha256']


@game_missing
@props_missing
def test_inventory_covers_thirty_and_extracts_only_exact(tmp_path):
    report = inv.build_inventory(GAME, PROPS, tmp_path / 'video_resources')
    assert report['placement_count'] == 30
    assert report['exact_count'] == 30
    assert report['unresolved_count'] == 0 and report['ambiguous_count'] == 0
    assert report['binding'] == 'unique_hash_header_witness'
    wall = next(row for row in report['placements'] if row['filename'] == 'watrwall.vqa')
    assert wall['status'] == 'exact' and wall['key'] == 3670366617
    for row in report['placements']:
        assert row['comparison']['descriptor_flags'] == 0x342
        if row['status'] != 'exact':
            assert row['extracted'] is None
            assert row['sha256'] is None
        else:
            assert row['extracted']
            data = Path(row['extracted']).read_bytes()
            assert inv.sha256_hex(data) == row['sha256']
            assert len(data) == row['length']
            assert row['vqhd']['count'] > 0
            assert row['comparison']['dimensions_equal'] is True or row['comparison']['dimensions_equal'] is False
    assert report['unique_extracted'] == len({row['sha256'] for row in report['placements'] if row['status'] == 'exact'})
    assert all(path.is_file() for path in (tmp_path / 'video_resources').rglob('*.vqa'))
