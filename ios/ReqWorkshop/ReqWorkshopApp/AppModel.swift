import Foundation
import Observation
import ReqWorkshopCore

@Observable
final class AppModel {
    var qwenModel = "qwen3.7-max"
    var endpoint = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation"
    var apiKeyDraft = ""
    var apiKeyConfigured = false
    var ragStore = RAGStore()
    var ragFileName = "未选择"
    var robots: [RobotProfile] = [
        RobotProfile(brand: "乐聚", model: "KUAVO", endEffector: "夹爪", arms: .dual, mobile: false, wholeBody: false, notes: "")
    ]
    var phase: TaskPhase = .pretrain
    var ideaPlanCount = 16
    var ideasText = "桌面垃圾清理\n餐具摆放\n电池入槽\n超市货架取放"
    var owner = ""
    var validations: [ValidationResult] = []
    var exportedURL: URL?
    var notice = ""
    var isBusy = false
    var hapticEvent = HapticEvent()
    var progressState: WorkProgress?
    @ObservationIgnored private var progressTicker: Task<Void, Never>?

    let modelOptions = ["qwen3.7-max", "qwen3-max", "qwen-plus", "qwen-turbo"]

    init() {
        loadSettings()
        refreshAPIKeyState()
    }

    var ideas: [String] {
        ideasText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var acceptedCount: Int {
        validations.filter { $0.status == .accepted }.count
    }

    var rejectedCount: Int {
        validations.filter { $0.status == .rejected }.count
    }

    var ragRobotPresets: [RobotPreset] {
        ragStore.inferredRobotPresets(limit: 6)
    }

    var ragRobotSuggestions: [RobotProfile] {
        ragRobotPresets.map(\.profile)
    }

    var hasRAGSource: Bool {
        !ragStore.documents.isEmpty
    }

    var hasUsableRobots: Bool {
        robots.contains { robot in
            let hasName = !robot.brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !robot.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return hasName && robot.hasManipulator
        }
    }

    var setupBlockers: [String] {
        var blockers: [String] = []
        if !apiKeyConfigured {
            blockers.append("先保存 DashScope API Key")
        }
        if !hasRAGSource {
            blockers.append("先导入 RAG Excel")
        }
        if !hasUsableRobots {
            blockers.append("至少配置一台有名称和可操作末端的机器人")
        }
        return blockers
    }

    var brainstormBlockers: [String] {
        setupBlockers
    }

    var generationBlockers: [String] {
        var blockers = setupBlockers
        if ideas.isEmpty {
            blockers.append("至少输入一条任务 idea")
        }
        return blockers
    }

    var canBrainstormIdeas: Bool {
        !isBusy && brainstormBlockers.isEmpty
    }

    var canGenerateRequirements: Bool {
        !isBusy && generationBlockers.isEmpty
    }

    var canExportXLSX: Bool {
        !isBusy && !validations.isEmpty
    }

    func refreshAPIKeyState() {
        apiKeyConfigured = ((try? KeychainStore.loadAPIKey()) ?? "").isEmpty == false
    }

    func saveAPIKey() {
        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            notice = apiKeyConfigured ? "已保留当前 Key；输入新 Key 后再保存即可替换。" : "请输入 DashScope API Key。"
            triggerHaptic(.warning)
            saveSettings()
            return
        }
        do {
            try KeychainStore.saveAPIKey(trimmed)
            apiKeyDraft = ""
            refreshAPIKeyState()
            notice = "API Key 已保存到本机 Keychain。"
        } catch {
            notice = error.localizedDescription
        }
    }

    func clearAPIKey() {
        do {
            try KeychainStore.clearAPIKey()
            refreshAPIKeyState()
            notice = "API Key 已清除。"
        } catch {
            notice = error.localizedDescription
        }
    }

