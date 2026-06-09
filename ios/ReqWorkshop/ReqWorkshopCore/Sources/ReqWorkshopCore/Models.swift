import Foundation

public enum TaskPhase: String, CaseIterable, Codable, Sendable {
    case pretrain
    case posttrain

    public var label: String {
        switch self {
        case .pretrain: "预训练"
        case .posttrain: "后训练"
        }
    }

    public var targetTimes: Int {
        switch self {
        case .pretrain: 60
        case .posttrain: 600
        }
    }

    public var style: String {
        switch self {
        case .pretrain:
            "基础能力覆盖，优先生成短步骤、单技能或低组合度任务，覆盖抓取、放置、对准、释放、简单转移等底层能力。"
        case .posttrain:
            "指令跟随和场景泛化，允许生成更长步骤、多对象、多约束和多场景任务，但仍必须受机器人真实能力限制。"
        }
    }
}

public enum ArmMode: String, CaseIterable, Codable, Sendable {
    case dual = "双臂"
    case singleLeft = "单臂_左"
    case singleRight = "单臂_右"
}

public struct RobotProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var brand: String
    public var model: String
    public var endEffector: String
    public var arms: ArmMode
    public var mobile: Bool
    public var wholeBody: Bool
    public var notes: String

    public init(
        id: UUID = UUID(),
        brand: String,
        model: String,
        endEffector: String,
        arms: ArmMode,
        mobile: Bool,
        wholeBody: Bool,
        notes: String
    ) {
        self.id = id
        self.brand = brand
        self.model = model
        self.endEffector = endEffector
        self.arms = arms
        self.mobile = mobile
        self.wholeBody = wholeBody
        self.notes = notes
    }

    public var name: String {
        let brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if !brand.isEmpty, !model.isEmpty { return model.hasPrefix(brand) ? model : brand + model }
        return brand.isEmpty ? (model.isEmpty ? "未命名机器人" : model) : brand
    }

    public var isDualArm: Bool { arms == .dual }
    public var isDexterous: Bool { endEffector.contains("灵巧") }
    public var hasManipulator: Bool { !endEffector.isEmpty && endEffector != "无" }

    public var summary: String {
        [
            name,
            arms.rawValue,
            "末端执行器：\(endEffector.isEmpty ? "未填写" : endEffector)",
            mobile ? "具备移动能力" : "固定工位",
            wholeBody ? "具备全身能力" : "不假设全身能力",
            "备注：\(notes.isEmpty ? "无" : notes)",
        ].joined(separator: "；")
    }
}

public struct RequirementRow: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var autoNumber: String
    public var taskID: String
    public var durationHours: String
    public var submitTime: String
    public var submitter: String
    public var fillDate: String
    public var taskName: String
    public var brief: String
    public var device: String
    public var mode: String
    public var category: String
    public var steps: String
    public var targetTimes: Int
    public var owner: String
    public var machineParameters: String
    public var level: String
    public var stepCount: Int

    public init(
        id: UUID = UUID(),
        autoNumber: String = "",
        taskID: String = "",
        durationHours: String = "",
        submitTime: String = "",
        submitter: String = "AI需求生成器",
        fillDate: String = "",
        taskName: String,
        brief: String,
        device: String,
        mode: String,
        category: String,
        steps: String,
        targetTimes: Int,
        owner: String = "",
        machineParameters: String,
        level: String,
        stepCount: Int
    ) {
        self.id = id
        self.autoNumber = autoNumber
        self.taskID = taskID
        self.durationHours = durationHours
        self.submitTime = submitTime
        self.submitter = submitter
        self.fillDate = fillDate
        self.taskName = taskName
        self.brief = brief
        self.device = device
        self.mode = mode
        self.category = category
        self.steps = steps
        self.targetTimes = targetTimes
        self.owner = owner
        self.machineParameters = machineParameters
        self.level = level
        self.stepCount = stepCount
    }

    public subscript(header: String) -> String {
        switch header {
        case "自动编号": autoNumber
        case "任务ID": taskID
        case "采集时长（小时）": durationHours
        case "提交时间": submitTime
        case "提交人": submitter
        case "填写日期": fillDate
        case "任务名称": taskName
        case "任务简述": brief
        case "采集设备": device
        case "采集模式": mode
        case "场景域分类": category
        case "任务步骤描述": steps
        case "目标次数": String(targetTimes)
        case "数采负责人": owner
        case "机器及环境参数": machineParameters
        case "任务级别": level
        case "任务步骤数量": String(stepCount)
        default: ""
        }
    }
}

