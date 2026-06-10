import CoreXLSX
import Foundation

public struct RAGDocument: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var serial: Int
    public var taskName: String
    public var brief: String
    public var device: String
    public var mode: String
    public var category: String
    public var steps: String
    public var targetTimes: String
    public var machineParameters: String
    public var level: String
    public var stepCount: String
    public var actions: [String]
    public var tokens: Set<String>

    public init(
        id: UUID = UUID(),
        serial: Int,
        taskName: String,
        brief: String,
        device: String,
        mode: String,
        category: String,
        steps: String,
        targetTimes: String,
        machineParameters: String = "",
        level: String,
        stepCount: String,
        actions: [String]? = nil
    ) {
        self.id = id
        self.serial = serial
        self.taskName = taskName
        self.brief = brief
        self.device = device
        self.mode = mode
        self.category = category
        self.steps = steps
        self.targetTimes = targetTimes
        self.machineParameters = machineParameters
        self.level = level
        self.stepCount = stepCount
        self.actions = actions ?? TextUtilities.actionKeys(from: steps)
        self.tokens = TextUtilities.tokens(
            taskName,
            brief,
            device,
            mode,
            category,
            steps,
            machineParameters,
            self.actions.joined(separator: " "),
            self.actions.compactMap { ReqConstants.canonicalActions[$0] }.joined(separator: " ")
        )
    }

    public static func fixture(taskName: String, brief: String, device: String = "乐聚KUAVO") -> RAGDocument {
        RAGDocument(
            serial: 1,
            taskName: taskName,
            brief: brief,
            device: device,
            mode: "双臂",
            category: "工业制造",
            steps: "1. 抓取物体 <Grasp（抓取）><8s>\n2. 放置物体 <Place（放置）><8s>",
            targetTimes: "60",
            level: "简易",
            stepCount: "2"
        )
    }
}

public struct CountItem: Codable, Equatable, Sendable {
    public var name: String
    public var count: Int
}

public struct RAGSummary: Codable, Equatable, Sendable {
    public var rows: Int
    public var ragDocumentCount: Int
    public var topDevices: [CountItem]
    public var topCategories: [CountItem]
}

public struct RobotPreset: Identifiable, Codable, Equatable, Sendable {
    public var id: String { name }
    public var name: String
    public var profile: RobotProfile
    public var count: Int
    public var categories: [String]
    public var actions: [String]
    public var modes: [String]
}

public struct RAGStore: Codable, Sendable {
    public private(set) var documents: [RAGDocument]

    public init(documents: [RAGDocument] = []) {
        self.documents = documents
    }

    public init(xlsxURL: URL) throws {
        let file = try RAGStore.openXLSX(at: xlsxURL)
        let sharedStrings = try? file.parseSharedStrings()
        let workbook = try file.parseWorkbooks().first
        let paths: [(String?, String)]
        if let workbook {
            paths = try file.parseWorksheetPathsAndNames(workbook: workbook)
        } else {
            paths = try file.parseWorksheetPaths().map { (nil, $0) }
        }
        guard let firstPath = paths.first?.1 else {
            self.documents = []
            return
        }
        let worksheet = try file.parseWorksheet(at: firstPath)
        let rows = worksheet.data?.rows ?? []
        let table = rows.map { row in
            RAGStore.rowValues(from: row.cells, sharedStrings: sharedStrings)
        }
        self.documents = RAGStore.documents(from: table)
    }

    public var summary: RAGSummary {
        let devices = topCounts(documents.map(\.device), limit: 5).map { CountItem(name: $0.0, count: $0.1) }
        let categories = topCounts(documents.map(\.category), limit: 5).map { CountItem(name: $0.0, count: $0.1) }
        return RAGSummary(rows: documents.count, ragDocumentCount: documents.count, topDevices: devices, topCategories: categories)
    }

    public func inferredRobotProfiles(limit: Int = 6) -> [RobotProfile] {
        inferredRobotPresets(limit: limit).map(\.profile)
    }

