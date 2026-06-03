import unittest

import app


class RagRetrievalTest(unittest.TestCase):
    def test_retrieves_relevant_examples_for_idea_and_robot(self):
        docs = [
            {
                "任务名称": "电池放置_1号电池",
                "任务简述": "把两个电池放入电池槽",
                "采集设备": "乐聚KUAVO",
                "采集模式": "双臂",
                "场景域分类": "工业制造",
                "任务步骤描述": "1. 抓取电池 <Pick（拿起）><20s>\n2. 放入电池盒 <Place（放置）><40s>",
                "任务级别": "简易",
                "目标次数": 300,
                "任务步骤数量": 2,
            },
            {
                "任务名称": "餐具摆放",
                "任务简述": "把餐盘放到架子上",
                "采集设备": "星尘智能S1",
                "采集模式": "单臂_右",
                "场景域分类": "餐饮服务",
                "任务步骤描述": "1. 抓取餐盘 <Grasp（抓取）><8s>\n2. 放置餐盘 <Place（放置）><8s>",
                "任务级别": "简易",
                "目标次数": 500,
                "任务步骤数量": 2,
            },
        ]

        rag_docs = [app.build_rag_document(item, index) for index, item in enumerate(docs, start=1)]
        robots = [app.RobotProfile("乐聚", "KUAVO", "夹爪", "双臂", False, False, "")]

        examples = app.retrieve_rag_examples("电池入槽", robots, rag_docs, limit=1)

        self.assertEqual(examples[0]["任务名称"], "电池放置_1号电池")
        self.assertIn("Pick", examples[0]["动作标签"])
        self.assertLessEqual(len(examples[0]["任务步骤描述"]), 320)

    def test_qwen_prompt_includes_retrieved_stock_context(self):
        docs = [
            app.build_rag_document(
                {
                    "任务名称": "电池放置_1号电池",
                    "任务简述": "把两个电池放入电池槽",
                    "采集设备": "乐聚KUAVO",
                    "采集模式": "双臂",
                    "场景域分类": "工业制造",
                    "任务步骤描述": "1. 抓取电池 <Pick（拿起）><20s>\n2. 放入电池盒 <Place（放置）><40s>",
                    "任务级别": "简易",
                    "目标次数": 60,
                    "任务步骤数量": 2,
                },
                1,
            )
        ]
        robots = [app.RobotProfile("乐聚", "KUAVO", "夹爪", "双臂", False, False, "")]
        original = getattr(app, "RAG_DOCUMENTS", [])
        app.RAG_DOCUMENTS = docs
        try:
            _, user_prompt = app.qwen_prompt(robots, ["电池入槽"], 1, "pretrain")
        finally:
            app.RAG_DOCUMENTS = original

        self.assertIn("存量数据 RAG 检索上下文", user_prompt)
        self.assertIn("电池放置_1号电池", user_prompt)

    def test_idea_relevance_beats_same_robot_only_match(self):
        docs = [
            app.build_rag_document(
                {
                    "任务名称": "可抓取物体清理入篮",
                    "任务简述": "将桌面上所有可抓取物体统一收纳到篮子中",
                    "采集设备": "乐聚KUAVO",
                    "采集模式": "双臂",
                    "场景域分类": "通用抓取放置",
                    "任务步骤描述": "1. 抓取物体 <Grasp（抓取）><8s>\n2. 放入篮子 <Place（放置）><8s>",
                    "任务级别": "简易",
                    "目标次数": 60,
                    "任务步骤数量": 2,
                },
                1,
            ),
            app.build_rag_document(
                {
                    "任务名称": "电池放置_1号电池",
                    "任务简述": "把两个电池放入电池槽",
                    "采集设备": "乐聚KUAVO",
                    "采集模式": "双臂",
                    "场景域分类": "工业制造",
                    "任务步骤描述": "1. 抓取桌面第一节1号电池 <Pick（拿起）><20s>\n2. 放入电池盒第一槽 <Place（放置）><40s>",
                    "任务级别": "简易",
                    "目标次数": 60,
                    "任务步骤数量": 2,
                },
                2,
            ),
        ]
        robots = [app.RobotProfile("乐聚", "KUAVO", "夹爪", "双臂", False, False, "")]

        examples = app.retrieve_rag_examples("电池入槽", robots, docs, limit=1)

        self.assertEqual(examples[0]["任务名称"], "电池放置_1号电池")


if __name__ == "__main__":
    unittest.main()
