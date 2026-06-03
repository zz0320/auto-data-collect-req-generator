import os
import unittest
from pathlib import Path

import app


def sample_robot():
    return {"brand": "乐聚", "model": "KUAVO", "endEffector": "夹爪", "arms": "双臂", "mobile": False, "wholeBody": False}


def sample_task(name="预-电池入槽"):
    return {
        "任务名称": name,
        "任务简述": "把电池放入电池槽",
        "采集设备": "乐聚KUAVO",
        "采集模式": "双臂",
        "场景域分类": "工业制造",
        "任务步骤描述": "1. 抓取电池 <Pick（拿起）><8s>\n2. 放入电池槽 <Place（放置）><8s>",
        "目标次数": 60,
        "任务级别": "简易",
        "任务步骤数量": 2,
    }


class GenerateExportFlowTest(unittest.TestCase):
    def test_generate_returns_editable_rows_without_export(self):
        original_call_qwen = app.call_qwen
        original_write_xlsx = app.write_xlsx
        original_key = os.environ.get("DASHSCOPE_API_KEY")

        def fake_call_qwen(*args, **kwargs):
            return [sample_task()]

        def fail_write_xlsx(*args, **kwargs):
            raise AssertionError("generate should not write xlsx")

        app.call_qwen = fake_call_qwen
        app.write_xlsx = fail_write_xlsx
        os.environ["DASHSCOPE_API_KEY"] = "test-key"
        try:
            response = app.generation_response(
                {
                    "robots": [sample_robot()],
                    "taskIdeas": "电池入槽",
                    "taskPhase": "pretrain",
                    "generationTaskCount": 1,
                    "matchIdeaCount": True,
                }
            )
        finally:
            app.call_qwen = original_call_qwen
            app.write_xlsx = original_write_xlsx
            if original_key is None:
                os.environ.pop("DASHSCOPE_API_KEY", None)
            else:
                os.environ["DASHSCOPE_API_KEY"] = original_key

        self.assertNotIn("downloadUrl", response)
        self.assertEqual(response["rows"][0]["任务名称"], "预-电池入槽")
        self.assertEqual(response["summary"]["generated"], 1)

    def test_export_uses_edited_rows(self):
        captured = {}
        original_write_xlsx = app.write_xlsx

        def fake_write_xlsx(validations, robots):
            captured["validations"] = validations
            captured["robots"] = robots
            return Path("edited.xlsx")

        app.write_xlsx = fake_write_xlsx
        try:
            response = app.export_response(
                {
                    "robots": [sample_robot()],
                    "rows": [sample_task("预-编辑后的任务")],
                    "taskPhase": "pretrain",
                }
            )
        finally:
            app.write_xlsx = original_write_xlsx

        self.assertEqual(response["downloadUrl"], "/download/edited.xlsx")
        self.assertEqual(captured["validations"][0]["row"]["任务名称"], "预-编辑后的任务")
        self.assertEqual(captured["validations"][0]["status"], "accepted")


if __name__ == "__main__":
    unittest.main()