	@MainActor
	func testConnection() async {
        let draftKey = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
		await runBusy(draftKey.isEmpty ? "连接测试通过。" : "临时 Key 连接测试通过，保存后才会用于生成。") {
            let apiKey = draftKey
			let client = self.makeClient()
            let testClient = DashScopeClient(
                apiKeyProvider: { apiKey.isEmpty ? try KeychainStore.loadAPIKey() : apiKey },
                model: client.model,
                endpoint: client.endpoint,
                session: client.session
            )
			_ = try await testClient.generateJSON(system: "你是 API 连通性测试器，只输出 JSON。", user: #"请只输出 {"ok": true}，不要添加解释。"#, timeoutSeconds: 20)
		}
	}

    @MainActor
    func importRAG(from url: URL) async {
        startProgress(.importExcel)
        isBusy = true
        notice = ""
        do {
            updateProgress(progress: 0.16, stepIndex: 0, detail: "正在读取 Excel 文件。")
            let fileName = url.lastPathComponent
            let importedStore = try await Task.detached(priority: .userInitiated) {
                let didAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccess { url.stopAccessingSecurityScopedResource() }
                }
                return try RAGStore(xlsxURL: url)
            }.value
            updateProgress(progress: 0.74, stepIndex: 2, detail: "正在构建 RAG 索引和候选机型。")
            ragStore = importedStore
            ragFileName = fileName
            validations = []
            exportedURL = nil
            let syncedCount = replaceRobotsFromRAG()
            notice = syncedCount > 0
                ? "RAG 已导入：\(ragStore.documents.count) 条历史需求，已从文件提取并填入 \(syncedCount) 台机器人能力。"
                : "RAG 已导入：\(ragStore.documents.count) 条历史需求，未识别到可用机器人能力。"
            completeProgress(detail: notice, status: .done)
            triggerHaptic(syncedCount > 0 ? .success : .warning)
            saveSettings()
        } catch {
            notice = "RAG 导入失败：\(error.localizedDescription)"
            completeProgress(detail: notice, status: .error)
            triggerHaptic(.error)
        }
        isBusy = false
    }

    func syncRobotsFromRAG() {
        let syncedCount = replaceRobotsFromRAG()
        exportedURL = nil
        notice = syncedCount > 0
            ? "已从 RAG 重新同步 \(syncedCount) 台机器人。"
            : "当前 RAG 没有可同步的机器人画像。"
        triggerHaptic(syncedCount > 0 ? .success : .warning)
        saveSettings()
    }

    func selectRobotPreset(_ preset: RobotPreset) {
        if isRobotSelected(preset.profile) {
            notice = "已选择过：\(preset.name)。"
            triggerHaptic(.warning)
            return
        }
        if shouldReplaceStarterRobot {
            robots = [preset.profile]
        } else {
            robots.append(preset.profile)
        }
        validations = []
        exportedURL = nil
        notice = "已选择机型：\(preset.name)，可继续确认能力。"
        triggerHaptic(.selection)
        saveSettings()
    }

	@MainActor
	func brainstormIdeas() async {
        guard brainstormBlockers.isEmpty else {
            notice = brainstormBlockers.first ?? "请先完成配置。"
            triggerHaptic(.warning)
            return
        }
		await runProgress(.brainstorm, fallbackSuccess: "自动脑洞完成。") {
			let engine = GenerationEngine(llmClient: self.makeClient())
			let result = try await engine.brainstormIdeas(
                robots: self.robots,
                phase: self.phase,
                ideaCount: self.ideaPlanCount,
                ragStore: self.ragStore,
                progress: { update in
                    await MainActor.run {
                        self.applyGenerationProgress(update)
                    }
                }
            )
			self.ideasText = result.ideas.joined(separator: "\n")
			self.notice = result.filteredExistingIdeaCount > 0
				? "已生成 \(result.ideas.count) 个 idea，过滤 \(result.filteredExistingIdeaCount) 个历史重复项。"
				: "已生成 \(result.ideas.count) 个 idea。"
		}
    }

	@MainActor
	func generateRequirements() async {
        guard generationBlockers.isEmpty else {
            notice = generationBlockers.first ?? "请先完成配置。"
            triggerHaptic(.warning)
            return
        }
		await runProgress(.requirements, fallbackSuccess: "需求生成完成。") {
			let engine = GenerationEngine(llmClient: self.makeClient())
			self.validations = try await engine.generateRequirements(
                robots: self.robots,
                ideas: self.ideas,
                phase: self.phase,
                ragStore: self.ragStore,
                owner: self.owner,
                progress: { update in
                    await MainActor.run {
                        self.applyGenerationProgress(update)
                    }
                }
            )
            self.exportedURL = nil
			self.notice = "已生成 \(self.validations.count) 条，接受 \(self.acceptedCount) 条，拒绝 \(self.rejectedCount) 条。"
		}
	}

