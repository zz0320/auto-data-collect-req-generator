import Foundation

public protocol LLMClient {
    func generateJSON(system: String, user: String, timeoutSeconds: TimeInterval) async throws -> [String: Any]
}

public struct BrainstormResult: Equatable, Sendable {
    public var ideas: [String]
    public var rationale: String
    public var filteredExistingIdeaCount: Int
    public var filteredExistingIdeas: [String]
}

public struct GenerationEngine {
    public var llmClient: LLMClient

    public init(llmClient: LLMClient) {
        self.llmClient = llmClient
    }

    public static func deriveCapabilities(_ robot: RobotProfile) -> CapabilitySummary {
        var allowed: Set<String> = [
            "Grasp", "Pick", "Place", "Release", "Transfer", "Alignment", "Press", "Push", "Pull", "Open", "Close",
            "Lift", "Lower", "Flip", "Rotate", "Touch", "Several Times",
        ]
        var blocked: [String] = []
        var cautions: [String] = []

        if !robot.hasManipulator {
            allowed.removeAll()
            blocked.append("未配置可操作末端执行器，不能生成抓取/放置类数据采集任务")
        }
        if robot.mobile {
            allowed.formUnion(ReqConstants.mobileActions)
        } else {
            blocked.append("未配置移动能力，禁止生成跨位置移动、货架往返、巡检搬运任务")
        }
        if robot.isDualArm {
            allowed.formUnion(["HandOver", "Hold", "Fold", "Unfold", "Straighten", "Pack", "Stack", "Wipe"])
        } else {
            blocked.append("单臂配置不能生成需要双手协作的折叠、双手传递、双手保持任务")
        }
        if robot.wholeBody {
            allowed.formUnion(ReqConstants.wholeBodyActions)
        } else {
            cautions.append("未配置全身能力时，只生成桌面或工位高度任务")
        }
        if robot.isDexterous {
            allowed.formUnion(ReqConstants.fineActions.union(["Scoop", "Pour", "Wipe"]))
        } else if robot.endEffector.contains("吸盘") {
            allowed.subtract(ReqConstants.suctionForbiddenActions)
            cautions.append("吸盘优先生成扁平、硬质、表面可吸附物体任务")
        } else {
            cautions.append("非灵巧手配置不生成拧螺丝、拉拉链、插拔插头等精细任务")
        }

        return CapabilitySummary(
            name: robot.name,
            summary: robot.summary,
            allowedActions: allowed.compactMap { ReqConstants.canonicalActions[$0] }.sorted(),
            blocked: blocked,
            cautions: cautions
        )
    }

    public func brainstormIdeas(
        robots: [RobotProfile],
        phase: TaskPhase,
        ideaCount: Int,
        ragStore: RAGStore
    ) async throws -> BrainstormResult {
        guard !robots.isEmpty else { throw GenerationError.validation("请先选择或新增至少一台机器人，再自动脑洞 idea") }
        let clampedCount = max(1, min(ideaCount, 200))
        let candidateCount = min(200, max(clampedCount, clampedCount + min(clampedCount, 20)))
        let robotText = robots.map {
            "- \($0.summary)\n  允许动作：\(Self.deriveCapabilities($0).allowedActions.joined(separator: ", "))"
        }.joined(separator: "\n")
        let capabilityContext = try prettyJSONString(ragStore.capabilityContext(for: robots))
        let ragExamples = ragStore.retrieveExamples(
            idea: "\(phase.label) \(robots.map(\.name).joined(separator: " ")) 通用抓取放置 家居家政 商超药店 餐饮服务 工业制造",
            robots: robots,
            limit: 16
        )
        let ragContext = try prettyJSONString(ragExamples.map { doc in
            [
                "任务名称": doc.taskName,
                "任务简述": doc.brief,
                "采集设备": doc.device,
                "采集模式": doc.mode,
                "场景域分类": doc.category,
                "动作标签": doc.actions,
                "任务步骤描述": String(doc.steps.prefix(320)),
            ] as [String: Any]
        })

        let system = "你是机器人数据采集需求的任务 idea 策划器。你只输出 JSON。必须结合存量数据分布和机器人真实能力提出新 idea；不确定的能力不要假设。"
        let user = """
        请自动脑洞一批新的机器人数据采集 task idea，供后续生成数据需求表使用。

        任务阶段：\(phase.label)
        阶段策略：\(phase.style)
        固定目标次数：\(phase.targetTimes) 次
        最终需要保留 idea 数量：\(clampedCount)
        请输出候选 idea 数量：\(candidateCount)（本地会按历史任务去重后截取前 \(clampedCount) 条）

        机器人配置：
        \(robotText)

        存量文档提炼的机器人能力画像（先根据这里判断机器人真实擅长的模式、场景和动作；历史任务名样例只用于避重，禁止复用或只改少量词）：
        \(capabilityContext)

        存量数据 RAG 检索上下文（用于发散 idea，参考既有任务的场景、对象、动作标签和任务颗粒度，但不要照抄任务名）：
        \(ragContext)

        要求：
        1. 每个 idea 是短句，不写完整步骤，不写编号。
        2. idea 必须符合至少一台机器人的实际能力；固定工位不要提出跨房间/巡检/货架往返 idea。
        3. 预训练 idea 偏底层技能覆盖和对象泛化；后训练 idea 偏复杂约束、多对象、多场景指令。
        4. 先从能力画像提炼该机器人已验证过的动作能力，再发散新对象、新约束、新评价目标。
        5. 不要提出与历史任务名样例、RAG 示例同名或内容近似重复的 idea。

        输出 JSON schema：
        {"ideas":["idea 1","idea 2"],"rationale":"一句话说明这些 idea 如何参考了存量数据"}
        """
        let parsed = try await llmClient.generateJSON(system: system, user: user, timeoutSeconds: 180)
        guard let rawIdeas = parsed["ideas"] as? [Any] else {
            throw GenerationError.validation("Qwen idea 响应缺少 ideas 数组")
        }
        let cleaned = cleanBrainstormIdeas(rawIdeas, ragStore: ragStore, limit: clampedCount)
        if cleaned.ideas.isEmpty {
            throw GenerationError.validation("Qwen 返回的 idea 都与存量需求重复，请减少约束或重试。")
        }
        return BrainstormResult(
            ideas: cleaned.ideas,
            rationale: parsed["rationale"] as? String ?? "",
            filteredExistingIdeaCount: cleaned.filtered.count,
            filteredExistingIdeas: Array(cleaned.filtered.prefix(12))
        )
    }

