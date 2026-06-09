import CoreXLSX
import Foundation
import XCTest
@testable import ReqWorkshopCore

final class RAGAndExportTests: XCTestCase {
    func testRAGRetrievalPrioritizesIdeaAndRobotMatches() throws {
        let robot = RobotProfile.fixture()
        let docs = [
            RAGDocument.fixture(taskName: "餐具摆放", brief: "摆放餐盘", device: "其他机器人X1"),
            RAGDocument.fixture(taskName: "遥控器电池盖扣合", brief: "将遥控器电池盖对准并按压扣合", device: "乐聚KUAVO"),
        ]
        let store = RAGStore(documents: docs)

        let matches = store.retrieveExamples(idea: "遥控器电池盖扣合", robots: [robot], limit: 1)

        XCTAssertEqual(matches.first?.taskName, "遥控器电池盖扣合")
    }

    func testExportWritesThreeReadableXLSXSheets() throws {
        let robot = RobotProfile.fixture()
        let row = RequirementRow.fixture(taskName: "预-遥控器电池盖扣合", robot: robot)
        let validation = ValidationResult(status: .accepted, row: row, errors: [], warnings: [], robotName: robot.name)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".xlsx")

        try XLSXExporter().export(validations: [validation], robots: [robot], to: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let file = try XCTUnwrap(XLSXFile(filepath: url.path))
        let workbook = try file.parseWorkbooks().first
        let sheets = try XCTUnwrap(workbook).sheets.items.map(\.name)
        XCTAssertEqual(sheets, ["生成结果", "校验日志", "机器人配置"])
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

private extension RequirementRow {
    static func fixture(taskName: String, robot: RobotProfile) -> RequirementRow {
        RequirementRow(
            taskName: taskName,
            brief: "将遥控器电池盖对准并扣合",
            device: robot.name,
            mode: "双臂",
            category: "工业制造",
            steps: "1. 拿起电池盖 <Pick（拿起）><8s>\n2. 对准并扣合 <Press（按压）><8s>",
            targetTimes: 60,
            machineParameters: robot.summary,
            level: "简易",
            stepCount: 2
        )
    }
}
