import ReqWorkshopCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var model: AppModel
    @State private var selectedTab: WorkshopTab = .home

    var body: some View {
        ZStack {
            switch selectedTab {
            case .home:
                HomeView(model: model)
            case .rag:
                RAGView(model: model)
            case .robots:
                RobotsView(model: model)
            case .ideas:
                IdeasView(model: model)
            case .results:
                ResultsView(model: model)
            case .settings:
                SettingsView(model: model)
            }
        }
        .background(WorkshopStyle.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            PixelTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(WorkshopStyle.bg)
        }
        .preferredColorScheme(.light)
        .tint(WorkshopStyle.ink)
        .foregroundStyle(WorkshopStyle.ink)
        .font(WorkshopStyle.mono(.body))
        .overlay(alignment: .bottom) {
            if !model.notice.isEmpty {
                PixelToast(text: model.notice)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 84)
            }
        }
    }
}

private enum WorkshopTab: CaseIterable {
    case home
    case rag
    case robots
    case ideas
    case results
    case settings

    var title: String {
        switch self {
        case .home: "首页"
        case .rag: "RAG"
        case .robots: "机器人"
        case .ideas: "Idea"
        case .results: "结果"
        case .settings: "设置"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .rag: "doc.badge.plus"
        case .robots: "cpu"
        case .ideas: "sparkles"
        case .results: "tablecells"
        case .settings: "gearshape.fill"
        }
    }
}

private struct HomeView: View {
    @Bindable var model: AppModel

    var body: some View {
        WorkshopScreen(title: "工作台", subtitle: "需求生成工坊") {
            PixelPanel(
                title: "需求生成工坊",
                subtitle: "本地原生 iOS 版，不依赖 Python 服务",
                headerColor: WorkshopStyle.yellow,
                trailing: {
                    Meter(value: "\(model.acceptedCount)", label: "接受")
                }
            ) {
                HStack(alignment: .center, spacing: 14) {
                    Image("DemandLogo")
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 66, height: 66)
                        .pixelFrame(lineWidth: 3, shadow: 4)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("需求生成工坊")
                            .font(WorkshopStyle.mono(.title2, weight: .black))
                        Text("沿用 Web 版像素风、网格纸背景和硬边框")
                            .foregroundStyle(WorkshopStyle.muted)
                            .font(WorkshopStyle.mono(.footnote, weight: .semibold))
                    }
                }

                LazyVGrid(columns: WorkshopStyle.twoColumns, spacing: 10) {
                    StatusTile(title: "API 配置", value: model.apiKeyConfigured ? "\(model.qwenModel) 已配置" : "未配置", ok: model.apiKeyConfigured)
                    StatusTile(title: "RAG 数据源", value: "\(model.ragFileName) · \(model.ragStore.documents.count) 条", ok: !model.ragStore.documents.isEmpty)
                    StatusTile(title: "机器人", value: "\(model.robots.count) 台", ok: !model.robots.isEmpty)
                    StatusTile(title: "任务阶段", value: "\(model.phase.label) · \(model.phase.targetTimes) 次", ok: true)
                }
            }

            PixelPanel(title: "生成队列", subtitle: "本地状态实时同步", headerColor: WorkshopStyle.mint) {
                LazyVGrid(columns: WorkshopStyle.twoColumns, spacing: 10) {
                    SummaryTile(number: "\(model.ideas.count)", title: "Idea")
                    SummaryTile(number: "\(model.validations.count)", title: "结果")
                    SummaryTile(number: "\(model.acceptedCount)", title: "接受")
                    SummaryTile(number: "\(model.rejectedCount)", title: "拒绝")
                }
            }
        }
    }
}

private struct RAGView: View {
    @Bindable var model: AppModel
    @State private var importing = false

