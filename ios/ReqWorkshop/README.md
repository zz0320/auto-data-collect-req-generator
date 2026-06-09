# 需求生成工坊 iOS

这是 Web 版核心能力的本地原生 iOS 迁移版，目标平台 iOS 17+，使用 SwiftUI + Observation。

## 目录

- `ReqWorkshop.xcodeproj`: iOS App 工程和 shared scheme。
- `ReqWorkshopApp/`: SwiftUI 界面、Keychain、应用状态。
- `ReqWorkshopCore/`: 纯 Swift 核心包，包含 RAG、DashScope、生成引擎、校验和 XLSX 导出。
- `ReqWorkshopTests/`: Xcode scheme 级单元测试。

## 本地能力

- API Key 存入 iOS Keychain，不写入仓库。
- RAG 只支持 `.xlsx`，通过 CoreXLSX 读取。
- 导出 `.xlsx` 使用 ZIPFoundation 写最小 OOXML 工作簿，包含 `生成结果`、`校验日志`、`机器人配置` 三张表。
- 预训练目标次数固定为 `60`，后训练固定为 `600`。
- 自动脑洞和需求生成都会参考 RAG 历史数据，并在本地做重复和能力边界校验。

## 工作流

- `首页`: 查看准备度、idea 数、结果数和三段流程状态。
- `准备`: 集中配置 DashScope API、导入 RAG Excel、维护机器人能力。
- `生成`: 选择阶段、自动脑洞、编辑 idea、生成需求。
- `结果`: 编辑生成结果、查看拒绝原因、导出并分享 Excel。

## 打开和运行

```bash
open ios/ReqWorkshop/ReqWorkshop.xcodeproj
```

在 Xcode 中选择 `ReqWorkshop` scheme，选择 iOS Simulator，运行即可。首次使用需要在 App 的 `准备` 页填写 DashScope API Key、模型和 endpoint。

默认 endpoint:

```text
https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation
```

## 验证

可用 simulator 名称取决于本机 Xcode。当前验证使用的是 `iPhone 17` simulator；如果本机有 `iPhone 16`，也可以按计划命令替换 destination。

```bash
xcodebuild build -project ios/ReqWorkshop/ReqWorkshop.xcodeproj -scheme ReqWorkshop -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
xcodebuild test -project ios/ReqWorkshop/ReqWorkshop.xcodeproj -scheme ReqWorkshop -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
cd ios/ReqWorkshop/ReqWorkshopCore && swift test
```

本工程包含一个签名前清理扩展属性的 build phase，用来避免本机文件同步/下载属性导致 simulator codesign 报 `resource fork, Finder information, or similar detritus not allowed`。
