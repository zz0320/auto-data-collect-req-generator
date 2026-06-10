import CoreXLSX
import Foundation
import XCTest
import ZIPFoundation
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

    func testRAGDocumentsTolerateDuplicateAndBlankHeaders() throws {
        let table = [
            ["任务名称", "", "任务步骤描述", "任务名称", "采集设备", "采集模式", "场景域分类", "目标次数", "任务级别", "任务步骤数量"],
            ["桌面垃圾清理", "", "1. 抓取垃圾 <Grasp（抓取）><8s>", "重复任务名", "乐聚KUAVO", "双臂", "家居家政", "60", "简易", "1"],
        ]

        let docs = RAGStore.documents(from: table)

        XCTAssertEqual(docs.count, 1)
        XCTAssertEqual(docs[0].taskName, "桌面垃圾清理")
        XCTAssertEqual(docs[0].device, "乐聚KUAVO")
    }

    func testRAGStoreInfersRobotProfilesFromImportedRows() throws {
        let table = [
            ["任务名称", "任务步骤描述", "采集设备", "采集模式", "场景域分类", "目标次数", "机器及环境参数", "任务级别", "任务步骤数量"],
            [
                "货架巡检取放",
                "1. 导航到货架 <Navigate（导航）><8s>\n2. 抓取商品 <Grasp（抓取）><8s>",
                "傅利叶GR-2",
                "双臂",
                "商超药店",
                "60",
                "末端执行器：灵巧手；具备移动能力；具备全身能力",
                "中等",
                "2",
            ],
        ]
        let store = RAGStore(documents: RAGStore.documents(from: table))

        let profile = try XCTUnwrap(store.inferredRobotProfiles().first)

        XCTAssertEqual(profile.brand, "傅利叶")
        XCTAssertEqual(profile.model, "GR-2")
        XCTAssertEqual(profile.endEffector, "灵巧手")
        XCTAssertEqual(profile.arms, .dual)
        XCTAssertTrue(profile.mobile)
        XCTAssertTrue(profile.wholeBody)
        XCTAssertTrue(profile.notes.contains("RAG 1 条"))
    }

    func testRAGStoreBuildsSelectableRobotPresetsWithMetadata() throws {
        let table = [
            ["任务名称", "任务步骤描述", "采集设备", "采集模式", "场景域分类", "目标次数", "机器及环境参数", "任务级别", "任务步骤数量"],
            [
                "货架巡检取放",
                "1. 导航到货架 <Navigate（导航）><8s>\n2. 抓取商品 <Grasp（抓取）><8s>",
                "傅利叶GR-2",
                "双臂",
                "商超药店",
                "60",
                "末端执行器：灵巧手；具备移动能力",
                "中等",
                "2",
            ],
            [
                "商品递送",
                "1. 拿起商品 <Pick（拿起）><8s>\n2. 递送商品 <HandOver（传递）><8s>",
                "傅利叶GR-2",
                "双臂",
                "商超药店",
                "60",
                "末端执行器：灵巧手；具备移动能力",
                "中等",
                "2",
            ],
        ]
        let store = RAGStore(documents: RAGStore.documents(from: table))

        let preset = try XCTUnwrap(store.inferredRobotPresets().first)

        XCTAssertEqual(preset.name, "傅利叶GR-2")
        XCTAssertEqual(preset.count, 2)
        XCTAssertEqual(preset.profile.endEffector, "灵巧手")
        XCTAssertTrue(preset.profile.mobile)
        XCTAssertEqual(preset.categories, ["商超药店"])
        XCTAssertTrue(preset.actions.contains("Navigate（导航）"))
        XCTAssertTrue(preset.actions.contains("HandOver（传递）"))
        XCTAssertEqual(preset.modes, ["双臂"])
    }

    func testRAGStoreTrustsExplicitCapabilityTextWhenInferringRobotProfiles() throws {
        let table = [
            ["任务名称", "任务步骤描述", "采集设备", "采集模式", "场景域分类", "目标次数", "机器及环境参数", "任务级别", "任务步骤数量"],
            [
                "固定工位桌面取放",
                "1. 移动到目标点 <Move（移动）><8s>\n2. 吸取包装袋 <Pick（拿起）><8s>",
                "测试机器人T1",
                "单臂_右",
                "通用抓取放置",
                "60",
                "末端执行器：吸盘；固定工位；不具备移动能力；不具备全身能力",
                "简易",
                "2",
            ],
        ]
        let store = RAGStore(documents: RAGStore.documents(from: table))

        let profile = try XCTUnwrap(store.inferredRobotProfiles().first)

        XCTAssertEqual(profile.endEffector, "吸盘")
        XCTAssertEqual(profile.arms, .singleRight)
        XCTAssertFalse(profile.mobile)
        XCTAssertFalse(profile.wholeBody)
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

    func testExportMatchesWebWorkbookContractAndFormatting() throws {
        let robot = RobotProfile.fixture()
        let acceptedRow = RequirementRow.fixture(taskName: "预-遥控器电池盖扣合", robot: robot)
        let rejectedRow = RequirementRow.fixture(taskName: "预-货架往返搬运", robot: robot)
        let accepted = ValidationResult(status: .accepted, row: acceptedRow, errors: [], warnings: [], robotName: robot.name)
        let rejected = ValidationResult(
            status: .rejected,
            row: rejectedRow,
            errors: ["任务包含移动/导航/搬运动作，但机器人未配置移动能力"],
            warnings: ["拒绝项不写入生成结果"],
            robotName: robot.name
        )
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".xlsx")

        try XLSXExporter().export(validations: [accepted, rejected], robots: [robot], to: url)

        let resultXML = try exportedText("xl/worksheets/sheet1.xml", from: url)
        let logXML = try exportedText("xl/worksheets/sheet2.xml", from: url)
        let robotXML = try exportedText("xl/worksheets/sheet3.xml", from: url)
        let stylesXML = try exportedText("xl/styles.xml", from: url)

        XCTAssertTrue(resultXML.contains("预-遥控器电池盖扣合"))
        XCTAssertFalse(resultXML.contains("预-货架往返搬运"))
        XCTAssertTrue(logXML.contains("rejected"))
        XCTAssertTrue(logXML.contains("任务包含移动/导航/搬运动作"))
        XCTAssertTrue(robotXML.contains("机器人"))
        XCTAssertTrue(robotXML.contains("乐聚KUAVO"))

        for xml in [resultXML, logXML, robotXML] {
            XCTAssertTrue(xml.contains(#"<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>"#))
            XCTAssertTrue(xml.contains("<cols>"))
            XCTAssertTrue(xml.contains(#"s="1""#))
            XCTAssertTrue(xml.contains(#"s="2""#))
        }
        XCTAssertTrue(stylesXML.contains("<fonts"))
        XCTAssertTrue(stylesXML.contains("<fills"))
        XCTAssertTrue(stylesXML.contains("<cellXfs"))
    }

    private func exportedText(_ entryPath: String, from url: URL) throws -> String {
        let archive = try Archive(url: url, accessMode: .read)
        let entry = try XCTUnwrap(archive[entryPath])
        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return String(decoding: data, as: UTF8.self)
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