    var body: some View {
        WorkshopScreen(title: "RAG", subtitle: "本地 Excel 数据源") {
            PixelPanel(title: "RAG 数据源", subtitle: "只支持 .xlsx 文件", headerColor: WorkshopStyle.mint) {
                PixelButton(title: "选择 RAG Excel", systemImage: "square.and.arrow.down", tone: .secondary) {
                    importing = true
                }
                LazyVGrid(columns: WorkshopStyle.twoColumns, spacing: 10) {
                    SummaryTile(number: model.ragFileName, title: "文件")
                    SummaryTile(number: "\(model.ragStore.documents.count)", title: "RAG 索引")
                }
                if !model.ragStore.summary.topDevices.isEmpty {
                    InfoStrip(title: "常见设备", value: model.ragStore.summary.topDevices.map(\.name).joined(separator: "、"))
                }
            }

            PixelPanel(title: "样例", subtitle: "导入后展示前 12 条", headerColor: WorkshopStyle.yellow) {
                if model.ragStore.documents.isEmpty {
                    PixelEmpty(text: "还没有导入 RAG Excel")
                } else {
                    ForEach(Array(model.ragStore.documents.prefix(12))) { doc in
                        PixelCard {
                            Text(doc.taskName)
                                .font(WorkshopStyle.mono(.headline, weight: .black))
                            Text("\(doc.device) · \(doc.category) · \(doc.mode)")
                                .foregroundStyle(WorkshopStyle.muted)
                                .font(WorkshopStyle.mono(.caption, weight: .semibold))
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.spreadsheet], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                model.importRAG(from: url)
            }
        }
    }
}

private struct RobotsView: View {
    @Bindable var model: AppModel

    var body: some View {
        WorkshopScreen(title: "机器人", subtitle: "能力配置要清楚地区分具备 / 不具备") {
            PixelPanel(
                title: "机器人配置",
                subtitle: "能力边界会进入 prompt 和本地校验",
                headerColor: WorkshopStyle.yellow,
                trailing: {
                    PixelButton(title: "新增", systemImage: "plus", tone: .secondary, action: model.addRobot)
                }
            ) {
                ForEach($model.robots) { $robot in
                    PixelCard {
                        HStack {
                            Text(robot.name)
                                .font(WorkshopStyle.mono(.headline, weight: .black))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(WorkshopStyle.yellow)
                                .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 2))
                            Spacer()
                            Button {
                                if let index = model.robots.firstIndex(where: { $0.id == robot.id }) {
                                    model.robots.remove(at: index)
                                    if model.robots.isEmpty { model.addRobot() }
                                }
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(PixelButtonStyle(.danger, compact: true))
                        }
                        LabeledPixelField("品牌") {
                            TextField("品牌", text: $robot.brand)
                                .pixelInput()
                        }
                        LabeledPixelField("机型") {
                            TextField("机型", text: $robot.model)
                                .pixelInput()
                        }
                        LabeledPixelField("末端执行器") {
                            Picker("", selection: $robot.endEffector) {
                                ForEach(["夹爪", "吸盘", "灵巧手", "二指夹爪", "无"], id: \.self, content: Text.init)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .pixelInput()
                        }
                        LabeledPixelField("采集模式") {
                            Picker("", selection: $robot.arms) {
                                ForEach(ArmMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .pixelInput()
                        }
                        CapabilitySwitch(title: "移动能力", isOn: $robot.mobile)
                        CapabilitySwitch(title: "全身能力", isOn: $robot.wholeBody)
                        LabeledPixelField("补充约束") {
                            TextField("补充约束", text: $robot.notes, axis: .vertical)
                                .lineLimit(2...5)
                                .pixelInput(minHeight: 72)
                        }
                    }
                }
            }
        }
        .onDisappear(perform: model.saveSettings)
    }
}

private struct IdeasView: View {
    @Bindable var model: AppModel

    var body: some View {
        WorkshopScreen(title: "Idea", subtitle: "每行一条，保持表格感") {
            PixelPanel(title: "阶段", subtitle: "目标次数固定", headerColor: WorkshopStyle.yellow) {
                Picker("任务阶段", selection: $model.phase) {
                    ForEach(TaskPhase.allCases, id: \.self) { phase in
                        Text("\(phase.label) · \(phase.targetTimes)").tag(phase)
                    }
                }
                .pickerStyle(.segmented)
                .padding(3)
                .background(WorkshopStyle.paper)
                .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 2))
            }

            PixelPanel(title: "自动脑洞", subtitle: "Qwen 调用过程会显示本地进度", headerColor: WorkshopStyle.mint) {
                Stepper("想生成 \(model.ideaPlanCount) 类 idea", value: $model.ideaPlanCount, in: 1...200)
                    .font(WorkshopStyle.mono(.body, weight: .bold))
                    .padding(10)
                    .background(WorkshopStyle.paper)
                    .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 2))

                PixelButton(title: model.isBusy ? "Qwen 生成中..." : "Qwen 自动脑洞 idea", systemImage: "sparkles", tone: .secondary) {
                    Task { await model.brainstormIdeas() }
                }
                .disabled(model.isBusy || !model.apiKeyConfigured)

                if model.isBusy {
                    PixelProgress(text: "正在结合 RAG 和机器人能力生成 idea")
                }
            }

            PixelPanel(title: "任务 idea（每行一条）", subtitle: "一行一条，不写编号也可以", headerColor: WorkshopStyle.yellow) {
                TextEditor(text: $model.ideasText)
                    .scrollContentBackground(.hidden)
                    .pixelEditor(minHeight: 220)
                InfoStrip(title: "识别", value: "\(model.ideas.count) 个 idea，本次输出需求条数自动匹配")
            }

            PixelPanel(title: "负责人", subtitle: "可留空", headerColor: WorkshopStyle.mint) {
                TextField("数采负责人，可留空", text: $model.owner)
                    .pixelInput()
            }
        }
        .onDisappear(perform: model.saveSettings)
    }
}