public enum ValidationStatus: String, Codable, Sendable {
    case accepted
    case rejected
}

public struct ValidationResult: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var status: ValidationStatus
    public var row: RequirementRow
    public var errors: [String]
    public var warnings: [String]
    public var robotName: String

    public init(
        id: UUID = UUID(),
        status: ValidationStatus,
        row: RequirementRow,
        errors: [String],
        warnings: [String],
        robotName: String
    ) {
        self.id = id
        self.status = status
        self.row = row
        self.errors = errors
        self.warnings = warnings
        self.robotName = robotName
    }
}

public enum ReqConstants {
    public static let taskHeaders = [
        "自动编号",
        "任务ID",
        "采集时长（小时）",
        "提交时间",
        "提交人",
        "填写日期",
        "任务名称",
        "任务简述",
        "采集设备",
        "采集模式",
        "场景域分类",
        "任务步骤描述",
        "目标次数",
        "数采负责人",
        "机器及环境参数",
        "任务级别",
        "任务步骤数量",
    ]

    public static let canonicalActions: [String: String] = [
        "Grasp": "Grasp（抓取）",
        "Pick": "Pick（拿起）",
        "Place": "Place（放置）",
        "Release": "Release（释放）",
        "Transfer": "Transfer（转移）",
        "Alignment": "Alignment（对准）",
        "Move": "Move（移动）",
        "Navigate": "Navigate（导航）",
        "Carry": "Carry（携带）",
        "Transport": "Transport（搬运）",
        "Open": "Open（打开）",
        "Close": "Close（关闭）",
        "Pull": "Pull（拉）",
        "Push": "Push（推）",
        "Press": "Press（按压）",
        "Lift": "Lift（抬起）",
        "Lower": "Lower（放下）",
        "Fold": "Fold（折叠）",
        "Unfold": "Unfold（展开）",
        "Straighten": "Straighten（整理）",
        "Flip": "Flip（翻转）",
        "HandOver": "HandOver（传递）",
        "Hold": "Hold（握住）",
        "Pour": "Pour（倒）",
        "Scoop": "Scoop（舀）",
        "Insert": "Insert（插入）",
        "Rotate": "Rotate（旋转）",
        "Pack": "Pack（打包）",
        "Stack": "Stack（堆叠）",
        "Wipe": "Wipe（擦拭）",
        "Touch": "Touch（触摸）",
        "Several Times": "Several Times（多次重复抓取放置）",
        "Crouch": "Crouch（蹲下）",
        "Stretch": "Stretch（伸展）",
        "Plug": "Plug（插插头）",
        "Unplug": "Unplug（拔插头）",
        "Screw": "Screw（拧紧）",
        "Unscrew": "Unscrew（拧松）",
        "Zip": "Zip（拉上）",
        "Unzip": "Unzip（拉开）",
    ]

    public static let mobileActions: Set<String> = ["Move", "Navigate", "Carry", "Transport"]
    public static let bimanualActions: Set<String> = ["Fold", "Unfold", "HandOver"]
    public static let wholeBodyActions: Set<String> = ["Crouch", "Stretch"]
    public static let fineActions: Set<String> = ["Screw", "Unscrew", "Zip", "Unzip", "Plug", "Unplug", "Twist", "Insert"]
    public static let suctionForbiddenActions = bimanualActions.union(fineActions).union(["Pull", "Scoop", "Pour", "Wipe", "Hold"])
}

public struct CapabilitySummary: Codable, Equatable, Sendable {
    public var name: String
    public var summary: String
    public var allowedActions: [String]
    public var blocked: [String]
    public var cautions: [String]
}
