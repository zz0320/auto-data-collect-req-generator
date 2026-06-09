import ReqWorkshopCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        TabView {
            HomeView(model: model)
                .tabItem { Label("首页", systemImage: "house") }
            RAGView(model: model)
                .tabItem { Label("RAG", systemImage: "doc.badge.plus") }
            RobotsView(model: model)
                .tabItem { Label("机器人", systemImage: "cpu") }
            IdeasView(model: model)
                .tabItem { Label("Idea", systemImage: "sparkles") }
            ResultsView(model: model)
                .tabItem { Label("结果", systemImage: "tablecells") }
            SettingsView(model: model)
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .overlay(alignment: .bottom) {
            if !model.notice.isEmpty {
                Text(model.notice)
                    .font(.footnote)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding()
            }
        }
    }
}

private struct HomeView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image("DemandLogo")
                            .resizable()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading) {
                            Text("需求生成工坊")
                                .font(.title2.bold())
                            Text("本地原生 iOS 版，不依赖 Python 服务")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("状态") {
                    StatusRow(title: "API 配置", value: model.apiKeyConfigured ? "\(model.qwenModel) 已配置" : "未配置", ok: model.apiKeyConfigured)
                    StatusRow(title: "RAG 数据源", value: "\(model.ragFileName) · \(model.ragStore.documents.count) 条", ok: !model.ragStore.documents.isEmpty)
                    StatusRow(title: "机器人", value: "\(model.robots.count) 台", ok: !model.robots.isEmpty)
                    StatusRow(title: "任务阶段", value: "\(model.phase.label) · 目标次数 \(model.phase.targetTimes)", ok: true)
                }
                Section("生成队列") {
                    LabeledContent("Idea", value: "\(model.ideas.count) 条")
                    LabeledContent("结果", value: "\(model.acceptedCount) 接受 / \(model.rejectedCount) 拒绝")
                }
            }
            .navigationTitle("工作台")
        }
    }
}

private struct StatusRow: View {
    var title: String
    var value: String
    var ok: Bool

    var body: some View {
        HStack {
            Image(systemName: ok ? "checkmark.square.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? .green : .orange)
            VStack(alignment: .leading) {
                Text(title)
                Text(value).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct RAGView: View {
    @Bindable var model: AppModel
    @State private var importing = false

    var body: some View {
        NavigationStack {
            List {
                Section("RAG 数据源") {
                    Button {
                        importing = true
                    } label: {
                        Label("选择 RAG Excel", systemImage: "square.and.arrow.down")
                    }
                    LabeledContent("文件", value: model.ragFileName)
                    LabeledContent("RAG 索引", value: "\(model.ragStore.documents.count) 条")
                    if !model.ragStore.summary.topDevices.isEmpty {
                        LabeledContent("常见设备", value: model.ragStore.summary.topDevices.map(\.name).joined(separator: "、"))
                    }
                }
                Section("样例") {
                    ForEach(model.ragStore.documents.prefix(12)) { doc in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(doc.taskName).font(.headline)
                            Text("\(doc.device) · \(doc.category) · \(doc.mode)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("RAG")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.spreadsheet], allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    model.importRAG(from: url)
                }
            }
        }
    }
}

private struct RobotsView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                ForEach($model.robots) { $robot in
                    Section(robot.name) {
                        TextField("品牌", text: $robot.brand)
                        TextField("机型", text: $robot.model)
                        Picker("末端执行器", selection: $robot.endEffector) {
                            ForEach(["夹爪", "吸盘", "灵巧手", "二指夹爪", "无"], id: \.self, content: Text.init)
                        }
                        Picker("采集模式", selection: $robot.arms) {
                            ForEach(ArmMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        Toggle("具备移动能力", isOn: $robot.mobile)
                        Toggle("具备全身能力", isOn: $robot.wholeBody)
                        TextField("补充约束", text: $robot.notes, axis: .vertical)
                    }
                }
                .onDelete(perform: model.removeRobots)
            }
            .navigationTitle("机器人")
            .toolbar {
                Button("新增", action: model.addRobot)
            }
            .onDisappear(perform: model.saveSettings)
        }
    }
}

private struct IdeasView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationStack {
            Form {
                Section("阶段") {
                    Picker("任务阶段", selection: $model.phase) {
                        ForEach(TaskPhase.allCases, id: \.self) { phase in
                            Text("\(phase.label) · \(phase.targetTimes)").tag(phase)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("自动脑洞") {
                    Stepper("想生成 \(model.ideaPlanCount) 类 idea", value: $model.ideaPlanCount, in: 1...200)
                    Button {
                        Task { await model.brainstormIdeas() }
                    } label: {
                        Label(model.isBusy ? "Qwen 生成中..." : "Qwen 自动脑洞 idea", systemImage: "sparkles")
                    }
                    .disabled(model.isBusy || !model.apiKeyConfigured)
                }
                Section("任务 idea（每行一条）") {
                    TextEditor(text: $model.ideasText)
                        .frame(minHeight: 180)
                    Text("已识别 \(model.ideas.count) 个 idea，本次输出需求条数自动匹配。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("负责人") {
                    TextField("数采负责人，可留空", text: $model.owner)
                }
            }
            .navigationTitle("Idea")
            .onDisappear(perform: model.saveSettings)
        }
    }
}

private struct ResultsView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await model.generateRequirements() }
                    } label: {
                        Label(model.isBusy ? "Qwen 生成中..." : "调用 Qwen 生成", systemImage: "wand.and.stars")
                    }
                    .disabled(model.isBusy || !model.apiKeyConfigured || model.ideas.isEmpty)
                    Button {
                        model.exportXLSX()
                    } label: {
                        Label("导出 Excel", systemImage: "square.and.arrow.up")
                    }
                    .disabled(model.validations.isEmpty)
                    if let url = model.exportedURL {
                        ShareLink(item: url) {
                            Label("分享已导出 Excel", systemImage: "arrow.up.doc")
                        }
                    }
                }
                Section("结果 \(model.acceptedCount) 接受 / \(model.rejectedCount) 拒绝") {
                    ForEach($model.validations) { $validation in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(validation.row.taskName).font(.headline)
                                Spacer()
                                Text(validation.status == .accepted ? "接受" : "拒绝")
                                    .font(.caption.bold())
                                    .foregroundStyle(validation.status == .accepted ? .green : .red)
                            }
                            TextField("任务名称", text: $validation.row.taskName)
                            TextField("任务简述", text: $validation.row.brief, axis: .vertical)
                            TextEditor(text: $validation.row.steps)
                                .frame(minHeight: 120)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                            if !validation.errors.isEmpty {
                                Text(validation.errors.joined(separator: "\n"))
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("结果")
        }
    }
}

private struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationStack {
            Form {
                Section("DashScope API") {
                    SecureField("API Key", text: $model.apiKeyDraft)
                    Picker("模型", selection: $model.qwenModel) {
                        ForEach(model.modelOptions, id: \.self, content: Text.init)
                    }
                    TextField("Endpoint", text: $model.endpoint)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    HStack {
                        Button("保存 Key", action: model.saveAPIKey)
                        Button("清除 Key", role: .destructive, action: model.clearAPIKey)
                    }
                    Button {
                        Task { await model.testConnection() }
                    } label: {
                        Label("测试连接", systemImage: "network")
                    }
                    .disabled(model.isBusy)
                }
                Section("本地模式") {
                    Text("API Key 保存在本机 Keychain；RAG、机器人配置和导出文件仅保存在本机，不调用 Python 服务器。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .onDisappear(perform: model.saveSettings)
        }
    }
}

#Preview {
    ContentView(model: AppModel())
}