private struct ResultsView: View {
    @Bindable var model: AppModel

    var body: some View {
        WorkshopScreen(title: "结果", subtitle: "生成、编辑、导出 Excel") {
            PixelPanel(
                title: "结果队列",
                subtitle: "生成后在这里编辑需求，再导出 Excel",
                headerColor: WorkshopStyle.mint,
                trailing: {
                    Meter(value: "\(model.validations.count)", label: "条")
                }
            ) {
                PixelButton(title: model.isBusy ? "Qwen 生成中..." : "调用 Qwen 生成", systemImage: "wand.and.stars", tone: .primary) {
                    Task { await model.generateRequirements() }
                }
                .disabled(model.isBusy || !model.apiKeyConfigured || model.ideas.isEmpty)

                if model.isBusy {
                    PixelProgress(text: "正在生成需求并执行本地重复 / 能力校验")
                }

                HStack(spacing: 10) {
                    PixelButton(title: "导出 Excel", systemImage: "square.and.arrow.up", tone: .secondary) {
                        model.exportXLSX()
                    }
                    .disabled(model.validations.isEmpty)
                    if let url = model.exportedURL {
                        ShareLink(item: url) {
                            Label("分享 Excel", systemImage: "arrow.up.doc")
                        }
                        .buttonStyle(PixelButtonStyle(.secondary))
                    }
                }
            }

            PixelPanel(title: "结果 \(model.acceptedCount) 接受 / \(model.rejectedCount) 拒绝", subtitle: "拒绝原因直接展示", headerColor: WorkshopStyle.yellow) {
                if model.validations.isEmpty {
                    PixelEmpty(text: "还没有生成结果")
                } else {
                    ForEach($model.validations) { $validation in
                        PixelCard(background: validation.status == .accepted ? WorkshopStyle.paper : WorkshopStyle.errorPaper) {
                            HStack(alignment: .top) {
                                TextField("任务名称", text: $validation.row.taskName)
                                    .font(WorkshopStyle.mono(.headline, weight: .black))
                                    .pixelInput()
                                Text(validation.status == .accepted ? "接受" : "拒绝")
                                    .font(WorkshopStyle.mono(.caption, weight: .black))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 8)
                                    .background(validation.status == .accepted ? WorkshopStyle.green : WorkshopStyle.red)
                                    .foregroundStyle(WorkshopStyle.paper)
                                    .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 2))
                            }
                            LabeledPixelField("任务简述") {
                                TextField("任务简述", text: $validation.row.brief, axis: .vertical)
                                    .lineLimit(2...4)
                                    .pixelInput(minHeight: 68)
                            }
                            LabeledPixelField("任务步骤描述") {
                                TextEditor(text: $validation.row.steps)
                                    .scrollContentBackground(.hidden)
                                    .pixelEditor(minHeight: 150)
                            }
                            if !validation.errors.isEmpty {
                                InfoStrip(title: "拒绝原因", value: validation.errors.joined(separator: "\n"), tone: .danger)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        WorkshopScreen(title: "设置", subtitle: "API 配置显式管理") {
            PixelPanel(title: "DashScope API", subtitle: "Key 只存 Keychain", headerColor: WorkshopStyle.yellow) {
                LabeledPixelField("API Key") {
                    SecureField("API Key", text: $model.apiKeyDraft)
                        .pixelInput()
                }
                LabeledPixelField("模型") {
                    Picker("", selection: $model.qwenModel) {
                        ForEach(model.modelOptions, id: \.self, content: Text.init)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .pixelInput()
                }
                LabeledPixelField("Endpoint") {
                    TextField("Endpoint", text: $model.endpoint)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .pixelInput()
                }
                HStack(spacing: 10) {
                    PixelButton(title: "保存 Key", systemImage: "externaldrive.badge.checkmark", tone: .primary, action: model.saveAPIKey)
                    PixelButton(title: "清除 Key", systemImage: "trash", tone: .danger, action: model.clearAPIKey)
                }
                PixelButton(title: model.isBusy ? "测试中..." : "测试连接", systemImage: "network", tone: .secondary) {
                    Task { await model.testConnection() }
                }
                .disabled(model.isBusy)
            }

            PixelPanel(title: "本地模式", subtitle: "不调用 Python 服务器", headerColor: WorkshopStyle.mint) {
                InfoStrip(title: "存储", value: "API Key 保存在本机 Keychain；RAG、机器人配置和导出文件仅保存在本机。")
            }
        }
        .onDisappear(perform: model.saveSettings)
    }
}

private enum WorkshopStyle {
    static let bg = Color(red: 0.969, green: 0.890, blue: 0.741)
    static let surface = Color(red: 1.000, green: 0.976, blue: 0.918)
    static let paper = Color(red: 1.000, green: 0.996, blue: 0.980)
    static let ink = Color(red: 0.161, green: 0.157, blue: 0.239)
    static let muted = Color(red: 0.420, green: 0.376, blue: 0.455)
    static let line = ink
    static let red = Color(red: 0.894, green: 0.341, blue: 0.341)
    static let blue = Color(red: 0.247, green: 0.412, blue: 0.729)
    static let green = Color(red: 0.184, green: 0.616, blue: 0.467)
    static let mint = Color(red: 0.737, green: 0.906, blue: 0.820)
    static let yellow = Color(red: 0.961, green: 0.784, blue: 0.298)
    static let sky = Color(red: 0.663, green: 0.875, blue: 0.953)
    static let errorPaper = Color(red: 1.000, green: 0.941, blue: 0.933)

    static let twoColumns = [GridItem(.adaptive(minimum: 145), spacing: 10)]

    static func mono(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .monospaced).weight(weight)
    }
}

private struct GridPaperBackground: View {
    var body: some View {
        Canvas { context, size in
            var vertical = Path()
            var x: CGFloat = 0
            while x <= size.width {
                vertical.move(to: CGPoint(x: x, y: 0))
                vertical.addLine(to: CGPoint(x: x, y: size.height))
                x += 18
            }
            context.stroke(vertical, with: .color(WorkshopStyle.ink.opacity(0.07)), lineWidth: 1)

            var horizontal = Path()
            var y: CGFloat = 0
            while y <= size.height {
                horizontal.move(to: CGPoint(x: 0, y: y))
                horizontal.addLine(to: CGPoint(x: size.width, y: y))
                y += 18
            }
            context.stroke(horizontal, with: .color(WorkshopStyle.ink.opacity(0.06)), lineWidth: 1)
        }
        .background(WorkshopStyle.bg)
        .ignoresSafeArea()
    }
}

private struct WorkshopScreen<Content: View>: View {
    let title: String
    let subtitle: String
    private let content: () -> Content

    init(title: String, subtitle: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        ZStack {
            GridPaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(WorkshopStyle.mono(.largeTitle, weight: .black))
                        Text(subtitle)
                            .font(WorkshopStyle.mono(.footnote, weight: .bold))
                            .foregroundStyle(WorkshopStyle.muted)
                    }
                    .padding(.top, 14)

                    content()
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .foregroundStyle(WorkshopStyle.ink)
    }
}

private struct PixelTabBar: View {
    @Binding var selectedTab: WorkshopTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(WorkshopTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .black))
                        Text(tab.title)
                            .font(WorkshopStyle.mono(.caption2, weight: .black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedTab == tab ? WorkshopStyle.mint : WorkshopStyle.paper)
                    .foregroundStyle(WorkshopStyle.ink)
                    .overlay(alignment: .trailing) {
                        if tab != WorkshopTab.allCases.last {
                            Rectangle().fill(WorkshopStyle.line).frame(width: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 3))
        .background(Rectangle().fill(WorkshopStyle.line).offset(x: 5, y: 5))
        .padding(.trailing, 5)
        .padding(.bottom, 5)
    }
}

private struct PixelPanel<Content: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let headerColor: Color
    private let trailing: () -> Trailing
    private let content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        headerColor: Color,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.headerColor = headerColor
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(WorkshopStyle.mono(.headline, weight: .black))
                    if let subtitle {
                        Text(subtitle)
                            .font(WorkshopStyle.mono(.caption, weight: .bold))
                            .foregroundStyle(WorkshopStyle.muted)
                    }
                }
                Spacer(minLength: 10)
                trailing()
            }
            .padding(14)
            .background(headerColor)
            .overlay(alignment: .bottom) {
                Rectangle().fill(WorkshopStyle.line).frame(height: 3)
            }

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WorkshopStyle.surface)
        }
        .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 3))
        .background(Rectangle().fill(WorkshopStyle.line).offset(x: 6, y: 6))
        .padding(.trailing, 6)
        .padding(.bottom, 6)
    }
}