    public func generateRequirements(
        robots: [RobotProfile],
        ideas: [String],
        phase: TaskPhase,
        ragStore: RAGStore,
        owner: String
    ) async throws -> [ValidationResult] {
        guard !robots.isEmpty else { throw GenerationError.validation("至少需要输入一台机器人配置") }
        let cleanIdeas = ideas.map(TextUtilities.stripListPrefix).filter { !$0.isEmpty }
        guard !cleanIdeas.isEmpty else { throw GenerationError.validation("请先输入至少一条任务 idea") }

        let robotText = robots.map {
            "- \($0.summary)\n  允许动作：\(Self.deriveCapabilities($0).allowedActions.joined(separator: ", "))"
        }.joined(separator: "\n")
        let ragContext = try prettyJSONString(
            ragStore.retrieveExamples(idea: cleanIdeas.joined(separator: " "), robots: robots, limit: 12).map { doc in
                [
                    "任务名称": doc.taskName,
                    "任务简述": doc.brief,
                    "采集设备": doc.device,
                    "采集模式": doc.mode,
                    "场景域分类": doc.category,
                    "任务级别": doc.level,
                    "目标次数": doc.targetTimes,
                    "任务步骤数量": doc.stepCount,
                    "动作标签": doc.actions,
                    "任务步骤描述": String(doc.steps.prefix(360)),
                ] as [String: Any]
            }
        )
        let schema = try prettyJSONString([
            "headers": ReqConstants.taskHeaders,
            "actions": Array(ReqConstants.canonicalActions.values),
            "format": "任务步骤描述必须逐行编号，每一行末尾必须包含 <动作（中文）><秒数s>。",
        ])
        let system = "你是机器人数据采集需求表生成器。你只输出 JSON，不要输出 Markdown。"
        let user = """
        请根据机器人配置、任务阶段和新的任务 idea，生成机器人数据采集需求。

        任务阶段：\(phase.label)
        固定目标次数：\(phase.targetTimes)
        需要生成条数：\(cleanIdeas.count)

        机器人配置：
        \(robotText)

        新的任务 idea：
        \(cleanIdeas.map { "- \($0)" }.joined(separator: "\n"))

        存量数据 RAG 检索上下文（用于参考字段写法、步骤粒度和动作标签；禁止照抄任务名或步骤）：
        \(ragContext)

        输出字段 schema：
        \(schema)

        要求：
        1. 每个输入 idea 至多生成一条需求。
        2. 目标次数必须填写 \(phase.targetTimes)。
        3. 不要生成与存量 RAG 重复或近似重复的任务。
        4. 严格遵守机器人移动、双臂、全身、末端执行器能力边界。
        5. 只输出 {"tasks":[...]} JSON。
        """

        let parsed = try await llmClient.generateJSON(system: system, user: user, timeoutSeconds: 240)
        let taskObjects = (parsed["tasks"] as? [[String: Any]])
            ?? (parsed["items"] as? [[String: Any]])
            ?? (parsed["rows"] as? [[String: Any]])
            ?? []
        guard !taskObjects.isEmpty else { throw GenerationError.validation("Qwen 响应缺少 tasks 数组") }

        let rows = taskObjects.enumerated().map { index, object in
            row(from: object, fallbackIdea: cleanIdeas[min(index, cleanIdeas.count - 1)], phase: phase, robot: robots.first, owner: owner)
        }
        let existingRows = ragStore.documents.map { doc in
            RequirementRow(
                taskName: doc.taskName,
                brief: doc.brief,
                device: doc.device,
                mode: doc.mode,
                category: doc.category,
                steps: doc.steps,
                targetTimes: Int(doc.targetTimes) ?? phase.targetTimes,
                machineParameters: "",
                level: doc.level,
                stepCount: Int(doc.stepCount) ?? TextUtilities.lineCount(from: doc.steps)
            )
        }
        return rows.map { Self.validate(row: $0, robots: robots, phase: phase, existingRows: existingRows) }
    }

