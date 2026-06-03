import tempfile
import unittest
from pathlib import Path

from openpyxl import Workbook

import app


class WorkbookSourceSwitchTest(unittest.TestCase):
    def test_active_workbook_switch_rebuilds_schema_and_rag(self):
        original_source = app.CURRENT_SOURCE_XLSX
        original_summary = app.WORKBOOK_SUMMARY
        original_docs = app.RAG_DOCUMENTS

        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "custom-rag.xlsx"
            wb = Workbook()
            ws = wb.active
            ws.title = "自选RAG"
            ws.append(app.TASK_HEADERS)
            ws.append(
                [
                    "",
                    "",
                    "",
                    "",
                    "",
                    "",
                    "电池测试",
                    "把电池放入电池槽",
                    "测试机器人T1",
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

            summary = app.set_active_workbook(path)

            self.assertEqual(app.CURRENT_SOURCE_XLSX, path)
            self.assertEqual(summary["sheet"], "自选RAG")
            self.assertEqual(summary["ragDocumentCount"], 1)
            self.assertEqual(len(app.RAG_DOCUMENTS), 1)
            self.assertEqual(app.RAG_DOCUMENTS[0]["采集设备"], "测试机器人T1")

        app.CURRENT_SOURCE_XLSX = original_source
        app.WORKBOOK_SUMMARY = original_summary
        app.RAG_DOCUMENTS = original_docs


if __name__ == "__main__":
    unittest.main()
