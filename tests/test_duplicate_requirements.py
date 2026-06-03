import os
import tempfile
import unittest
from pathlib import Path

from openpyxl import Workbook

import app


def make_workbook(path: Path, task_name: str = "电池入槽") -> None:
    wb = Workbook()
    ws = wb.active
    ws.title = "历史需求"
    ws.append(app.TASK_HEADERS)
    ws.append(
        [
            "",
            "",
            "",
            "",
            "",
            "",
            task_name,
            "把电池放入电池槽",
            "乐聚KUAVO",
            "双臂",
            "工业制造",
            "1. 抓取电池 <Pick（拿起）><8s>\n2. 放入电池槽 <Place（放置）><8s>",
            60,
            "",
            "",
            "简易",
            2,
        ]
    )
    wb.save(path)


def sample_robot():
    return {"brand": "乐聚", "model": "KUAVO", "endEffector": "夹爪", "arms": "双臂", "mobile": False, "wholeBody": False}


def sample_task(name: str = "预-电池入槽", brief: str = "把电池放入电池槽") -> dict:
    return {
        "任务名称": name,
        "任务简述": brief,
        "采集设备": "乐聚KUAVO",
        "采集模式": "双臂",
        "场景域分类": "工业制造",
        "任务步骤描述": "1. 抓取电池 <Pick（拿起）><8s>\n2. 放入电池槽 <Place（放置）><8s>",
        "目标次数": 60,
        "任务级别": "简易",
        "任务步骤数量": 2,
    }


class DuplicateRequirementsTest(unittest.TestCase):
    def test_generation_rejects_rows_that_duplicate_active_workbook(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            default_wb = tmp / "history.xlsx"
            make_workbook(default_wb, task_name="电池入槽")
            workspaces = app.UserWorkspaceManager(tmp / "user_data", default_wb, tmp / "outputs")
            user = {"id": "u_alice", "username": "alice", "role": "user", "disabled": False, "createdAt": ""}
            original_call_qwen = app.call_qwen
            original_key = os.environ.get("DASHSCOPE_API_KEY")

            def fake_call_qwen(*args, **kwargs):
                return [sample_task("预-电池入槽")]

            app.call_qwen = fake_call_qwen
            os.environ["DASHSCOPE_API_KEY"] = "test-key"
            try:
                response = app.generation_response(
                    {
                        "robots": [sample_robot()],
                        "taskIdeas": "电池入槽",
                        "taskPhase": "pretrain",
                        "generationTaskCount": 1,
                        "matchIdeaCount": True,
                    },
                    current_user=user,
                    workspace_manager=workspaces,
                )
            finally:
                app.call_qwen = original_call_qwen
                if original_key is None:
                    os.environ.pop("DASHSCOPE_API_KEY", None)
                else:
                    os.environ["DASHSCOPE_API_KEY"] = original_key

        self.assertEqual(response["summary"]["accepted"], 0)
        self.assertEqual(response["summary"]["rejected"], 1)
        self.assertTrue(any("存量需求重复" in error for error in response["items"][0]["errors"]))

    def test_generation_rejects_renamed_rows_that_reuse_historical_steps(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            default_wb = tmp / "history.xlsx"
            make_workbook(default_wb, task_name="电池入槽")
            workspaces = app.UserWorkspaceManager(tmp / "user_data", default_wb, tmp / "outputs")
            user = {"id": "u_alice", "username": "alice", "role": "user", "disabled": False, "createdAt": ""}
            original_call_qwen = app.call_qwen
            original_key = os.environ.get("DASHSCOPE_API_KEY")

            def fake_call_qwen(*args, **kwargs):
                return [sample_task("预-电池放置入槽", "将电池放进指定槽位")]

            app.call_qwen = fake_call_qwen
            os.environ["DASHSCOPE_API_KEY"] = "test-key"
            try:
                response = app.generation_response(
                    {
                        "robots": [sample_robot()],
                        "taskIdeas": "电池放置入槽",
                        "taskPhase": "pretrain",
                        "generationTaskCount": 1,
                        "matchIdeaCount": True,
                    },
                    current_user=user,
                    workspace_manager=workspaces,
                )
            finally:
                app.call_qwen = original_call_qwen
                if original_key is None:
                    os.environ.pop("DASHSCOPE_API_KEY", None)
                else:
                    os.environ["DASHSCOPE_API_KEY"] = original_key

        self.assertEqual(response["summary"]["accepted"], 0)
        self.assertEqual(response["summary"]["rejected"], 1)
        self.assertTrue(any("存量需求重复" in error for error in response["items"][0]["errors"]))

    def test_export_rejects_rows_that_duplicate_active_workbook(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            default_wb = tmp / "history.xlsx"
            make_workbook(default_wb, task_name="电池入槽")
            workspaces = app.UserWorkspaceManager(tmp / "user_data", default_wb, tmp / "outputs")
            user = {"id": "u_alice", "username": "alice", "role": "user", "disabled": False, "createdAt": ""}

            response = app.export_response(
                {"robots": [sample_robot()], "rows": [sample_task("预-电池入槽")], "taskPhase": "pretrain"},
                current_user=user,
                workspace_manager=workspaces,
            )

        self.assertEqual(response["summary"]["accepted"], 0)
        self.assertEqual(response["summary"]["rejected"], 1)
        self.assertTrue(any("存量需求重复" in error for error in response["items"][0]["errors"]))

    def test_validation_rejects_duplicates_inside_the_same_batch(self):
        robots = app.parse_robots([sample_robot()])

        validations = app.validate_tasks(
            [sample_task("预-杯子摆放"), sample_task("预-杯子摆放")],
            robots,
            "pretrain",
        )

        self.assertEqual(validations[0]["status"], "accepted")
        self.assertEqual(validations[1]["status"], "rejected")
        self.assertTrue(any("本次已生成需求重复" in error for error in validations[1]["errors"]))


if __name__ == "__main__":
    unittest.main()
