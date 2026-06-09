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

    var ragRobotSuggestions: [RobotProfile] {
        ragStore.inferredRobotProfiles(limit: 6)
    }

    func refreshAPIKeyState() {
        apiKeyConfigured = ((try? KeychainStore.loadAPIKey()) ?? "").isEmpty == false
    }

    func saveAPIKey() {
        do {
            try KeychainStore.saveAPIKey(apiKeyDraft)
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
		await runBusy("连接测试通过。") {
			let client = self.makeClient()
			_ = try await client.generateJSON(system: "你是 API 连通性测试器，只输出 JSON。", user: #"请只输出 {"ok": true}，不要添加解释。"#, timeoutSeconds: 20)
		}
	}

    func importRAG(from url: URL) {
        do {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess { url.stopAccessingSecurityScopedResource() }
            }
            ragStore = try RAGStore(xlsxURL: url)
            ragFileName = url.lastPathComponent
            validations = []
            let syncedCount = applyRobotsFromRAG()
            notice = syncedCount > 0
                ? "RAG 已导入：\(ragStore.documents.count) 条历史需求，已同步 \(syncedCount) 台机器人。"
                : "RAG 已导入：\(ragStore.documents.count) 条历史需求，未识别到机器人配置。"
            saveSettings()
        } catch {
            notice = "RAG 导入失败：\(error.localizedDescription)"
        }
    }

    func syncRobotsFromRAG() {
        let syncedCount = applyRobotsFromRAG()
        notice = syncedCount > 0
            ? "已从 RAG 重新同步 \(syncedCount) 台机器人。"
            : "当前 RAG 没有可同步的机器人画像。"
        saveSettings()
    }

	@MainActor
	func brainstormIdeas() async {
		await runBusy("自动脑洞完成。") {
			let engine = GenerationEngine(llmClient: self.makeClient())
			let result = try await engine.brainstormIdeas(robots: self.robots, phase: self.phase, ideaCount: self.ideaPlanCount, ragStore: self.ragStore)
			self.ideasText = result.ideas.joined(separator: "\n")
			self.notice = result.filteredExistingIdeaCount > 0
				? "已生成 \(result.ideas.count) 个 idea，过滤 \(result.filteredExistingIdeaCount) 个历史重复项。"
				: "已生成 \(result.ideas.count) 个 idea。"
		}
    }

	@MainActor
	func generateRequirements() async {
		await runBusy("需求生成完成。") {
			let engine = GenerationEngine(llmClient: self.makeClient())
			self.validations = try await engine.generateRequirements(robots: self.robots, ideas: self.ideas, phase: self.phase, ragStore: self.ragStore, owner: self.owner)
			self.notice = "已生成 \(self.validations.count) 条，接受 \(self.acceptedCount) 条，拒绝 \(self.rejectedCount) 条。"
		}
	}

    func exportXLSX() {
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("generated_data_requirements_\(Int(Date().timeIntervalSince1970)).xlsx")
            try XLSXExporter().export(validations: validations, robots: robots, to: url)
            exportedURL = url
            notice = "Excel 已生成，可通过系统分享导出。"
        } catch {
            notice = "导出失败：\(error.localizedDescription)"
        }
    }

    func addRobot() {
        robots.append(RobotProfile(brand: "", model: "", endEffector: "夹爪", arms: .dual, mobile: false, wholeBody: false, notes: ""))
    }

    func removeRobots(at offsets: IndexSet) {
        robots.remove(atOffsets: offsets)
        if robots.isEmpty { addRobot() }
    }

    @discardableResult
    private func applyRobotsFromRAG() -> Int {
        let suggested = ragRobotSuggestions
        guard !suggested.isEmpty else { return 0 }
        robots = suggested
        validations = []
        return suggested.count
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
            saveSettings()
        } catch {
            notice = error.localizedDescription
        }
        isBusy = false
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