private extension PixelPanel where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, headerColor: Color, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, subtitle: subtitle, headerColor: headerColor, trailing: { EmptyView() }, content: content)
    }
}

private struct PixelCard<Content: View>: View {
    let background: Color
    private let content: () -> Content

    init(background: Color = WorkshopStyle.paper, @ViewBuilder content: @escaping () -> Content) {
        self.background = background
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 2))
        .background(Rectangle().fill(WorkshopStyle.line).offset(x: 4, y: 4))
        .padding(.trailing, 4)
        .padding(.bottom, 4)
    }
}

private enum PixelButtonTone {
    case primary
    case secondary
    case danger
    case neutral

    var fill: Color {
        switch self {
        case .primary: WorkshopStyle.red
        case .secondary: WorkshopStyle.paper
        case .danger: WorkshopStyle.red
        case .neutral: WorkshopStyle.yellow
        }
    }

    var foreground: Color {
        switch self {
        case .primary, .danger: WorkshopStyle.paper
        case .secondary, .neutral: WorkshopStyle.ink
        }
    }
}

private struct PixelButtonStyle: ButtonStyle {
    let tone: PixelButtonTone
    let compact: Bool

    init(_ tone: PixelButtonTone = .secondary, compact: Bool = false) {
        self.tone = tone
        self.compact = compact
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WorkshopStyle.mono(.body, weight: .black))
            .foregroundStyle(tone.foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 8 : 11)
            .frame(minHeight: compact ? 34 : 44)
            .background(tone.fill)
            .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 2))
            .background(Rectangle().fill(WorkshopStyle.line).offset(x: configuration.isPressed ? 1 : 4, y: configuration.isPressed ? 1 : 4))
            .offset(x: configuration.isPressed ? 3 : 0, y: configuration.isPressed ? 3 : 0)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

