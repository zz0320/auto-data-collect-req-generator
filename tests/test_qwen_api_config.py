import json
import os
import tempfile
import unittest
from pathlib import Path

from openpyxl import Workbook

import app


def make_workbook(path: Path) -> None:
    wb = Workbook()
    ws = wb.active
    ws.title = "默认表"
    ws.append(app.TASK_HEADERS)
    ws.append(
        [
            "",
            "",
            "",
            "",
            "",
            "",
            "历史任务",
            "历史需求",
            "乐聚KUAVO",
            "双臂",
            "工业制造",
            "1. 抓取工件 <Pick（拿起）><8s>\n2. 放置工件 <Place（放置）><8s>",
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


def sample_task():
    return {
        "任务名称": "预-配置测试任务",
        "任务简述": "把测试工件放到测试槽",
        "采集设备": "乐聚KUAVO",
        "采集模式": "双臂",
        "场景域分类": "工业制造",
        "任务步骤描述": "1. 拿起测试工件 <Pick（拿起）><8s>\n2. 放到测试槽 <Place（放置）><8s>",
        "目标次数": 60,
        "任务级别": "简易",
        "任务步骤数量": 2,
    }


class QwenApiConfigTest(unittest.TestCase):
    def test_user_qwen_config_is_saved_masked_and_preserves_active_workbook(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            default_wb = tmp / "default.xlsx"
            active_wb = tmp / "active.xlsx"
            make_workbook(default_wb)
            make_workbook(active_wb)
            user = {"id": "u_alice", "username": "alice", "role": "user", "disabled": False, "createdAt": ""}
            workspaces = app.UserWorkspaceManager(tmp / "user_data", default_wb, tmp / "outputs")
            workspaces.set_active_workbook(user, active_wb)

            public_config = workspaces.save_qwen_config(
                user,
                api_key="sk-test-secret-123456",
                model="qwen-plus",
                endpoint="https://example.test/qwen",
            )
            settings = json.loads(workspaces.settings_path(user).read_text(encoding="utf-8"))

            self.assertEqual(settings["activeSource"], str(active_wb))
            self.assertEqual(settings["qwen"]["apiKey"], "sk-test-secret-123456")
            self.assertEqual(workspaces.get_workspace(user).source, active_wb)
            self.assertTrue(public_config["configured"])
            self.assertEqual(public_config["source"], "user")
            self.assertEqual(public_config["model"], "qwen-plus")
            self.assertEqual(public_config["endpoint"], "https://example.test/qwen")
            self.assertNotIn("sk-test-secret-123456", json.dumps(public_config, ensure_ascii=False))

    def test_user_profile_avatar_is_saved_and_returned_without_overwriting_settings(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            default_wb = tmp / "default.xlsx"
            active_wb = tmp / "active.xlsx"
            make_workbook(default_wb)
            make_workbook(active_wb)
            user = {"id": "u_alice", "username": "alice", "role": "user", "disabled": False, "createdAt": ""}
            workspaces = app.UserWorkspaceManager(tmp / "user_data", default_wb, tmp / "outputs")
            workspaces.set_active_workbook(user, active_wb)
            workspaces.save_qwen_config(user, api_key="sk-test-secret", model="qwen-plus", endpoint="https://example.test/qwen")

            profile = workspaces.save_user_profile(user, avatar="engineer_girl")
            settings = json.loads(workspaces.settings_path(user).read_text(encoding="utf-8"))

            self.assertEqual(profile["avatar"], "engineer_girl")
            self.assertEqual(settings["activeSource"], str(active_wb))
            self.assertEqual(settings["qwen"]["model"], "qwen-plus")
            self.assertEqual(workspaces.user_profile(user)["avatar"], "engineer_girl")

    def test_generation_uses_saved_qwen_config_without_environment_key(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            default_wb = tmp / "default.xlsx"
            make_workbook(default_wb)
            user = {"id": "u_alice", "username": "alice", "role": "user", "disabled": False, "createdAt": ""}
            workspaces = app.UserWorkspaceManager(tmp / "user_data", default_wb, tmp / "outputs")
            workspaces.save_qwen_config(
                user,
                api_key="sk-user-config-key",
                model="qwen-plus",
                endpoint="https://example.test/qwen",
            )
            captured = {}
            original_call_qwen = app.call_qwen
            original_key = os.environ.get("DASHSCOPE_API_KEY")

            def fake_call_qwen(robots, ideas, task_count, task_phase, api_key, model, endpoint, *args, **kwargs):
                captured["api_key"] = api_key
                captured["model"] = model
                captured["endpoint"] = endpoint
                return [sample_task()]

            app.call_qwen = fake_call_qwen
            os.environ.pop("DASHSCOPE_API_KEY", None)
            try:
                response = app.generation_response(
                    {
                        "robots": [sample_robot()],
                        "taskIdeas": "配置测试任务",
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

        self.assertEqual(captured["api_key"], "sk-user-config-key")
        self.assertEqual(captured["model"], "qwen-plus")
        self.assertEqual(captured["endpoint"], "https://example.test/qwen")
        self.assertEqual(response["summary"]["accepted"], 1)

    def test_static_ui_exposes_separate_api_config_panel(self):
        html = (Path(__file__).resolve().parents[1] / "static" / "index.html").read_text(encoding="utf-8")

        self.assertIn("apiConfigBtn", html)
        self.assertIn("apiPanel", html)
        self.assertIn("DashScope API Key", html)
        self.assertIn("测试连接", html)

    def test_connection_step_uses_compact_api_status_layout(self):
        html = (Path(__file__).resolve().parents[1] / "static" / "index.html").read_text(encoding="utf-8")

        self.assertIn("connection-card", html)
        self.assertIn("connection-tools", html)
        self.assertIn('class="field wide-field"', html)

    def test_rag_workbook_picker_supports_drag_upload(self):
        root = Path(__file__).resolve().parents[1]
        html = (root / "static" / "index.html").read_text(encoding="utf-8")
        js = (root / "static" / "app.js").read_text(encoding="utf-8")

        self.assertIn("workbookDropzone", html)
        self.assertIn("拖拽 .xlsx", html)
        self.assertIn("handleWorkbookDrop", js)
        self.assertIn("uploadWorkbookFile", js)

    def test_static_ui_refreshes_runtime_state_after_rag_and_api_changes(self):
        root = Path(__file__).resolve().parents[1]
        js = (root / "static" / "app.js").read_text(encoding="utf-8")

        self.assertIn("async function refreshRuntimeState", js)
        self.assertRegex(js, r"async function uploadWorkbookFile[\s\S]+await refreshRuntimeState\(\);")
        self.assertRegex(js, r"async function handleSaveApiConfig[\s\S]+await refreshRuntimeState\(\);")
        self.assertRegex(js, r"async function handleTestApiConfig[\s\S]+await refreshRuntimeState\(\);")
        self.assertRegex(js, r"async function handleClearApiKey[\s\S]+await refreshRuntimeState\(\);")

    def test_task_idea_editor_has_visible_line_markers(self):
        root = Path(__file__).resolve().parents[1]
        html = (root / "static" / "index.html").read_text(encoding="utf-8")
        js = (root / "static" / "app.js").read_text(encoding="utf-8")
        css = (root / "static" / "styles.css").read_text(encoding="utf-8")

        self.assertIn("idea-editor", html)
        self.assertIn("taskIdeaGutter", html)
        self.assertIn("taskIdeaRows", html)
        self.assertIn("taskIdeaRows", js)
        self.assertIn("syncIdeaLineMarkers", js)
        self.assertIn("idea-line-gutter", css)
        self.assertIn("idea-line-rows", css)
        self.assertIn("idea-line-row", css)
        self.assertIn("idea-row-marker", css)

    def test_llm_calls_show_visual_progress(self):
        root = Path(__file__).resolve().parents[1]
        html = (root / "static" / "index.html").read_text(encoding="utf-8")
        js = (root / "static" / "app.js").read_text(encoding="utf-8")
        css = (root / "static" / "styles.css").read_text(encoding="utf-8")

        self.assertIn("ideaProgress", html)
        self.assertIn("generationProgress", html)
        self.assertIn("startLlmProgress", js)
        self.assertIn("completeLlmProgress", js)
        self.assertIn("llm-progress", css)
        self.assertIn("progress-step", css)

    def test_static_ui_exposes_avatar_picker_and_clear_capability_states(self):
        root = Path(__file__).resolve().parents[1]
        html = (root / "static" / "index.html").read_text(encoding="utf-8")
        js = (root / "static" / "app.js").read_text(encoding="utf-8")
        css = (root / "static" / "styles.css").read_text(encoding="utf-8")

        self.assertIn("avatarPanel", html)
        self.assertIn("avatarPickerBtn", html)
        self.assertIn("/assets/avatar-sheet.png", html)
        self.assertIn("capability-segment", html)
        self.assertIn("capability-options", html)
        self.assertIn("data-capability-on", html)
        self.assertIn("data-capability-off", html)
        self.assertNotIn(">不具备移动能力</span>", html)
        self.assertNotIn(">不具备全身能力</span>", html)
        self.assertIn("具备移动能力", js)
        self.assertIn("不具备移动能力", js)
        self.assertIn("具备全身能力", js)
        self.assertIn("不具备全身能力", js)
        self.assertNotIn('content: "当前：";', css)
        self.assertIn('content: "✓";', css)


if __name__ == "__main__":
    unittest.main()