    public static func validate(
        row: RequirementRow,
        robots: [RobotProfile],
        phase: TaskPhase,
        existingRows: [RequirementRow]
    ) -> ValidationResult {
        let robot = robots.first { row.device.contains($0.name) || row.device.contains($0.brand) } ?? robots.first
        var normalized = row
        normalized.targetTimes = phase.targetTimes
        normalized.stepCount = max(TextUtilities.lineCount(from: normalized.steps), normalized.stepCount)
        if normalized.mode.isEmpty, let robot { normalized.mode = robot.arms.rawValue }
        if normalized.device.isEmpty, let robot { normalized.device = robot.name }
        if normalized.machineParameters.isEmpty, let robot { normalized.machineParameters = robot.summary }

        var errors: [String] = []
        var warnings: [String] = []
        if normalized.taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("任务名称不能为空") }
        if normalized.steps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("任务步骤描述不能为空") }

        let actionKeys = Set(TextUtilities.actionKeys(from: normalized.steps))
        if let unknown = Set(normalized.steps.matches(pattern: #"<([^<>]+)>"#).compactMap(TextUtilities.actionKey)).subtracting(Set(ReqConstants.canonicalActions.keys)).first,
           !unknown.lowercased().hasSuffix("s") {
            warnings.append("存在未知动作标签：\(unknown)")
        }
        if let robot {
            if actionKeys.intersection(ReqConstants.mobileActions).isEmpty == false, !robot.mobile {
                errors.append("固定工位机器人不能生成移动、导航、搬运类任务")
            }
            if actionKeys.intersection(ReqConstants.bimanualActions).isEmpty == false, !robot.isDualArm || normalized.mode != ArmMode.dual.rawValue {
                errors.append("单臂或非双臂采集模式不能生成双臂协作任务")
            }
            if actionKeys.intersection(ReqConstants.wholeBodyActions).isEmpty == false, !robot.wholeBody {
                errors.append("未配置全身能力时不能生成蹲下、伸展类任务")
            }
            if robot.endEffector.contains("吸盘"), actionKeys.intersection(ReqConstants.suctionForbiddenActions).isEmpty == false {
                errors.append("吸盘配置不适合柔性、液体或精细任务")
            }
            if !robot.isDexterous, actionKeys.intersection(ReqConstants.fineActions).isEmpty == false {
                errors.append("非灵巧手配置不生成拧螺丝、拉拉链、插拔插头等精细任务")
            }
        }
        let rowDuplicateKeys = duplicateKeys(for: normalized)
        for existing in existingRows where !rowDuplicateKeys.intersection(duplicateKeys(for: existing)).isEmpty {
            errors.append("与存量需求重复：\(existing.taskName)")
            break
        }
        return ValidationResult(
            status: errors.isEmpty ? .accepted : .rejected,
            row: normalized,
            errors: errors,
            warnings: warnings,
            robotName: robot?.name ?? ""
        )
    }

    private func cleanBrainstormIdeas(_ rawIdeas: [Any], ragStore: RAGStore, limit: Int) -> (ideas: [String], filtered: [String]) {
        var ideas: [String] = []
        var filtered: [String] = []
        var seen = Set<String>()
        for raw in rawIdeas {
            let text = TextUtilities.stripListPrefix(String(describing: raw))
            let key = TextUtilities.normalizeTaskName(text)
            guard !text.isEmpty, !key.isEmpty, seen.insert(key).inserted else { continue }
            if let match = ragStore.existingMatchLabel(forIdea: text) {
                filtered.append("\(text) => \(match)")
                continue
            }
            ideas.append(String(text.prefix(80)))
            if ideas.count >= limit { break }
        }
        return (ideas, filtered)
    }

    private func row(
        from object: [String: Any],
        fallbackIdea: String,
        phase: TaskPhase,
        robot: RobotProfile?,
        owner: String
    ) -> RequirementRow {
        func string(_ header: String) -> String {
            if let value = object[header] as? String { return value }
            if let value = object[header] { return String(describing: value) }
            return ""
        }
        let steps = string("任务步骤描述")
        return RequirementRow(
            autoNumber: string("自动编号"),
            taskID: string("任务ID"),
            durationHours: string("采集时长（小时）"),
            submitTime: string("提交时间"),
            submitter: string("提交人").isEmpty ? "AI需求生成器" : string("提交人"),
            fillDate: string("填写日期"),
            taskName: string("任务名称").isEmpty ? "\(phase == .posttrain ? "后" : "预")-\(fallbackIdea)" : string("任务名称"),
            brief: string("任务简述").isEmpty ? "基于“\(fallbackIdea)”生成，限定在已配置机器人能力内完成。" : string("任务简述"),
            device: string("采集设备").isEmpty ? (robot?.name ?? "") : string("采集设备"),
            mode: string("采集模式").isEmpty ? (robot?.arms.rawValue ?? "双臂") : string("采集模式"),
            category: string("场景域分类").isEmpty ? inferCategory(fallbackIdea) : string("场景域分类"),
            steps: steps,
            targetTimes: phase.targetTimes,
            owner: owner.isEmpty ? string("数采负责人") : owner,
            machineParameters: string("机器及环境参数").isEmpty ? (robot?.summary ?? "") : string("机器及环境参数"),
            level: string("任务级别").isEmpty ? taskLevel(stepCount: TextUtilities.lineCount(from: steps), actions: TextUtilities.actionKeys(from: steps)) : string("任务级别"),
            stepCount: Int(string("任务步骤数量")) ?? TextUtilities.lineCount(from: steps)
        )
    }
}