private struct PixelButton: View {
    let title: String
    let systemImage: String
    let tone: PixelButtonTone
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(PixelButtonStyle(tone))
    }
}

private struct StatusTile: View {
    let title: String
    let value: String
    let ok: Bool

    var body: some View {
        PixelCard(background: ok ? WorkshopStyle.paper : WorkshopStyle.errorPaper) {
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(ok ? WorkshopStyle.green : WorkshopStyle.red)
                    .frame(width: 18, height: 18)
                    .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 2))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(WorkshopStyle.mono(.subheadline, weight: .black))
                    Text(value)
                        .font(WorkshopStyle.mono(.caption, weight: .bold))
                        .foregroundStyle(WorkshopStyle.muted)
                }
            }
        }
    }
}

private struct SummaryTile: View {
    let number: String
    let title: String

    var body: some View {
        PixelCard(background: WorkshopStyle.paper) {
            Text(number)
                .font(WorkshopStyle.mono(.title3, weight: .black))
                .lineLimit(2)
                .minimumScaleFactor(0.66)
            Text(title)
                .font(WorkshopStyle.mono(.caption, weight: .bold))
                .foregroundStyle(WorkshopStyle.muted)
        }
    }
}

private struct Meter: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(WorkshopStyle.mono(.title3, weight: .black))
            Text(label)
                .font(WorkshopStyle.mono(.caption, weight: .black))
        }
        .frame(minWidth: 72)
        .padding(.vertical, 8)
        .background(WorkshopStyle.green)
        .foregroundStyle(WorkshopStyle.paper)
        .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 2))
        .background(Rectangle().fill(WorkshopStyle.line).offset(x: 4, y: 4))
    }
}

