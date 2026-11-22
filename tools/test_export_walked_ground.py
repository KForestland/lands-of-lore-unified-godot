import copy
import unittest
from tools.export_walked_ground import split_poses


def pose(index,area='L10_DC',host=1,discontinuity=''):
    return {'sample':index,'msec':index*20,'area':area,'host':host,
            'position':[index,32,index*2],'body':{'feet':0,'top':46},
            'on_floor':True,'resets':0,'discontinuity':discontinuity}


class WalkedGroundExportTest(unittest.TestCase):
    def test_area_host_and_jump_split_actual_segments(self):
        rows=[pose(0),pose(1),pose(2,area='L9_DR'),pose(3),pose(4),
              pose(5,host=2),pose(6,host=2),pose(7,host=2,discontinuity='native_jump'),pose(8,host=2)]
        before=copy.deepcopy(rows)
        groups=split_poses(rows,'L10_DC')
        self.assertEqual([[p['source_sample'] for p in group] for group in groups],[[0,1],[3,4],[5,6],[7,8]])
        self.assertEqual(rows,before)

    def test_axis_and_actual_bounds_survive_without_interpolation(self):
        rows=[pose(11),pose(12)]
        group=split_poses(rows,'L10_DC')[0]
        self.assertEqual(len(group),2)
        self.assertEqual((group[0]['x'],group[0]['h'],group[0]['z']),(11,32,22))
        self.assertEqual(group[0]['body'],{'feet':0,'top':46})
        self.assertEqual(split_poses([pose(0)],'L10_DC'),[])


if __name__=='__main__':unittest.main()
