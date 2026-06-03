import os
import unittest

import app


def sample_robot():
    return {"brand": "乐聚", "model": "KUAVO", "endEffector": "夹爪", "arms": "双臂", "mobile": False, "wholeBody": False}


def rag_doc(name: str, brief: str, steps: str, device: str = "乐聚KUAVO") -> dict:
    return app.build_rag_document(
        {
            "任务名称": name,
            "任务简述": brief,
            "采集设备": device,
            "采集模式": "双臂",
            "场景域分类": "工业制造",
            "任务步骤描述": steps,
            "目标次数": 60,
            "任务级别": "简易",
            "任务步骤数量": 2,
        },
        1,
    )


class IdeaBrainstormTest(unittest.TestCase):
    def test_brainstorm_filters_ideas_that_already_exist_in_rag_documents(self):
        original_call_qwen_json = app.call_qwen_json
        original_docs = app.RAG_DOCUMENTS
        original_key = os.environ.get("DASHSCOPE_API_KEY")
        app.RAG_DOCUMENTS = [
            rag_doc(
                "桌面垃圾清理",
                "将桌面的垃圾夹到垃圾篮中",
                "1. 抓取纸团 <Grasp（抓取）><8s>\n2. 放入垃圾篮 <Place（放置）><8s>",
            ),
            rag_doc(
                "电池入槽",
                "把电池放入电池槽",
                "1. 抓取电池 <Pick（拿起）><8s>\n2. 放入电池槽 <Place（放置）><8s>",
            ),
        ]

        def fake_call_qwen_json(*args, **kwargs):
            return {
                "ideas": ["桌面垃圾清理", "遥控器电池盖扣合", "电池入槽"],
                "rationale": "按历史能力发散",
            }

        app.call_qwen_json = fake_call_qwen_json
        os.environ["DASHSCOPE_API_KEY"] = "test-key"
        try:
            response = app.brainstorm_ideas_response(
                {
                    "robots": [sample_robot()],
                    "taskPhase": "pretrain",
                    "generationTaskCount": 3,
                    "ideaCount": 3,
                }
            )
        finally:
            app.call_qwen_json = original_call_qwen_json
            app.RAG_DOCUMENTS = original_docs
            if original_key is None:
                os.environ.pop("DASHSCOPE_API_KEY", None)
            else:
                os.environ["DASHSCOPE_API_KEY"] = original_key

        self.assertEqual(response["ideas"], ["遥控器电池盖扣合"])
        self.assertEqual(response["filteredExistingIdeaCount"], 2)

    def test_brainstorm_prompt_includes_robot_capabilities_mined_from_rag_documents(self):
        original_call_qwen_json = app.call_qwen_json
        original_docs = app.RAG_DOCUMENTS
        original_key = os.environ.get("DASHSCOPE_API_KEY")
        captured = {}
        app.RAG_DOCUMENTS = [
            rag_doc(
                "螺丝拧紧",
                "将螺丝拧紧到工装上",
                "1. 抓取螺丝 <Grasp（抓取）><8s>\n2. 拧紧螺丝 <Screw（拧紧）><8s>",
            )
        ]

        def fake_call_qwen_json(system, user, *args, **kwargs):
            captured["user"] = user
            return {"ideas": ["小型旋钮对准旋紧"], "rationale": "参考历史动作能力"}

        app.call_qwen_json = fake_call_qwen_json
        os.environ["DASHSCOPE_API_KEY"] = "test-key"
        try:
            app.brainstorm_ideas_response(
                {
                    "robots": [sample_robot()],
                    "taskPhase": "pretrain",
                    "generationTaskCount": 1,
                    "ideaCount": 1,
                }
            )
        finally:
            app.call_qwen_json = original_call_qwen_json
            app.RAG_DOCUMENTS = original_docs
            if original_key is None:
                os.environ.pop("DASHSCOPE_API_KEY", None)
            else:
                os.environ["DASHSCOPE_API_KEY"] = original_key

        self.assertIn("存量文档提炼的机器人能力画像", captured["user"])
        self.assertIn("乐聚KUAVO", captured["user"])
        self.assertIn("Screw（拧紧）", captured["user"])
        self.assertIn("历史任务名样例", captured["user"])


if __name__ == "__main__":
    unittest.main()