private enum InfoTone {
    case normal
    case danger
}

private struct InfoStrip: View {
    let title: String
    let value: String
    var tone: InfoTone = .normal

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(WorkshopStyle.mono(.caption, weight: .black))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(tone == .danger ? WorkshopStyle.red : WorkshopStyle.yellow)
                .foregroundStyle(tone == .danger ? WorkshopStyle.paper : WorkshopStyle.ink)
                .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 2))
            Text(value)
                .font(WorkshopStyle.mono(.caption, weight: .bold))
                .foregroundStyle(WorkshopStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone == .danger ? WorkshopStyle.errorPaper : WorkshopStyle.paper)
        .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 2))
    }
}

private struct PixelEmpty: View {
    let text: String

    var body: some View {
        Text(text)
            .font(WorkshopStyle.mono(.footnote, weight: .bold))
            .foregroundStyle(WorkshopStyle.muted)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WorkshopStyle.paper)
            .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 2))
    }
}

private struct LabeledPixelField<Content: View>: View {
    let label: String
    private let content: () -> Content

    init(_ label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(WorkshopStyle.mono(.caption, weight: .black))
            content()
        }
    }
}

private struct CapabilitySwitch: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(WorkshopStyle.mono(.caption, weight: .black))
            HStack(spacing: 0) {
                CapabilityButton(label: "不具备", selected: !isOn, fill: WorkshopStyle.yellow) { isOn = false }
                CapabilityButton(label: "具备", selected: isOn, fill: WorkshopStyle.green) { isOn = true }
            }
            .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 2))
            Text("当前：\(isOn ? "具备" : "不具备")")
                .font(WorkshopStyle.mono(.caption, weight: .black))
                .foregroundStyle(isOn ? WorkshopStyle.green : WorkshopStyle.muted)
        }
    }
}

private struct CapabilityButton: View {
    let label: String
    let selected: Bool
    let fill: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(WorkshopStyle.mono(.caption, weight: .black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? fill : WorkshopStyle.paper)
                .foregroundStyle(selected && fill == WorkshopStyle.green ? WorkshopStyle.paper : WorkshopStyle.ink)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(WorkshopStyle.line).frame(width: 2)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct PixelProgress: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(WorkshopStyle.mono(.caption, weight: .black))
            ProgressView()
                .progressViewStyle(.linear)
                .tint(WorkshopStyle.green)
        }
        .padding(12)
        .background(WorkshopStyle.paper)
        .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 2))
        .background(Rectangle().fill(WorkshopStyle.line).offset(x: 4, y: 4))
        .padding(.trailing, 4)
        .padding(.bottom, 4)
    }
}

private struct PixelToast: View {
    let text: String

    var body: some View {
        Text(text)
            .font(WorkshopStyle.mono(.footnote, weight: .black))
            .foregroundStyle(WorkshopStyle.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WorkshopStyle.surface)
            .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 2))
            .background(Rectangle().fill(WorkshopStyle.line).offset(x: 4, y: 4))
    }
}

private extension View {
    func pixelFrame(lineWidth: CGFloat = 2, shadow: CGFloat = 4) -> some View {
        self
            .background(WorkshopStyle.paper)
            .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: lineWidth))
            .background(Rectangle().fill(WorkshopStyle.line).offset(x: shadow, y: shadow))
            .padding(.trailing, shadow)
            .padding(.bottom, shadow)
    }

    func pixelInput(minHeight: CGFloat = 42) -> some View {
        self
            .font(WorkshopStyle.mono(.body, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minHeight: minHeight, alignment: .leading)
            .background(WorkshopStyle.paper)
            .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 2))
            .background(Rectangle().fill(WorkshopStyle.ink.opacity(0.12)).offset(x: 3, y: 3))
            .padding(.trailing, 3)
            .padding(.bottom, 3)
    }

    func pixelEditor(minHeight: CGFloat) -> some View {
        self
            .font(WorkshopStyle.mono(.body, weight: .semibold))
            .padding(8)
            .frame(minHeight: minHeight)
            .background(WorkshopStyle.paper)
            .overlay(Rectangle().stroke(WorkshopStyle.line, lineWidth: 2))
            .background(Rectangle().fill(WorkshopStyle.ink.opacity(0.12)).offset(x: 3, y: 3))
            .padding(.trailing, 3)
            .padding(.bottom, 3)
    }
}

#Preview {
    ContentView(model: AppModel())
}
