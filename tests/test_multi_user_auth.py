import tempfile
import unittest
from pathlib import Path

from openpyxl import Workbook

import app


def make_workbook(path: Path, sheet: str, device: str, task_name: str) -> None:
    wb = Workbook()
    ws = wb.active
    ws.title = sheet
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
            device,
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


class MultiUserAuthTest(unittest.TestCase):
    def route_json(self, method: str, path: str, body: dict | None = None, cookie: str = "") -> tuple[int, dict, dict]:
        handler = object.__new__(app.Handler)
        handler.path = path
        handler.headers = {"Cookie": cookie}
        result: dict[str, object] = {"status": 200, "payload": {}, "headers": {}}

        def send_json(payload: dict, status: int = 200, headers: dict | None = None) -> None:
            result["status"] = status
            result["payload"] = payload
            result["headers"] = headers or {}

        def send_error(status: int, *args, **kwargs) -> None:
            result["status"] = int(status)
            result["payload"] = {"ok": False, "error": str(status)}
            result["headers"] = {}

        handler.send_json = send_json
        handler.send_error = send_error
        handler.read_json_body = lambda: body or {}
        getattr(app.Handler, f"do_{method}")(handler)
        return result["status"], result["payload"], result["headers"]

    def cookie_from_headers(self, headers: dict) -> str:
        return str(headers["Set-Cookie"]).split(";", 1)[0]

    def test_admin_bootstrap_hashes_password_and_controls_user_management(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            auth = app.AuthStore(Path(tmpdir) / "users.json")
            admin = auth.bootstrap_admin("admin", "admin-secret")
            alice = auth.create_user(admin, "alice", "alice-secret")

            raw_store = (Path(tmpdir) / "users.json").read_text(encoding="utf-8")
            self.assertNotIn("admin-secret", raw_store)
            self.assertNotIn("alice-secret", raw_store)
            self.assertEqual(auth.authenticate("admin", "admin-secret")["role"], "admin")
            self.assertEqual(auth.authenticate("alice", "alice-secret")["username"], "alice")
            self.assertEqual([user["username"] for user in auth.list_users(admin)], ["admin", "alice"])
            with self.assertRaises(PermissionError):
                auth.create_user(alice, "bob", "bob-secret")
            with self.assertRaises(PermissionError):
                auth.list_users(alice)

    def test_users_have_isolated_active_workbooks_and_rag_indexes(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            default_wb = tmp / "default.xlsx"
            alice_wb = tmp / "alice.xlsx"
            bob_wb = tmp / "bob.xlsx"
            make_workbook(default_wb, "默认表", "默认机器人D1", "默认任务")
            make_workbook(alice_wb, "Alice表", "Alice机器人A1", "Alice任务")
            make_workbook(bob_wb, "Bob表", "Bob机器人B1", "Bob任务")

            auth = app.AuthStore(tmp / "users.json")
            admin = auth.bootstrap_admin("admin", "admin-secret")
            alice = auth.create_user(admin, "alice", "alice-secret")
            bob = auth.create_user(admin, "bob", "bob-secret")
            workspaces = app.UserWorkspaceManager(tmp / "user_data", default_wb)

            alice_summary = workspaces.set_active_workbook(alice, alice_wb)
            bob_summary = workspaces.get_workspace(bob).summary
            self.assertEqual(alice_summary["sheet"], "Alice表")
            self.assertEqual(bob_summary["sheet"], "默认表")
            self.assertEqual(workspaces.get_workspace(alice).rag_documents[0]["采集设备"], "Alice机器人A1")
            self.assertEqual(workspaces.get_workspace(bob).rag_documents[0]["采集设备"], "默认机器人D1")

            workspaces.set_active_workbook(bob, bob_wb)
            self.assertEqual(workspaces.get_workspace(alice).summary["sheet"], "Alice表")
            self.assertEqual(workspaces.get_workspace(bob).summary["sheet"], "Bob表")

    def test_export_download_paths_are_private_to_the_owner(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            default_wb = tmp / "default.xlsx"
            make_workbook(default_wb, "默认表", "默认机器人D1", "默认任务")
            auth = app.AuthStore(tmp / "users.json")
            admin = auth.bootstrap_admin("admin", "admin-secret")
            alice = auth.create_user(admin, "alice", "alice-secret")
            bob = auth.create_user(admin, "bob", "bob-secret")
            workspaces = app.UserWorkspaceManager(tmp / "user_data", default_wb)

            response = app.export_response(
                {"robots": [sample_robot()], "rows": [sample_task("预-Alice私有任务")], "taskPhase": "pretrain"},
                current_user=alice,
                workspace_manager=workspaces,
            )

            alice_file = workspaces.resolve_download(alice, response["downloadName"])
            self.assertTrue(alice_file.exists())
            self.assertIn(alice["id"], alice_file.parts)
            with self.assertRaises(PermissionError):
                workspaces.resolve_download(bob, response["downloadName"])

    def test_http_routes_require_login_and_admin_role(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            default_wb = tmp / "default.xlsx"
            make_workbook(default_wb, "默认表", "默认机器人D1", "默认任务")

            original_auth_store = app.AUTH_STORE
            original_workspace_manager = app.WORKSPACE_MANAGER
            original_sessions = app.SESSION_STORE
            app.AUTH_STORE = app.AuthStore(tmp / "accounts.json")
            app.WORKSPACE_MANAGER = app.UserWorkspaceManager(tmp / "user_data", default_wb)
            app.SESSION_STORE = {}
            app.AUTH_STORE.bootstrap_admin("admin", "admin-secret")
            try:
                status, payload, _ = self.route_json("GET", "/api/schema")
                self.assertEqual(status, 401)
                self.assertFalse(payload["ok"])

                status, payload, headers = self.route_json(
                    "POST",
                    "/api/auth/login",
                    {"username": "admin", "password": "admin-secret"},
                )
                self.assertEqual(status, 200)
                self.assertEqual(payload["user"]["role"], "admin")
                admin_cookie = self.cookie_from_headers(headers)

                status, payload, _ = self.route_json(
                    "POST",
                    "/api/admin/users",
                    {"username": "alice", "password": "alice-secret", "role": "user"},
                    admin_cookie,
                )
                self.assertEqual(status, 200)
                self.assertEqual(payload["user"]["username"], "alice")

                status, payload, headers = self.route_json(
                    "POST",
                    "/api/auth/login",
                    {"username": "alice", "password": "alice-secret"},
                )
                self.assertEqual(status, 200)
                alice_cookie = self.cookie_from_headers(headers)

                status, payload, _ = self.route_json("GET", "/api/admin/users", cookie=alice_cookie)
                self.assertEqual(status, 403)
                self.assertFalse(payload["ok"])

                status, payload, _ = self.route_json("GET", "/api/schema", cookie=alice_cookie)
                self.assertEqual(status, 200)
                self.assertEqual(payload["sheet"], "默认表")
            finally:
                app.AUTH_STORE = original_auth_store
                app.WORKSPACE_MANAGER = original_workspace_manager
                app.SESSION_STORE = original_sessions


if __name__ == "__main__":
    unittest.main()