    func exportXLSX() {
        revalidateResults()
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("generated_data_requirements_\(Int(Date().timeIntervalSince1970)).xlsx")
            try XLSXExporter().export(validations: validations, robots: robots, to: url)
            exportedURL = url
            notice = "Excel 已生成：接受 \(acceptedCount) 条，拒绝 \(rejectedCount) 条。"
            triggerHaptic(acceptedCount > 0 ? .success : .warning)
        } catch {
            notice = "导出失败：\(error.localizedDescription)"
            triggerHaptic(.error)
        }
    }

    func revalidateResults() {
        guard !validations.isEmpty else { return }
        exportedURL = nil
        let existingRows = ragStore.documents.map { doc in
            RequirementRow(
                taskName: doc.taskName,
                brief: doc.brief,
                device: doc.device,
                mode: doc.mode,
                category: doc.category,
                steps: doc.steps,
                targetTimes: Int(doc.targetTimes) ?? phase.targetTimes,
                machineParameters: doc.machineParameters,
                level: doc.level,
                stepCount: Int(doc.stepCount) ?? Self.lineCount(from: doc.steps)
            )
        }
        validations = validations.map { validation in
            GenerationEngine.validate(row: validation.row, robots: robots, phase: phase, existingRows: existingRows)
        }
        notice = "已重新校验：接受 \(acceptedCount) 条，拒绝 \(rejectedCount) 条。"
        triggerHaptic(rejectedCount == 0 ? .success : .warning)
    }

    func addRobot() {
        robots.append(RobotProfile(brand: "", model: "", endEffector: "夹爪", arms: .dual, mobile: false, wholeBody: false, notes: ""))
        exportedURL = nil
        triggerHaptic(.impact)
    }

    func removeRobots(at offsets: IndexSet) {
        robots.remove(atOffsets: offsets)
        if robots.isEmpty { addRobot() }
        exportedURL = nil
    }

    @discardableResult
    private func replaceRobotsFromRAG() -> Int {
        let suggested = ragRobotSuggestions
        guard !suggested.isEmpty else { return 0 }
        robots = suggested
        validations = []
        exportedURL = nil
        return suggested.count
    }

    func isRobotSelected(_ robot: RobotProfile) -> Bool {
        robots.contains { selected in
            normalizedRobotName(selected) == normalizedRobotName(robot)
        }
    }

    private var shouldReplaceStarterRobot: Bool {
        guard robots.count == 1, let robot = robots.first else { return false }
        return robot.brand == "乐聚"
            && robot.model == "KUAVO"
            && robot.endEffector == "夹爪"
            && robot.arms == .dual
            && robot.mobile == false
            && robot.wholeBody == false
            && robot.notes.isEmpty
    }

    private func normalizedRobotName(_ robot: RobotProfile) -> String {
        robot.name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func lineCount(from steps: String) -> Int {
        steps
            .split(whereSeparator: \.isNewline)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }

    func saveSettings() {
        let settings = LocalSettings(qwenModel: qwenModel, endpoint: endpoint, ragFileName: ragFileName, robots: robots, phase: phase, ideasText: ideasText, owner: owner)
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "ReqWorkshop.LocalSettings")
        }
    }

    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: "ReqWorkshop.LocalSettings"),
              let settings = try? JSONDecoder().decode(LocalSettings.self, from: data) else { return }
        qwenModel = settings.qwenModel
        endpoint = settings.endpoint
        ragFileName = settings.ragFileName
        robots = settings.robots.isEmpty ? robots : settings.robots
        phase = settings.phase
        ideasText = settings.ideasText
        owner = settings.owner
    }

    private func makeClient() -> DashScopeClient {
        DashScopeClient(
            apiKeyProvider: { try KeychainStore.loadAPIKey() },
            model: qwenModel,
            endpoint: URL(string: endpoint) ?? URL(string: "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation")!
        )
    }

    @MainActor
    private func runBusy(_ fallbackSuccess: String, operation: @escaping () async throws -> Void) async {
        isBusy = true
        notice = ""
        do {
            try await operation()
            if notice.isEmpty { notice = fallbackSuccess }
            triggerHaptic(.success)
            saveSettings()
        } catch {
            notice = error.localizedDescription
            triggerHaptic(.error)
        }
        isBusy = false
    }

    @MainActor
    private func runProgress(_ kind: WorkProgressKind, fallbackSuccess: String, operation: @escaping () async throws -> Void) async {
        startProgress(kind)
        isBusy = true
        notice = ""
        do {
            try await operation()
            if notice.isEmpty { notice = fallbackSuccess }
            completeProgress(detail: notice, status: .done)
            triggerHaptic(.success)
            saveSettings()
        } catch {
            notice = error.localizedDescription
            completeProgress(detail: notice, status: .error)
            triggerHaptic(.error)
        }
        isBusy = false
    }

    @MainActor
    private func startProgress(_ kind: WorkProgressKind) {
        progressTicker?.cancel()
        progressState = WorkProgress.profile(for: kind)
        let startedAt = Date()
        progressTicker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.tickProgress(startedAt: startedAt)
                }
            }
        }
    }

    @MainActor
    private func tickProgress(startedAt: Date) {
        guard var state = progressState, state.status == .running else { return }
        let increment = state.progress < 0.40 ? 0.08 : state.progress < 0.70 ? 0.04 : 0.015
        state.progress = min(0.88, state.progress + increment)
        let active = Int((state.progress * Double(max(state.steps.count, 1))).rounded(.down))
        state.activeStep = min(max(state.activeStep, active), max(state.steps.count - 1, 0))
        let elapsed = Date().timeIntervalSince(startedAt)
        if elapsed > 45, state.kind != .importExcel {
            state.detail = "模型仍在处理，数据量越大等待越久。请勿退出当前页面。"
        } else if elapsed > 8, state.kind == .importExcel {
            state.detail = "Excel 较大时解析会慢一些，正在继续处理。"
        }
        progressState = state
    }

    @MainActor
    private func applyGenerationProgress(_ update: GenerationProgressUpdate) {
        updateProgress(progress: update.progress, stepIndex: update.stepIndex, detail: update.detail)
    }

    @MainActor
    private func updateProgress(progress: Double, stepIndex: Int, detail: String) {
        guard var state = progressState else { return }
        state.progress = max(state.progress, min(max(progress, 0), 1))
        state.activeStep = max(state.activeStep, min(stepIndex, state.steps.count))
        state.detail = detail
        progressState = state
    }

    @MainActor
    private func completeProgress(detail: String, status: WorkProgressStatus) {
        progressTicker?.cancel()
        progressTicker = nil
        guard var state = progressState else { return }
        state.status = status
        state.progress = status == .done ? 1 : max(state.progress, 0.88)
        state.activeStep = status == .done ? state.steps.count : min(state.activeStep, max(state.steps.count - 1, 0))
        state.detail = detail
        progressState = state
    }

    func triggerHaptic(_ kind: HapticKind) {
        hapticEvent = HapticEvent(id: hapticEvent.id + 1, kind: kind)
    }
}

