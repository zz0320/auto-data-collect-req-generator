import XCTest
import ReqWorkshopCore

final class ReqWorkshopTests: XCTestCase {
	func testPhaseTargetTimesStayFixed() {
		XCTAssertEqual(TaskPhase.pretrain.targetTimes, 60)
		XCTAssertEqual(TaskPhase.posttrain.targetTimes, 600)
	}

	func testLocalValidationRejectsTasksOutsideRobotCapability() {
		let fixedSingleArmRobot = RobotProfile(
			brand: "傅利叶",
			model: "GR-2",
			endEffector: "夹爪",
			arms: .singleRight,
			mobile: false,
			wholeBody: false,
			notes: ""
		)
		let row = RequirementRow(
			taskName: "货架巡检并搬运纸箱",
			brief: "机器人从货架移动到分拣台并双手搬运纸箱",
			device: fixedSingleArmRobot.name,
			mode: ArmMode.singleRight.rawValue,
			category: "商超零售",
			steps: "1. 导航到货架前 <Navigate（导航）><8s>\n2. 双手抬起纸箱 <Lift（抬起）><5s>\n3. 搬运至分拣台 <Transport（搬运）><10s>",
			targetTimes: 999,
			machineParameters: fixedSingleArmRobot.summary,
			level: "L2",
			stepCount: 3
		)

		let result = GenerationEngine.validate(row: row, robots: [fixedSingleArmRobot], phase: .posttrain, existingRows: [])

		XCTAssertEqual(result.status, .rejected)
		XCTAssertEqual(result.row.targetTimes, 600)
		XCTAssertTrue(result.errors.contains { $0.contains("固定工位") })
	}
}
