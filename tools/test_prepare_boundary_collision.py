import copy
import unittest
from tools.prepare_boundary_collision import census, height_at, validate_inputs


def fixture(other_floor=60, other_ceiling=80, neighbour=None, wall=(0,60)):
    polys=[[(0,0),(100,0),(100,100),(0,100)],[(100,0),(200,0),(200,100),(100,100)]]
    vertices=[];regions=[]
    for index,poly in enumerate(polys):
        start=len(vertices);vertices.extend([[x*65536,-z*65536] for x,z in poly])
        regions.append({'vertex_indices':list(range(start,start+4)),
                        'neighbors':[None]*4,'floor_corners':[0 if index==0 else other_floor]*4,
                        'ceiling_corners':[100 if index==0 else other_ceiling]*4,'owner':None})
    regions[0]['neighbors'][1]=neighbour
    face={'kind':'source_wall','region':0,'edge':1,
          'points':[[100,wall[0],0],[100,wall[1],0],[100,wall[1],100],[100,wall[0],100]]}
    return {'regions':regions,'vertices_fixed':vertices},{'area':'TEST','faces':[face]},{'edges':[]}


class HeightBoundaryProbeTest(unittest.TestCase):
    def result(self, **kwargs):
        return census(*fixture(**kwargs))

    def test_stacked_higher_and_lower_rooms_are_not_passages(self):
        for floor,ceiling in [(60,80),(-150,-75)]:
            with self.subTest(floor=floor):
                result=self.result(other_floor=floor,other_ceiling=ceiling)
                self.assertEqual(result['counts']['new_null_edges'],1)
                self.assertEqual(result['rows'][0]['reason'],'null_neighbour_height_block')

    def test_same_level_room_and_real_low_opening_stay_open(self):
        for floor,ceiling in [(0,100),(0,20),(40,100)]:
            with self.subTest(floor=floor,ceiling=ceiling):
                result=self.result(other_floor=floor,other_ceiling=ceiling)
                self.assertEqual(result['block_face_keys'],[])
                self.assertEqual(result['counts']['preserved_null_edges'],1)

    def test_floor_match_alone_does_not_ignore_the_ceiling(self):
        result=self.result(other_floor=0,other_ceiling=5)
        self.assertEqual(result['counts']['new_null_edges'],1)

    def test_sloped_height_uses_probe_point_instead_of_minimum(self):
        poly=[(0,0),(100,0),(100,100),(0,100)]
        self.assertAlmostEqual(height_at(poly,[0,100,100,0],(90,30)),90)
        self.assertAlmostEqual(height_at(poly,[100,0,0,100],(90,30)),10)
        self.assertIsNone(height_at(poly,[0]*4,(101,30)))

    def test_linked_lower_band_blocks_but_native_aperture_does_not(self):
        result=self.result(neighbour=1)
        self.assertEqual(result['counts']['linked_band_edges'],1)
        self.assertTrue(all(s['native_opening']==[60,80] for s in result['rows'][0]['samples']))
        self.assertEqual(self.result(neighbour=1,wall=(60,80))['block_face_keys'],[])
        self.assertEqual(self.result(neighbour=1,wall=(0,70))['block_face_keys'],[])
        self.assertEqual(self.result(neighbour=1,other_floor=40)['block_face_keys'],[])

    def test_legacy_selected_edges_are_preserved_not_reclassified(self):
        geometry,pack,old=fixture(other_floor=0,other_ceiling=100)
        old['edges']=[[0,1]]
        result=census(geometry,pack,old)
        self.assertEqual(result['rows'],[])

    def test_floor_subdivision_inherits_owner_ceiling(self):
        geometry,pack,old=fixture(other_floor=0,other_ceiling=100)
        owner=copy.deepcopy(geometry['regions'][1]);geometry['regions'].append(owner)
        geometry['regions'][1]['ceiling_corners']=None
        geometry['regions'][1]['owner']=2
        result=census(geometry,pack,old)
        self.assertEqual(result['block_face_keys'],[])
        self.assertEqual(result['counts']['preserved_null_edges'],1)


    def test_input_guard_rejects_captured_height_variant(self):
        geometry,pack,old=fixture()
        geometry['source']={'area_id':'TEST','geometry_sha256':'pinned'}
        pack['source']={'geometry_sha256':'pinned'}
        old.update(area='TEST',geometry_sha256='pinned')
        pack['faces'].append({'kind':'floor','record_role':'primary_region','region':0,
                              'points':[[0,0,0],[100,0,0],[100,0,100],[0,0,100]]})
        validate_inputs(geometry,pack,old)
        geometry['regions'][0]['floor_corners']=[5]*4
        with self.assertRaisesRegex(ValueError,'corner heights differ'):
            validate_inputs(geometry,pack,old)
        old['area']='OTHER'
        with self.assertRaisesRegex(ValueError,'same area'):
            validate_inputs(geometry,pack,old)


    def test_raised_slot_gets_collision_only_below_the_opening(self):
        geometry,pack,old=fixture(other_floor=55,other_ceiling=75,neighbour=1,wall=(-80,90))
        geometry['regions'][0]['floor_corners']=[-80]*4
        original=copy.deepcopy(pack)
        result=census(geometry,pack)
        self.assertEqual(result['block_face_keys'],[])
        self.assertEqual(result['counts']['partial_band_faces'],1)
        points=result['collision_faces'][0]['points']
        self.assertEqual(min(p[1] for p in points),-80)
        self.assertEqual(max(p[1] for p in points),55)
        self.assertEqual(pack,original)
        self.assertTrue(all(p[1]<=55 for p in points))

    def test_renamed_wall_and_no_legacy_selection_are_supported(self):
        geometry,pack,_=fixture()
        pack['faces'][0]['kind']='wall'
        result=census(geometry,pack)
        self.assertEqual(result['counts']['new_null_edges'],1)
        self.assertTrue(result['block_face_keys'][0].startswith('wall|'))

    def test_degenerate_floor_validation_uses_exact_source_corners(self):
        geometry,pack,old=fixture()
        geometry['source']={'area_id':'TEST','geometry_sha256':'pinned'}
        pack['source']={'geometry_sha256':'pinned'}
        for index in range(4):geometry['vertices_fixed'][index][1]=0
        pack['faces']=[{'kind':'floor','record_role':'primary_region','region':0,
                       'points':[[0,0,0],[100,0,0],[100,0,0],[0,0,0]]}]
        validate_inputs(geometry,pack,{})
        pack['faces'][0]['points'][0][1]=5
        with self.assertRaisesRegex(ValueError,'corner heights differ'):
            validate_inputs(geometry,pack,{})

    def test_slope_endpoint_passage_is_not_marked_as_whole_solid(self):
        geometry,pack,_=fixture(other_floor=100,neighbour=1,wall=(0,51))
        geometry['regions'][1]['floor_corners']=[40,40,100,100]
        result=census(geometry,pack)
        self.assertEqual(result['block_face_keys'],[])
        self.assertEqual(result['counts']['partial_band_faces'],0)
        self.assertEqual(result['counts']['withheld_sloped_faces'],1)


    def test_native_neighbour_can_meet_only_middle_of_source_edge(self):
        geometry,pack,_=fixture(other_floor=55,other_ceiling=75,neighbour=1,wall=(-80,90))
        geometry['regions'][0]['floor_corners']=[-80]*4
        # A narrow slot on the middle30..70of the owning0..100edge.
        for index,z in zip((4,5,6,7),(30,30,70,70)):
            geometry['vertices_fixed'][index][1]=-z*65536
        result=census(geometry,pack)
        self.assertEqual(result['block_face_keys'],[])
        self.assertEqual(result['counts']['partial_band_faces'],1)
        self.assertTrue(result['collision_faces'])
        for part in result['collision_faces']:
            self.assertLessEqual(max(p[1] for p in part['points']),55)
        area=sum(abs(sum(a[2]*b[1]-b[2]*a[1] for a,b in zip(part['points'],part['points'][1:]+part['points'][:1])))/2 for part in result['collision_faces'])
        self.assertAlmostEqual(area,13500)


    def test_no_static_band_on_either_live_floor(self):
        geometry,pack,old=fixture(neighbour=1)
        for moving in [{0},{1}]:
            with self.subTest(moving=moving):
                result=census(geometry,pack,old,moving)
                self.assertEqual(result['block_face_keys'],[])
                self.assertEqual(result['collision_faces'],[])
                self.assertEqual(result['counts']['withheld_dynamic_faces'],1)

    def test_ceiling_subdivision_cannot_be_a_raised_floor(self):
        geometry,pack,old=fixture(other_floor=137,other_ceiling=147,neighbour=1,wall=(-40,137))
        geometry['regions'][1].update(record_role='floor_subdivision',owner=0)
        pack['faces'].append({'kind':'ceiling','record_role':'ceiling_subdivision','region':1,
                              'points':[[100,137,0],[200,137,0],[200,137,100],[100,137,100]]})
        result=census(geometry,pack,old)
        self.assertEqual(result['block_face_keys'],[])
        self.assertEqual(result['collision_faces'],[])
        self.assertEqual(result['counts']['withheld_ceiling_only_faces'],1)


if __name__=='__main__':
    unittest.main()