private struct LocalSettings: Codable {
    var qwenModel: String
    var endpoint: String
    var ragFileName: String
    var robots: [RobotProfile]
    var phase: TaskPhase
    var ideasText: String
    var owner: String
}

enum HapticKind: Equatable {
    case impact
    case selection
    case success
    case warning
    case error
}

struct HapticEvent: Equatable {
    var id = 0
    var kind: HapticKind = .impact
}

enum WorkProgressKind: Equatable {
    case importExcel
    case brainstorm
    case requirements
}

enum WorkProgressStatus: Equatable {
    case running
    case done
    case error
}

struct WorkProgress: Equatable {
    var kind: WorkProgressKind
    var title: String
    var detail: String
    var steps: [String]
    var progress: Double
    var activeStep: Int
    var status: WorkProgressStatus

    var percent: Int {
        Int((min(max(progress, 0), 1) * 100).rounded())
    }

    var statusText: String {
        switch status {
        case .running: "进行中 \(percent)%"
        case .done: "完成"
        case .error: "失败"
        }
    }

    static func profile(for kind: WorkProgressKind) -> WorkProgress {
        switch kind {
        case .importExcel:
            WorkProgress(
                kind: kind,
                title: "正在导入 Excel",
                detail: "正在读取工作簿，准备构建 RAG 索引。",
                steps: ["读取文件", "解析表头", "构建索引", "识别机型"],
                progress: 0.08,
                activeStep: 0,
                status: .running
            )
        case .brainstorm:
            WorkProgress(
                kind: kind,
                title: "Qwen 正在生成点子",
                detail: "正在整理机器人能力、存量样例和任务阶段。",
                steps: ["整理约束", "检索样例", "调用模型", "写入 idea"],
                progress: 0.08,
                activeStep: 0,
                status: .running
            )
        case .requirements:
            WorkProgress(
                kind: kind,
                title: "Qwen 正在生成需求",
                detail: "正在汇总机器人、idea、RAG 样例和字段格式。",
                steps: ["整理输入", "检索 RAG", "调用模型", "校验结果"],
                progress: 0.08,
                activeStep: 0,
                status: .running
            )
        }
    }
}