public enum GenerationError: Error, LocalizedError {
    case validation(String)

    public var errorDescription: String? {
        switch self {
        case .validation(let message): message
        }
    }
}

func duplicateKeys(for row: RequirementRow) -> Set<String> {
    let name = TextUtilities.normalizeTaskName(row.taskName)
    let device = TextUtilities.normalizeDuplicateText(row.device)
    let brief = TextUtilities.normalizeDuplicateText(row.brief)
    let steps = TextUtilities.normalizeDuplicateText(row.steps)
    var keys = Set<String>()
    if !name.isEmpty { keys.insert("name:\(name)") }
    if !name.isEmpty, !device.isEmpty { keys.insert("name_device:\(device):\(name)") }
    if !name.isEmpty, !steps.isEmpty { keys.insert("name_steps:\(name):\(steps)") }
    if !device.isEmpty, !steps.isEmpty { keys.insert("device_steps:\(device):\(steps)") }
    if !device.isEmpty, !brief.isEmpty, !steps.isEmpty { keys.insert("content_device:\(device):\(brief):\(steps)") }
    return keys
}

func prettyJSONString(_ object: Any) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    return String(data: data, encoding: .utf8) ?? "{}"
}

func inferCategory(_ idea: String) -> String {
    if idea.range(of: #"药|商品|货架|超市|商店|扫码|补货"#, options: .regularExpression) != nil { return "商超药店" }
    if idea.range(of: #"餐|碗|盘|杯|筷|勺|厨房|面包|饮料|咖啡"#, options: .regularExpression) != nil { return "餐饮服务" }
    if idea.range(of: #"电池|工件|装配|螺丝|线束|产线|包装盒|质检"#, options: .regularExpression) != nil { return "工业制造" }
    if idea.range(of: #"抓取|放置|摆放|分拣"#, options: .regularExpression) != nil { return "通用抓取放置" }
    return "家居家政"
}

func taskLevel(stepCount: Int, actions: [String]) -> String {
    let actionSet = Set(actions)
    if stepCount >= 8 || !actionSet.intersection(ReqConstants.bimanualActions.union(ReqConstants.wholeBodyActions).union(ReqConstants.fineActions)).isEmpty {
        return "复杂"
    }
    if stepCount >= 5 || !actionSet.intersection(["Open", "Close", "Pour", "Scoop", "Wipe", "Navigate", "Move"]).isEmpty {
        return "中等"
    }
    return "简易"
}
