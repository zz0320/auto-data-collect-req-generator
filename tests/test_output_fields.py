import unittest

import app


class OutputFieldNormalizationTest(unittest.TestCase):
    def test_generated_metadata_columns_are_left_blank(self):
        robot = app.RobotProfile("乐聚", "KUAVO", "夹爪", "双臂", False, False, "")
        row = {
            "自动编号": "123",
            "任务ID": "abc",
            "采集时长（小时）": 2.5,
            "任务名称": "电池入槽",
            "任务简述": "把电池放入电池槽",
            "采集设备": "乐聚KUAVO",
            "采集模式": "双臂",
            "场景域分类": "工业制造",
            "任务步骤描述": "1. 抓取电池 <Pick（拿起）><8s>\n2. 放入电池槽 <Place（放置）><8s>",
            "目标次数": 60,
        }

        normalized = app.normalize_task(row, robot, serial=1, task_phase="pretrain")

        self.assertEqual(normalized["自动编号"], "")
        self.assertEqual(normalized["任务ID"], "")
        self.assertEqual(normalized["采集时长（小时）"], "")

    def test_phase_moves_to_task_name_not_brief(self):
        robot = app.RobotProfile("乐聚", "KUAVO", "夹爪", "双臂", False, False, "")
        row = {
            "任务名称": "【后训练】桌面分拣",
            "任务简述": "【后训练】按照颜色把积木分到不同托盘",
            "采集设备": "乐聚KUAVO",
            "采集模式": "双臂",
            "场景域分类": "通用抓取放置",
            "任务步骤描述": "1. 抓取积木 <Grasp（抓取）><8s>\n2. 放入托盘 <Place（放置）><8s>",
            "目标次数": 600,
        }

        normalized = app.normalize_task(row, robot, serial=1, task_phase="posttrain")

        self.assertEqual(normalized["任务名称"], "后-桌面分拣")
        self.assertEqual(normalized["任务简述"], "按照颜色把积木分到不同托盘")


if __name__ == "__main__":
    unittest.main()
