import XCTest
@testable import ReqWorkshopCore

final class GenerationEngineTests: XCTestCase {
    func testTargetTimesAreFixedByPhase() throws {
        XCTAssertEqual(TaskPhase.pretrain.targetTimes, 60)
        XCTAssertEqual(TaskPhase.posttrain.targetTimes, 600)
    }

    func testValidationRejectsRobotCapabilityMismatchesAndKeepsFixedTargetTimes() throws {
        let robot = RobotProfile(
            brand: "傅利叶",
            model: "GR-2",
            endEffector: "夹爪",
            arms: .singleRight,
            mobile: false,
            wholeBody: false,
            notes: ""
        )
        let row = RequirementRow(
            taskName: "后-跨房间双手递送",
            brief: "移动到货架后双手递送物品",
            device: "傅利叶GR-2",
            mode: "双臂",
            category: "商超药店",
            steps: "1. 导航到货架 <Move（移动）><8s>\n2. 双手递送商品 <HandOver（传递）><8s>",
            targetTimes: 1,
            machineParameters: robot.summary,
            level: "复杂",
            stepCount: 2
        )

        let result = GenerationEngine.validate(row: row, robots: [robot], phase: .posttrain, existingRows: [])

        XCTAssertEqual(result.status, .rejected)
        XCTAssertTrue(result.errors.contains { $0.contains("移动") })
        XCTAssertTrue(result.errors.contains { $0.contains("双臂") })
        XCTAssertEqual(result.row.targetTimes, 600)
    }

    func testBrainstormFiltersExistingIdeasFromRAGDocuments() async throws {
        let robot = RobotProfile.fixture()
        let docs = [
            RAGDocument.fixture(taskName: "桌面垃圾清理", brief: "将桌面的垃圾夹到垃圾篮中"),
            RAGDocument.fixture(taskName: "电池入槽", brief: "把电池放入电池槽"),
        ]
        let client = StubLLMClient(json: [
            "ideas": ["桌面垃圾清理", "遥控器电池盖扣合", "电池入槽"],
            "rationale": "参考历史能力发散",
        ])
        let engine = GenerationEngine(llmClient: client)

        let result = try await engine.brainstormIdeas(
            robots: [robot],
            phase: .pretrain,
            ideaCount: 3,
            ragStore: RAGStore(documents: docs)
        )

        XCTAssertEqual(result.ideas, ["遥控器电池盖扣合"])
        XCTAssertEqual(result.filteredExistingIdeaCount, 2)
        XCTAssertTrue(client.lastUserPrompt.contains("存量文档提炼的机器人能力画像"))
    }

    func testGenerateRequirementsParsesQwenRowsAndAppliesLocalValidation() async throws {
        let robot = RobotProfile.fixture()
        let client = StubLLMClient(json: [
            "tasks": [
                [
                    "任务名称": "预-遥控器电池盖扣合",
                    "任务简述": "将遥控器电池盖对准并按压扣合",
                    "采集设备": "乐聚KUAVO",
                    "采集模式": "双臂",
                    "场景域分类": "工业制造",
                    "任务步骤描述": "1. 拿起电池盖 <Pick（拿起）><8s>\n2. 对准并扣合 <Press（按压）><8s>",
                    "目标次数": 999,
                    "机器及环境参数": robot.summary,
                    "任务级别": "简易",
                    "任务步骤数量": 2,
                ],
            ],
        ])
        let engine = GenerationEngine(llmClient: client)

        let validations = try await engine.generateRequirements(
            robots: [robot],
            ideas: ["遥控器电池盖扣合"],
            phase: .pretrain,
            ragStore: RAGStore(),
            owner: ""
        )

        XCTAssertEqual(validations.count, 1)
        XCTAssertEqual(validations[0].status, .accepted)
        XCTAssertEqual(validations[0].row.targetTimes, 60)
        XCTAssertTrue(client.lastUserPrompt.contains("新的任务 idea"))
    }
}

private final class StubLLMClient: LLMClient {
    var json: [String: Any]
    private(set) var lastUserPrompt = ""

    init(json: [String: Any]) {
        self.json = json
    }

    func generateJSON(system: String, user: String, timeoutSeconds: TimeInterval) async throws -> [String: Any] {
        lastUserPrompt = user
        return json
    }
}

private extension RobotProfile {
    static func fixture() -> RobotProfile {
        RobotProfile(
            brand: "乐聚",
            model: "KUAVO",
            endEffector: "夹爪",
            arms: .dual,
            mobile: false,
            wholeBody: false,
            notes: ""
        )
    }
}