    public func inferredRobotPresets(limit: Int = 6) -> [RobotPreset] {
        guard limit > 0 else { return [] }
        let groups = Dictionary(grouping: documents.filter { !$0.device.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            TextUtilities.normalizeDuplicateText($0.device)
        }
        return groups.values
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return (lhs.first?.device ?? "") < (rhs.first?.device ?? "")
                }
                return lhs.count > rhs.count
            }
            .prefix(limit)
            .compactMap { docs in
                guard let device = topCounts(docs.map(\.device), limit: 1).first?.0 else { return nil }
                let name = Self.splitDeviceName(device)
                let profile = RobotProfile(
                    brand: name.brand,
                    model: name.model,
                    endEffector: Self.inferEndEffector(from: docs),
                    arms: Self.inferArmMode(from: docs),
                    mobile: Self.inferMobile(from: docs),
                    wholeBody: Self.inferWholeBody(from: docs),
                    notes: Self.inferNotes(from: docs)
                )
                return RobotPreset(
                    name: device,
                    profile: profile,
                    count: docs.count,
                    categories: topCounts(docs.map(\.category), limit: 3).map(\.0),
                    actions: topCounts(docs.flatMap(\.actions), limit: 5).map { ReqConstants.canonicalActions[$0.0] ?? $0.0 },
                    modes: topCounts(docs.map(\.mode), limit: 3).map(\.0)
                )
            }
    }

    public func retrieveExamples(idea: String, robots: [RobotProfile], limit: Int) -> [RAGDocument] {
        guard limit > 0 else { return [] }
        let ideaTokens = TextUtilities.tokens(idea)
        let robotTokens = TextUtilities.tokens(robots.map { "\($0.name) \($0.brand) \($0.model)" }.joined(separator: " "))
        let queryTokens = ideaTokens.isEmpty ? robotTokens : ideaTokens
        let robotNames = Set(robots.map(\.name))
        let robotBrands = Set(robots.map(\.brand).filter { !$0.isEmpty })
        let robotModes = Set(robots.map(\.arms.rawValue))

        let scored = documents.compactMap { doc -> (Double, RAGDocument)? in
            let overlap = queryTokens.intersection(doc.tokens)
            let ideaOverlap = ideaTokens.intersection(doc.tokens)
            var score = Double(overlap.count) + Double(ideaOverlap.count) * 3
            let docText = [doc.taskName, doc.brief, doc.device, doc.mode, doc.category, doc.steps, doc.machineParameters].joined(separator: " ")
            if !idea.isEmpty, docText.contains(idea) { score += 8 }
            if robotNames.contains(doc.device) {
                score += ideaOverlap.isEmpty ? 0.7 : 2
            } else if robotBrands.contains(where: { !$0.isEmpty && doc.device.contains($0) }) {
                score += ideaOverlap.isEmpty ? 0.3 : 1
            }
            if robotModes.contains(doc.mode) { score += ideaOverlap.isEmpty ? 0.2 : 0.8 }
            return score > 0 ? (score, doc) : nil
        }
        return scored.sorted { lhs, rhs in
            lhs.0 == rhs.0 ? lhs.1.taskName < rhs.1.taskName : lhs.0 > rhs.0
        }
        .prefix(limit)
        .map(\.1)
    }

    public func existingMatchLabel(forIdea idea: String) -> String? {
        let ideaName = TextUtilities.normalizeTaskName(idea)
        let ideaText = TextUtilities.normalizeDuplicateText(idea)
        guard !ideaName.isEmpty else { return nil }
        for doc in documents {
            let name = TextUtilities.normalizeTaskName(doc.taskName)
            let brief = TextUtilities.normalizeDuplicateText(doc.brief)
            let steps = TextUtilities.normalizeDuplicateText(doc.steps)
            if !name.isEmpty, ideaName == name { return label(for: doc) }
            if !name.isEmpty, min(ideaName.count, name.count) >= 4, ideaName.contains(name) || name.contains(ideaName) {
                return label(for: doc)
            }
            if ideaText.count >= 6, brief.contains(ideaText) { return label(for: doc) }
            if ideaText.count >= 8, steps.contains(ideaText) { return label(for: doc) }
        }
        return nil
    }

    public func capabilityContext(for robots: [RobotProfile]) -> [[String: Any]] {
        robots.map { robot in
            let matched = documents.filter { robotMatches(robot, document: $0) }
            return [
                "机器人": robot.name,
                "用户配置能力": GenerationEngine.deriveCapabilities(robot).dictionary,
                "匹配历史需求数": matched.count,
                "常见采集模式": topCounts(matched.map(\.mode), limit: 5).map { ["name": $0.0, "count": $0.1] },
                "常见场景": topCounts(matched.map(\.category), limit: 5).map { ["name": $0.0, "count": $0.1] },
                "观察到动作": topCounts(matched.flatMap(\.actions), limit: 12).map { ["name": ReqConstants.canonicalActions[$0.0] ?? $0.0, "count": $0.1] },
                "历史机器参数样例": Array(matched.map(\.machineParameters).filter { !$0.isEmpty }.uniqued().prefix(5)),
                "历史任务名样例": Array(matched.map(\.taskName).uniqued().prefix(12)),
            ]
        }
    }

    func robotMatches(_ robot: RobotProfile, document: RAGDocument) -> Bool {
        let device = TextUtilities.normalizeDuplicateText(document.device)
        let names = [robot.name, robot.model, robot.brand + robot.model, robot.brand + " " + robot.model]
            .map(TextUtilities.normalizeDuplicateText)
            .filter { !$0.isEmpty }
        if names.contains(where: { $0.count >= 2 && (device.contains($0) || $0.contains(device)) }) {
            return true
        }
        let brand = TextUtilities.normalizeDuplicateText(robot.brand)
        return names.isEmpty && !brand.isEmpty && (device.contains(brand) || brand.contains(device))
    }

    private func label(for doc: RAGDocument) -> String {
        doc.device.isEmpty ? doc.taskName : "\(doc.taskName) / \(doc.device)"
    }

    private static func openXLSX(at url: URL) throws -> XLSXFile {
        guard let file = XLSXFile(filepath: url.path) else {
            throw RAGError.unreadableWorkbook
        }
        return file
    }

    static func documents(from table: [[String]]) -> [RAGDocument] {
        guard let headers = table.first else { return [] }
        let indexByHeader = indexHeaders(headers)
        func value(_ row: [String], _ header: String) -> String {
            guard let index = indexByHeader[header], index < row.count else { return "" }
            return row[index]
        }
        return table.dropFirst().enumerated().compactMap { offset, row in
            let taskName = value(row, "任务名称").trimmingCharacters(in: .whitespacesAndNewlines)
            let steps = value(row, "任务步骤描述")
            guard !taskName.isEmpty, !steps.isEmpty else { return nil }
            return RAGDocument(
                serial: offset + 1,
                taskName: taskName,
                brief: value(row, "任务简述"),
                device: value(row, "采集设备"),
                mode: value(row, "采集模式"),
                category: value(row, "场景域分类"),
                steps: steps,
                targetTimes: value(row, "目标次数"),
                machineParameters: value(row, "机器及环境参数"),
                level: value(row, "任务级别"),
                stepCount: value(row, "任务步骤数量")
            )
        }
    }

    private static func indexHeaders(_ headers: [String]) -> [String: Int] {
        var result: [String: Int] = [:]
        for (offset, rawHeader) in headers.enumerated() {
            let header = rawHeader.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !header.isEmpty, result[header] == nil else { continue }
            result[header] = offset
        }
        return result
    }

    private static func rowValues(from cells: [Cell], sharedStrings: SharedStrings?) -> [String] {
        guard !cells.isEmpty else { return [] }
        let firstColumn = ColumnReference("A")!
        var values: [String] = []
        for cell in cells {
            let index = firstColumn.distance(to: cell.reference.column)
            guard index >= 0 else { continue }
            if index >= values.count {
                values.append(contentsOf: Array(repeating: "", count: index - values.count + 1))
            }
            if let sharedStrings {
                values[index] = cell.stringValue(sharedStrings) ?? cell.inlineString?.text ?? cell.value ?? ""
            } else {
                values[index] = cell.inlineString?.text ?? cell.value ?? ""
            }
        }
        return values
    }

    private static func splitDeviceName(_ value: String) -> (brand: String, model: String) {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let knownBrands = ["星尘智能", "银河通用", "优必选", "傅利叶", "乐聚", "天机", "遨博", "智元", "宇树", "越疆", "节卡"]
            .sorted { $0.count > $1.count }
        if let brand = knownBrands.first(where: { cleaned.contains($0) }) {
            let model = cleaned.replacingOccurrences(of: brand, with: "")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            return (brand, model.isEmpty ? cleaned : model)
        }
        if let match = cleaned.firstMatch(pattern: #"^([\u{4e00}-\u{9fff}]{2,})([A-Za-z0-9].*)$"#), match.count == 3 {
            return (match[1], match[2].trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return ("", cleaned)
    }

    private static func inferArmMode(from docs: [RAGDocument]) -> ArmMode {
        let modes = docs.map(\.mode)
        if let topMode = topCounts(modes, limit: 1).first?.0 {
            if topMode.contains("单臂"), topMode.contains("左") { return .singleLeft }
            if topMode.contains("单臂") { return .singleRight }
            if topMode.contains("双") { return .dual }
        }
        return .dual
    }

    private static func inferMobile(from docs: [RAGDocument]) -> Bool {
        let text = capabilityText(from: docs)
        if text.range(of: #"不具备移动|无移动|固定工位|非移动|不能移动"#, options: .regularExpression) != nil { return false }
        let actions = Set(docs.flatMap(\.actions))
        if !actions.intersection(ReqConstants.mobileActions).isEmpty { return true }
        return text.range(of: #"具备移动|移动底盘|导航|巡检|跨房间|搬运|货架往返"#, options: .regularExpression) != nil
    }

    private static func inferWholeBody(from docs: [RAGDocument]) -> Bool {
        let text = capabilityText(from: docs)
        if text.range(of: #"不具备全身|无全身|非全身|不假设全身"#, options: .regularExpression) != nil { return false }
        let actions = Set(docs.flatMap(\.actions))
        if !actions.intersection(ReqConstants.wholeBodyActions).isEmpty { return true }
        return text.range(of: #"具备全身|全身能力|蹲下|伸展|升降"#, options: .regularExpression) != nil
    }

    private static func inferEndEffector(from docs: [RAGDocument]) -> String {
        let text = capabilityText(from: docs)
        if text.contains("灵巧手") { return "灵巧手" }
        if text.contains("吸盘") { return "吸盘" }
        if text.contains("二指") { return "二指夹爪" }
        let actions = Set(docs.flatMap(\.actions))
        if !actions.intersection(ReqConstants.fineActions).isEmpty { return "灵巧手" }
        if text.contains("夹爪") || text.contains("夹具") || text.contains("爪") { return "夹爪" }
        return "夹爪"
    }

    private static func inferNotes(from docs: [RAGDocument]) -> String {
        let categories = topCounts(docs.map(\.category), limit: 4).map(\.0).joined(separator: "、")
        let actions = topCounts(docs.flatMap(\.actions), limit: 8)
            .map { ReqConstants.canonicalActions[$0.0] ?? $0.0 }
            .joined(separator: "、")
        let scenes = categories.isEmpty ? "未识别" : categories
        let observedActions = actions.isEmpty ? "未识别" : actions
        return "从 RAG \(docs.count) 条历史需求自动归纳；常见场景：\(scenes)；观察动作：\(observedActions)"
    }

    private static func capabilityText(from docs: [RAGDocument]) -> String {
        docs.map { [$0.device, $0.mode, $0.category, $0.brief, $0.steps, $0.machineParameters].joined(separator: " ") }
            .joined(separator: " ")
    }
}

public enum RAGError: Error, LocalizedError {
    case unreadableWorkbook

    public var errorDescription: String? {
        switch self {
        case .unreadableWorkbook: "无法读取 xlsx 文件"
        }
    }
}

func topCounts(_ values: [String], limit: Int) -> [(String, Int)] {
    let cleaned = values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    let grouped = Dictionary(grouping: cleaned, by: { $0 })
    let counted = grouped.map { key, rows in (key, rows.count) }
    let sorted = counted.sorted { lhs, rhs in lhs.1 == rhs.1 ? lhs.0 < rhs.0 : lhs.1 > rhs.1 }
    return Array(sorted.prefix(limit))
}

private extension CapabilitySummary {
    var dictionary: [String: Any] {
        [
            "name": name,
            "summary": summary,
            "allowedActions": allowedActions,
            "blocked": blocked,
            "cautions": cautions,
        ]
    }
}
