const authGate = document.querySelector("#authGate");
const appShell = document.querySelector("#appShell");
const loginForm = document.querySelector("#loginForm");
const loginUsername = document.querySelector("#loginUsername");
const loginPassword = document.querySelector("#loginPassword");
const loginBtn = document.querySelector("#loginBtn");
const authNotice = document.querySelector("#authNotice");
const userBadge = document.querySelector("#userBadge");
const avatarPickerBtn = document.querySelector("#avatarPickerBtn");
const userAvatar = document.querySelector("#userAvatar");
const avatarPanel = document.querySelector("#avatarPanel");
const closeAvatarBtn = document.querySelector("#closeAvatarBtn");
const avatarGrid = document.querySelector("#avatarGrid");
const avatarNotice = document.querySelector("#avatarNotice");
const apiConfigBtn = document.querySelector("#apiConfigBtn");
const openApiConfigInline = document.querySelector("#openApiConfigInline");
const adminUsersBtn = document.querySelector("#adminUsersBtn");
const logoutBtn = document.querySelector("#logoutBtn");
const apiPanel = document.querySelector("#apiPanel");
const closeApiBtn = document.querySelector("#closeApiBtn");
const apiConfigForm = document.querySelector("#apiConfigForm");
const apiConfigBadge = document.querySelector("#apiConfigBadge");
const apiConfigMeta = document.querySelector("#apiConfigMeta");
const apiConfigSource = document.querySelector("#apiConfigSource");
const apiKeyInput = document.querySelector("#apiKeyInput");
const toggleApiKeyBtn = document.querySelector("#toggleApiKeyBtn");
const apiKeyHelp = document.querySelector("#apiKeyHelp");
const apiModel = document.querySelector("#apiModel");
const apiModelCustom = document.querySelector("#apiModelCustom");
const apiEndpoint = document.querySelector("#apiEndpoint");
const testApiConfigBtn = document.querySelector("#testApiConfigBtn");
const clearApiKeyBtn = document.querySelector("#clearApiKeyBtn");
const apiNotice = document.querySelector("#apiNotice");
const adminPanel = document.querySelector("#adminPanel");
const closeAdminBtn = document.querySelector("#closeAdminBtn");
const createUserForm = document.querySelector("#createUserForm");
const newUsername = document.querySelector("#newUsername");
const newPassword = document.querySelector("#newPassword");
const newRole = document.querySelector("#newRole");
const adminNotice = document.querySelector("#adminNotice");
const userList = document.querySelector("#userList");
const robotsEl = document.querySelector("#robots");
const robotTemplate = document.querySelector("#robotTemplate");
const addRobotBtn = document.querySelector("#addRobotBtn");
const robotPresetList = document.querySelector("#robotPresetList");
const capabilityPreview = document.querySelector("#capabilityPreview");
const schemaLine = document.querySelector("#schemaLine");
const serverStatus = document.querySelector("#serverStatus");
const sourceStatus = document.querySelector("#sourceStatus");
const qwenDot = document.querySelector("#qwenDot");
const sheetDot = document.querySelector("#sheetDot");
const qwenReadiness = document.querySelector("#qwenReadiness");
const sheetReadiness = document.querySelector("#sheetReadiness");
const workbookFile = document.querySelector("#workbookFile");
const workbookDropzone = document.querySelector("#workbookDropzone");
const workbookSourceText = document.querySelector("#workbookSourceText");
const wizardTitle = document.querySelector("#wizardTitle");
const wizardHint = document.querySelector("#wizardHint");
const stepMeter = document.querySelector("#stepMeter");
const prevBtn = document.querySelector("#prevBtn");
const nextBtn = document.querySelector("#nextBtn");
const generateBtn = document.querySelector("#generateBtn");
const exportBtn = document.querySelector("#exportBtn");
const brainstormIdeasBtn = document.querySelector("#brainstormIdeasBtn");
const downloadLink = document.querySelector("#downloadLink");
const resultSummary = document.querySelector("#resultSummary");
const acceptedMeter = document.querySelector("#acceptedMeter");
const noticesEl = document.querySelector("#notices");
const resultsEl = document.querySelector("#results");
const generationSummary = document.querySelector("#generationSummary");
const ideaStatus = document.querySelector("#ideaStatus");
const phaseLimitText = document.querySelector("#phaseLimitText");
const targetTimesLimit = document.querySelector("#targetTimesLimit");
const taskPhaseInputs = [...document.querySelectorAll('input[name="taskPhase"]')];

const controls = {
  taskIdeas: document.querySelector("#taskIdeas"),
  ideaPlanCount: document.querySelector("#ideaPlanCount"),
  generationTaskCount: document.querySelector("#generationTaskCount"),
  ownerHint: document.querySelector("#ownerHint"),
  qwenModel: document.querySelector("#qwenModel"),
  qwenModelCustom: document.querySelector("#qwenModelCustom"),
  qwenEndpoint: document.querySelector("#qwenEndpoint"),
};

const stepMeta = [
  {
    title: "步骤 1：确认连接",
    hint: "先确认后端、Qwen 和存量表都就绪。",
  },
  {
    title: "步骤 2：登记机器人",
    hint: "只填写真实硬件具备的能力，后续生成会按这些约束执行。",
  },
  {
    title: "步骤 3：输入任务构想",
    hint: "预训练单任务目标次数最多 60 次，后训练最多 600 次；本次输出条数另行填写。",
  },
  {
    title: "步骤 4：生成和导出",
    hint: "先生成需求，在右侧编辑区修改后再导出 Excel。",
  },
];

const initialRobots = [];

let currentStep = 0;
let healthState = { ok: false, qwenConfigured: false, sheetReady: false };
let robotPresets = [];
let schemaState = null;
let generatedRows = [];
let lastGenerationSummary = null;
let currentUser = null;
let apiConfigState = null;
let taskPhases = {
  pretrain: { label: "预训练", maxTargetTimes: 60 },
  posttrain: { label: "后训练", maxTargetTimes: 600 },
};
const maxGenerationTaskCount = 200;
let ideaBusy = false;

const avatarOptions = [
  { id: "young_man", label: "男生", row: 0, col: 0 },
  { id: "young_woman", label: "女生", row: 0, col: 1 },
  { id: "engineer_boy", label: "工程师男生", row: 0, col: 2 },
  { id: "engineer_girl", label: "工程师女生", row: 0, col: 3 },
  { id: "cat", label: "猫咪", row: 1, col: 0 },
  { id: "dog", label: "狗狗", row: 1, col: 1 },
  { id: "rabbit", label: "兔子", row: 1, col: 2 },
  { id: "panda", label: "熊猫", row: 1, col: 3 },
  { id: "robot", label: "机器人", row: 2, col: 0 },
  { id: "fox", label: "狐狸", row: 2, col: 1 },
  { id: "bear", label: "小熊", row: 2, col: 2 },
  { id: "blob", label: "圆形角色", row: 2, col: 3 },
];
let currentAvatar = "robot";

const editableFields = [
  { key: "任务名称", label: "任务名称", type: "input" },
  { key: "任务简述", label: "任务简述", type: "textarea" },
  { key: "采集设备", label: "采集设备", type: "input" },
  { key: "采集模式", label: "采集模式", type: "input" },
  { key: "场景域分类", label: "场景域分类", type: "input" },
  { key: "目标次数", label: "目标次数", type: "input" },
  { key: "任务级别", label: "任务级别", type: "input" },
  { key: "任务步骤数量", label: "任务步骤数量", type: "input" },
  { key: "数采负责人", label: "数采负责人", type: "input" },
  { key: "机器及环境参数", label: "机器及环境参数", type: "textarea" },
  { key: "任务步骤描述", label: "任务步骤描述", type: "textarea", wide: true },
];

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function setNotice(node, message) {
  if (!node) return;
  node.textContent = message || "";
  node.classList.toggle("hidden", !message);
}

function avatarOptionById(id) {
  return avatarOptions.find((item) => item.id === id) || avatarOptions.find((item) => item.id === "robot") || avatarOptions[0];
}

function avatarBackgroundPosition(option) {
  const col = Number(option?.col || 0);
  const row = Number(option?.row || 0);
  return `${col * 33.3333}% ${row * 50}%`;
}

function paintAvatar(node, avatarId) {
  if (!node) return;
  const option = avatarOptionById(avatarId);
  node.dataset.avatar = option.id;
  node.style.backgroundPosition = avatarBackgroundPosition(option);
  node.setAttribute("title", option.label);
}

function renderAvatarGrid() {
  if (!avatarGrid) return;
  avatarGrid.innerHTML = avatarOptions
    .map((option) => {
      const selected = option.id === currentAvatar;
      return `
        <button class="avatar-option ${selected ? "selected" : ""}" type="button" data-avatar-id="${escapeHtml(option.id)}">
          <span class="avatar-sprite avatar-preview" style="background-position: ${avatarBackgroundPosition(option)}" aria-hidden="true"></span>
          <span>${escapeHtml(option.label)}</span>
        </button>
      `;
    })
    .join("");
}

function applyAvatar(avatarId) {
  const option = avatarOptionById(avatarId);
  currentAvatar = option.id;
  paintAvatar(userAvatar, currentAvatar);
  renderAvatarGrid();
}

function setAuthenticated(user) {
  currentUser = user || null;
  authGate?.classList.toggle("hidden", Boolean(currentUser));
  appShell?.classList.toggle("app-locked", !currentUser);
  if (userBadge) {
    userBadge.textContent = currentUser ? `${currentUser.username} · ${currentUser.role === "admin" ? "管理员" : "普通用户"}` : "未登录";
  }
  applyAvatar(currentUser?.avatar || "robot");
  adminUsersBtn?.classList.toggle("hidden", currentUser?.role !== "admin");
  if (!currentUser) {
    adminPanel?.classList.add("hidden");
    apiPanel?.classList.add("hidden");
    apiConfigState = null;
    if (apiKeyInput) apiKeyInput.value = "";
    generatedRows = [];
    lastGenerationSummary = null;
    resultsEl.innerHTML = "";
    acceptedMeter.textContent = "0";
    resultSummary.textContent = "生成后在这里编辑需求，再导出 Excel";
    downloadLink.href = "#";
    downloadLink.download = "";
    downloadLink.classList.add("disabled");
    downloadLink.setAttribute("aria-disabled", "true");
  }
}

function handleAuthExpired() {
  setAuthenticated(null);
  setNotice(authNotice, "请先登录。");
}

function splitIdeas() {
  return controls.taskIdeas.value
    .split(/[\n；;]+/)
    .map((item) => item.trim().replace(/^[-\s]+/, ""))
    .filter(Boolean);
}

function syncGenerationCountWithIdeas(message = "") {
  const count = splitIdeas().length;
  controls.generationTaskCount.value = String(count);
  if (ideaStatus && !ideaBusy) {
    ideaStatus.textContent = message || `已识别 ${count} 个 idea，本次输出需求条数自动匹配。`;
  }
  return count;
}

function plannedIdeaCount() {
  return Number(controls.ideaPlanCount.value || 0);
}

function currentQwenModel() {
  if (controls.qwenModel.value === "custom") {
    return controls.qwenModelCustom.value.trim();
  }
  return controls.qwenModel.value.trim();
}

function syncQwenModelCustom() {
  const isCustom = controls.qwenModel.value === "custom";
  controls.qwenModelCustom.classList.toggle("hidden-field", !isCustom);
  if (!isCustom) {
    controls.qwenModelCustom.value = "";
  }
}

function setQwenModel(model) {
  const value = String(model || "").trim();
  if (!value) return;
  const option = [...controls.qwenModel.options].find((item) => item.value === value);
  if (option) {
    controls.qwenModel.value = value;
    controls.qwenModelCustom.value = "";
  } else {
    controls.qwenModel.value = "custom";
    controls.qwenModelCustom.value = value;
  }
  syncQwenModelCustom();
}

function currentApiModel() {
  if (apiModel?.value === "custom") {
    return apiModelCustom?.value.trim() || "";
  }
  return apiModel?.value.trim() || currentQwenModel();
}

function syncApiModelCustom() {
  const isCustom = apiModel?.value === "custom";
  apiModelCustom?.classList.toggle("hidden-field", !isCustom);
  if (!isCustom && apiModelCustom) {
    apiModelCustom.value = "";
  }
}

function setApiModel(model) {
  const value = String(model || "").trim();
  if (!apiModel || !value) return;
  const option = [...apiModel.options].find((item) => item.value === value);
  if (option) {
    apiModel.value = value;
    if (apiModelCustom) apiModelCustom.value = "";
  } else {
    apiModel.value = "custom";
    if (apiModelCustom) apiModelCustom.value = value;
  }
  syncApiModelCustom();
}

function qwenSourceLabel(source) {
  if (source === "user") return "用户配置";
  if (source === "env") return "环境变量";
  if (source === "draft") return "临时输入";
  return "未配置";
}

function applyQwenConfig(config = {}) {
  apiConfigState = config;
  const configured = Boolean(config.configured);
  healthState.qwenConfigured = configured;
  setQwenModel(config.model || currentQwenModel());
  if (controls.qwenEndpoint && config.endpoint) controls.qwenEndpoint.value = config.endpoint;
  setApiModel(config.model || currentQwenModel());
  if (apiEndpoint) apiEndpoint.value = config.endpoint || controls.qwenEndpoint.value || "";
  if (apiKeyInput) apiKeyInput.value = "";
  const sourceLabel = qwenSourceLabel(config.source);
  const mask = config.apiKeyMask ? ` · ${config.apiKeyMask}` : "";
  if (apiConfigBadge) apiConfigBadge.textContent = configured ? "已配置" : "未配置";
  if (apiConfigMeta) apiConfigMeta.textContent = configured ? `${sourceLabel}${mask}` : "请填写 DashScope API Key 后保存";
  if (apiConfigSource) apiConfigSource.textContent = sourceLabel;
  sourceStatus.textContent = configured ? `Qwen: ${config.model || currentQwenModel()} · ${sourceLabel}` : "Qwen: 未配置";
  setDot(qwenDot, configured);
  qwenReadiness.textContent = configured ? `${sourceLabel}${mask}` : "请打开 API 配置填写 Key";
  if (apiKeyHelp) {
    apiKeyHelp.textContent = configured
      ? `当前 ${sourceLabel}${mask}；输入新 Key 并保存即可替换，留空保存会保留原 Key。`
      : "Key 只保存在当前用户本地设置中，不会写入代码仓库；已保存的 Key 只显示掩码。";
  }
  updateIdeaButton();
  updateReviewSummary();
  updateNav();
}

async function loadQwenConfig() {
  const config = await jsonFetch("/api/qwen/config");
  applyQwenConfig(config);
  return config;
}

function currentTaskPhase() {
  return taskPhaseInputs.find((input) => input.checked)?.value || "pretrain";
}

function currentPhaseConfig() {
  const phaseKey = currentTaskPhase();
  return taskPhases[phaseKey] || taskPhases.pretrain;
}

function normalizeTaskPhases(phases = {}) {
  const merged = { ...taskPhases };
  Object.entries(phases || {}).forEach(([key, value]) => {
    if (!value || typeof value !== "object") return;
    merged[key] = {
      label: value.label || merged[key]?.label || key,
      maxTargetTimes: Number(value.maxTargetTimes || value.maxTasks || merged[key]?.maxTargetTimes || 60),
    };
  });
  taskPhases = merged;
}

function syncPhaseControls({ clamp = true } = {}) {
  const phaseKey = currentTaskPhase();
  const phase = currentPhaseConfig();
  const maxTargetTimes = Number(phase.maxTargetTimes || 60);
  if (targetTimesLimit) {
    targetTimesLimit.value = String(maxTargetTimes);
  }
  if (phaseLimitText) {
    phaseLimitText.textContent = `${phase.label}任务：目标次数最多 ${maxTargetTimes} 次`;
  }
  document.querySelectorAll(".phase-option").forEach((node) => {
    const input = node.querySelector('input[name="taskPhase"]');
    node.classList.toggle("active", input?.value === phaseKey && input.checked);
  });
  controls.generationTaskCount.max = String(maxGenerationTaskCount);
}

function robotDisplayName(robot) {
  const brand = String(robot.brand || "").trim();
  const model = String(robot.model || "").trim();
  if (brand && model) return model.startsWith(brand) ? model : `${brand}${model}`;
  return brand || model || "未命名机器人";
}

function setDot(dot, ok) {
  dot.classList.toggle("ok", Boolean(ok));
  dot.classList.toggle("bad", ok === false);
}

function setBusy(isBusy) {
  generateBtn.disabled = isBusy;
  generateBtn.innerHTML = isBusy
    ? '<span class="btn-mark" aria-hidden="true"></span>Qwen 生成中...'
    : '<span class="btn-mark" aria-hidden="true"></span>调用 Qwen 生成';
  if (exportBtn) exportBtn.disabled = isBusy || generatedRows.length === 0;
}

function updateIdeaButton() {
  if (!brainstormIdeasBtn) return;
  brainstormIdeasBtn.disabled = ideaBusy || !healthState.qwenConfigured || collectRobots().length === 0;
}

function setIdeaBusy(isBusy) {
  ideaBusy = isBusy;
  if (brainstormIdeasBtn) {
    brainstormIdeasBtn.innerHTML = isBusy ? "Qwen 脑洞中..." : "Qwen 自动脑洞 idea";
  }
  if (ideaStatus && isBusy) {
    ideaStatus.textContent = "正在结合存量数据和机器人能力生成 idea。";
  }
  updateIdeaButton();
}

function updateCapabilityToggleLabels(root = document) {
  const labels = {
    mobile: ["不具备移动能力", "具备移动能力"],
    wholeBody: ["不具备全身能力", "具备全身能力"],
  };
  root.querySelectorAll(".capability-segment input[data-key]").forEach((input) => {
    const label = input.closest(".capability-segment");
    const textNode = label?.querySelector("[data-capability-state]");
    const pair = labels[input.dataset.key];
    if (!label || !textNode || !pair) return;
    const text = input.checked ? pair[1] : pair[0];
    textNode.textContent = text;
    input.setAttribute("aria-label", text);
    label.classList.toggle("is-on", input.checked);
    label.classList.toggle("is-off", !input.checked);
  });
}

async function jsonFetch(url, options = {}) {
  const headers = options.body instanceof FormData ? options.headers || {} : { "Content-Type": "application/json", ...(options.headers || {}) };
  const response = await fetch(url, { ...options, headers, credentials: "same-origin" });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || payload.ok === false) {
    if (response.status === 401 && !url.includes("/api/session") && !url.includes("/api/auth/login")) {
      handleAuthExpired();
    }
    throw new Error(payload.error || `${response.status} ${response.statusText}`);
  }
  return payload;
}

function addRobot(data = {}) {
  const node = robotTemplate.content.firstElementChild.cloneNode(true);
  robotsEl.appendChild(node);
  node.querySelectorAll("[data-key]").forEach((input) => {
    const key = input.dataset.key;
    if (typeof data[key] === "boolean") {
      input.checked = data[key];
    } else if (data[key] !== undefined) {
      input.value = data[key];
    }
    input.addEventListener("input", () => {
      updateCapabilityToggleLabels(node);
      refreshCapabilities();
      updateReviewSummary();
    });
    input.addEventListener("change", () => {
      updateCapabilityToggleLabels(node);
      refreshCapabilities();
      updateReviewSummary();
    });
  });
  updateCapabilityToggleLabels(node);
  node.querySelector(".remove-robot").addEventListener("click", () => {
    node.remove();
    renumberRobots();
    refreshCapabilities();
    updateReviewSummary();
    renderRobotPresets();
    updateNav();
  });
  renumberRobots();
  refreshCapabilities();
  updateReviewSummary();
  renderRobotPresets();
  updateNav();
}

function renumberRobots() {
  [...robotsEl.children].forEach((node, index) => {
    node.querySelector(".robot-index").textContent = `Robot ${index + 1}`;
  });
}

function collectRobots() {
  return [...robotsEl.children].map((node) => {
    const robot = {};
    node.querySelectorAll("[data-key]").forEach((input) => {
      const key = input.dataset.key;
      robot[key] = input.type === "checkbox" ? input.checked : input.value.trim();
    });
    return robot;
  });
}

function collectPayload() {
  return {
    robots: collectRobots(),
    taskIdeas: controls.taskIdeas.value,
    taskPhase: currentTaskPhase(),
    generationTaskCount: splitIdeas().length,
    matchIdeaCount: true,
    qwenModel: currentQwenModel(),
    qwenEndpoint: controls.qwenEndpoint.value.trim(),
  };
}

function presetToRobot(preset) {
  return {
    brand: preset.brand || preset.name || "",
    model: preset.model || "",
    endEffector: preset.endEffector || "夹爪",
    arms: preset.arms || "双臂",
    mobile: Boolean(preset.mobile),
    wholeBody: Boolean(preset.wholeBody),
    notes: preset.notes || "从存量数据需求表选择，可按真实硬件继续调整。",
  };
}

function renderRobotPresets() {
  if (!robotPresetList) return;
  if (!robotPresets.length) {
    robotPresetList.innerHTML = `<div class="notice">暂未从存量数据需求表归纳出机型列表，可使用“新增自定义”。</div>`;
    return;
  }
  const selected = new Set(collectRobots().map(robotDisplayName));
  robotPresetList.innerHTML = robotPresets
    .map((preset) => {
      const isSelected = selected.has(preset.name);
      const categories = (preset.categories || []).slice(0, 2).join("、") || "未归类";
      const modes = (preset.modes || []).map(([mode]) => mode).slice(0, 2).join("、") || preset.arms || "-";
      const mobility = preset.mobile ? "可移动" : "固定工位";
      const body = preset.wholeBody ? "全身" : "非全身";
      return `
        <button class="preset-card ${isSelected ? "selected" : ""}" type="button" data-preset-name="${escapeHtml(
          preset.name
        )}" ${isSelected ? "disabled" : ""}>
          <strong>${escapeHtml(preset.name)}</strong>
          <small>存量 ${escapeHtml(preset.count || 0)} 条 · ${escapeHtml(categories)}</small>
          <div class="preset-meta">
            <span>${escapeHtml(modes)}</span>
            <span>${escapeHtml(preset.endEffector || "夹爪")}</span>
            <span>${escapeHtml(mobility)}</span>
            <span>${escapeHtml(body)}</span>
          </div>
        </button>
      `;
    })
    .join("");
}

function validateStep(step) {
  if (step === 0) {
    if (!healthState.ok) return "后端未就绪。";
    if (!healthState.qwenConfigured) return "请先打开 API 配置，填写 DashScope API Key。";
    if (!healthState.sheetReady) return "存量数据需求表未就绪。";
    if (!currentQwenModel()) return "请填写 Qwen 模型。";
    if (!controls.qwenEndpoint.value.trim()) return "请填写 Qwen endpoint。";
  }
  if (step === 1) {
    const robots = collectRobots();
    if (!robots.length) return "至少需要一台机器人。";
    const invalid = robots.find((robot) => (!robot.brand && !robot.model) || !robot.endEffector || robot.endEffector === "无");
    if (invalid) return "机器人名称和可操作末端执行器都必须填写。";
  }
  if (step === 2) {
    const count = splitIdeas().length;
    if (!count) return "至少输入一个任务 idea。";
    if (!Number.isInteger(count) || count < 1 || count > maxGenerationTaskCount) {
      return `有效 idea 行数必须在 1 到 ${maxGenerationTaskCount} 之间；本次输出需求条数会自动匹配。`;
    }
  }
  return "";
}

function validateReadyToGenerate() {
  for (let step = 0; step < stepMeta.length; step += 1) {
    const invalid = validateStep(step);
    if (invalid) return invalid;
  }
  return "";
}

function updateNav() {
  prevBtn.disabled = currentStep === 0;
  nextBtn.textContent = currentStep === stepMeta.length - 1 ? "生成导出" : "下一步";
  nextBtn.disabled = currentStep === stepMeta.length - 1;
  generateBtn.disabled = Boolean(validateReadyToGenerate());
  if (exportBtn) exportBtn.disabled = generatedRows.length === 0;
  updateIdeaButton();
}

function updateWorkbookLabels(schema = schemaState) {
  if (!schema) return;
  const devices = (schema.devices || []).slice(0, 4).map(([name]) => name).join("、");
  const ragCount = Number(schema.ragDocumentCount || 0);
  sheetReadiness.textContent = `${schema.rows || 0} 条样例，${schema.headers?.length || 0} 个字段，RAG ${ragCount} 条`;
  schemaLine.textContent = `${schema.sheet || "数据表"}：${schema.rows || 0} 条样例；RAG 索引 ${ragCount} 条；常见设备 ${devices || "-"}`;
  if (workbookSourceText) {
    const sourceName = schema.source ? schema.source.split(/[\\/]/).pop() : "默认存量表";
    workbookSourceText.textContent = `${sourceName} · RAG ${ragCount} 条`;
  }
}

function showStep(step) {
  currentStep = Math.max(0, Math.min(step, stepMeta.length - 1));
  document.querySelectorAll(".wizard-step").forEach((node) => {
    node.classList.toggle("active", Number(node.dataset.step) === currentStep);
  });
  document.querySelectorAll(".step-tab").forEach((node, index) => {
    node.classList.toggle("active", index === currentStep);
    node.classList.toggle("done", index < currentStep);
  });
  wizardTitle.textContent = stepMeta[currentStep].title;
  wizardHint.textContent = stepMeta[currentStep].hint;
  stepMeter.textContent = `${currentStep + 1}/4`;
  if (currentStep === 3) updateReviewSummary();
  updateNav();
}

function renderCapabilities(items) {
  if (!items.length) {
    capabilityPreview.innerHTML = "";
    return;
  }
  capabilityPreview.innerHTML = items
    .map((item) => {
      const blocked = item.blocked?.length ? `禁用：${item.blocked.join("；")}` : "禁用：无";
      const cautions = item.cautions?.length ? `提示：${item.cautions.join("；")}` : "提示：常规桌面任务";
      return `
        <div class="capability-item">
          <strong>${escapeHtml(item.name)}</strong>
          <small>${escapeHtml(item.summary)}</small>
          <small>${escapeHtml(blocked)}</small>
          <small>${escapeHtml(cautions)}</small>
        </div>
      `;
    })
    .join("");
}

let capabilityTimer = 0;
function refreshCapabilities() {
  clearTimeout(capabilityTimer);
  capabilityTimer = setTimeout(async () => {
    try {
      const payload = await jsonFetch("/api/capabilities", {
        method: "POST",
        body: JSON.stringify({ robots: collectRobots() }),
      });
      renderCapabilities(payload.capabilities || []);
    } catch (error) {
      capabilityPreview.innerHTML = `<div class="notice">${escapeHtml(error.message)}</div>`;
    }
  }, 120);
}

function renderNotices(notices) {
  noticesEl.innerHTML = (notices || [])
    .map((notice) => `<div class="notice">${escapeHtml(notice)}</div>`)
    .join("");
}

function updateReviewSummary() {
  if (!generationSummary) return;
  const robots = collectRobots();
  const ideas = splitIdeas();
  const phase = currentPhaseConfig();
  const generationCount = ideas.length;
  const maxTargetTimes = Number(phase.maxTargetTimes || 60);
  generationSummary.innerHTML = `
    <div class="summary-card">
      <strong>机器人</strong>
      <ul>
        ${robots
          .map((robot) => {
            const mobile = robot.mobile ? "可移动" : "固定工位";
            const body = robot.wholeBody ? "全身" : "非全身";
            return `<li>${escapeHtml(`${robotDisplayName(robot)} / ${robot.arms} / ${robot.endEffector} / ${mobile} / ${body}`)}</li>`;
          })
          .join("")}
      </ul>
    </div>
    <div class="summary-card">
      <strong>任务构想</strong>
      <small>${escapeHtml(phase.label)}任务，${ideas.length} 个 idea，本次输出 ${
        generationCount || 0
      } 条需求；输出条数与 idea 行数匹配，单任务目标次数最多 ${maxTargetTimes} 次。</small>
      <ul>
        ${ideas.slice(0, 6).map((idea) => `<li>${escapeHtml(idea)}</li>`).join("")}
      </ul>
    </div>
    <div class="summary-card">
      <strong>模型</strong>
      <small>${escapeHtml(currentQwenModel() || "-")}</small>
      <small>${escapeHtml(controls.qwenEndpoint.value || "-")}</small>
    </div>
  `;
}

function renderResults(payload) {
  const rows = payload.rows || (payload.items || []).map((item) => item.row || {}).filter(Boolean);
  generatedRows = rows.map((row) => ({ ...row }));
  lastGenerationSummary = payload.summary || { generated: generatedRows.length };
  acceptedMeter.textContent = generatedRows.length;
  downloadLink.href = "#";
  downloadLink.download = "";
  downloadLink.classList.add("disabled");
  downloadLink.setAttribute("aria-disabled", "true");
  if (exportBtn) exportBtn.disabled = generatedRows.length === 0;
  const summary = lastGenerationSummary;
  const phaseText = summary.taskPhase ? `${summary.taskPhase} · ` : "";
  const requestedText = summary.requested ? `，本次输出 ${summary.requested} 条需求` : "";
  const targetText = summary.maxTargetTimes ? `，单任务目标次数 ≤ ${summary.maxTargetTimes} 次` : "";
  resultSummary.textContent = `${phaseText}已生成 ${generatedRows.length} 条${requestedText}${targetText}，可直接编辑后导出。`;
  sourceStatus.textContent = `Qwen: ${payload.model || currentQwenModel() || "-"}`;
  renderNotices(payload.notices || []);

  resultsEl.innerHTML = generatedRows
    .map((row, index) => {
      return `
        <article class="result-card editable-result" data-row-index="${index}">
          <div class="result-title">
            <strong>${escapeHtml(row["任务名称"] || "未命名任务")}</strong>
            <span class="pill">需求 ${index + 1}</span>
          </div>
          <div class="editable-grid">
            ${editableFields
              .map((field) => {
                const value = row[field.key] ?? "";
                const control =
                  field.type === "textarea"
                    ? `<textarea class="editable-control" data-row-index="${index}" data-field="${escapeHtml(field.key)}" rows="${
                        field.wide ? 7 : 3
                      }">${escapeHtml(value)}</textarea>`
                    : `<input class="editable-control" data-row-index="${index}" data-field="${escapeHtml(field.key)}" value="${escapeHtml(
                        value
                      )}" />`;
                return `<label class="editable-field ${field.wide ? "wide" : ""}"><span>${escapeHtml(field.label)}</span>${control}</label>`;
              })
              .join("")}
          </div>
        </article>
      `;
    })
    .join("");
}

function collectEditedRows() {
  const rows = generatedRows.map((row) => ({ ...row }));
  resultsEl.querySelectorAll("[data-field]").forEach((control) => {
    const index = Number(control.dataset.rowIndex);
    const field = control.dataset.field;
    if (rows[index] && field) rows[index][field] = control.value;
  });
  generatedRows = rows;
  return rows;
}

async function loadSchema() {
  try {
    const health = await jsonFetch("/api/health");
    healthState.ok = Boolean(health.ok);
    applyQwenConfig(
      health.qwenConfig || {
        configured: Boolean(health.qwenConfigured),
        source: health.qwenConfigSource,
        apiKeyMask: health.qwenApiKeyMask,
        model: health.qwenModel,
        endpoint: health.qwenEndpoint,
      }
    );

    serverStatus.textContent = health.ok ? "后端已连接" : "后端依赖异常";
    serverStatus.classList.toggle("ok", Boolean(health.ok));
    serverStatus.classList.toggle("bad", !health.ok);

    const schema = await jsonFetch("/api/schema");
    schemaState = schema;
    healthState.sheetReady = Boolean(schema.ok);
    robotPresets = schema.robotPresets || [];
    normalizeTaskPhases(schema.taskPhases || {});
    syncPhaseControls({ clamp: false });
    renderRobotPresets();
    setDot(sheetDot, schema.ok);
    updateWorkbookLabels(schema);
  } catch (error) {
    healthState = { ok: false, qwenConfigured: false, sheetReady: false };
    serverStatus.textContent = "后端未连接";
    serverStatus.classList.add("bad");
    sourceStatus.textContent = "Qwen: 未就绪";
    schemaLine.textContent = error.message;
    qwenReadiness.textContent = "服务不可用";
    sheetReadiness.textContent = "服务不可用";
    setDot(qwenDot, false);
    setDot(sheetDot, false);
  } finally {
    updateReviewSummary();
    renderRobotPresets();
    updateNav();
  }
}

async function uploadWorkbookFile(file) {
  if (!file) return;
  if (!file.name.toLowerCase().endsWith(".xlsx")) {
    renderNotices(["请选择 .xlsx 格式的存量数据表。"]);
    if (workbookFile) workbookFile.value = "";
    return;
  }
  if (workbookSourceText) workbookSourceText.textContent = "正在读取并重建 RAG...";
  setDot(sheetDot, null);
  try {
    const form = new FormData();
    form.append("workbook", file);
    const payload = await jsonFetch("/api/workbook/upload", { method: "POST", body: form });
    const schema = payload.summary || {};
    schemaState = schema;
    healthState.sheetReady = Boolean(schema.ok);
    robotPresets = schema.robotPresets || [];
    normalizeTaskPhases(schema.taskPhases || {});
    renderRobotPresets();
    updateWorkbookLabels(schema);
    setDot(sheetDot, schema.ok);
    renderNotices([`已切换 RAG Excel：${file.name}，索引 ${Number(schema.ragDocumentCount || 0)} 条。`]);
  } catch (error) {
    setDot(sheetDot, false);
    renderNotices([`RAG Excel 切换失败：${error.message}`]);
    updateWorkbookLabels();
  } finally {
    if (workbookFile) workbookFile.value = "";
    workbookDropzone?.classList.remove("drag-over");
    updateReviewSummary();
    updateNav();
  }
}

async function handleWorkbookUpload() {
  await uploadWorkbookFile(workbookFile?.files?.[0]);
}

function setWorkbookDragState(event, active) {
  event.preventDefault();
  event.stopPropagation();
  workbookDropzone?.classList.toggle("drag-over", active);
}

async function handleWorkbookDrop(event) {
  setWorkbookDragState(event, false);
  const file = event.dataTransfer?.files?.[0];
  await uploadWorkbookFile(file);
}

async function handleGenerate() {
  const invalid = validateReadyToGenerate();
  if (invalid) {
    renderNotices([invalid]);
    return;
  }
  setBusy(true);
  renderNotices([]);
  generatedRows = [];
  lastGenerationSummary = null;
  resultsEl.innerHTML = "";
  resultSummary.textContent = "Qwen 生成中";
  acceptedMeter.textContent = "0";
  downloadLink.href = "#";
  downloadLink.download = "";
  downloadLink.classList.add("disabled");
  downloadLink.setAttribute("aria-disabled", "true");
  if (exportBtn) exportBtn.disabled = true;
  try {
    const payload = await jsonFetch("/api/generate", {
      method: "POST",
      body: JSON.stringify(collectPayload()),
    });
    renderResults(payload);
  } catch (error) {
    renderNotices([error.message]);
    resultSummary.textContent = "生成失败";
  } finally {
    setBusy(false);
    updateNav();
  }
}

async function handleExport() {
  const rows = collectEditedRows();
  if (!rows.length) {
    renderNotices(["请先生成需求，再编辑并导出。"]);
    return;
  }
  const originalText = exportBtn.textContent;
  exportBtn.disabled = true;
  exportBtn.textContent = "导出中...";
  try {
    const payload = await jsonFetch("/api/export", {
      method: "POST",
      body: JSON.stringify({
        robots: collectRobots(),
        rows,
        taskPhase: currentTaskPhase(),
      }),
    });
    const summary = payload.summary || {};
    downloadLink.href = payload.downloadUrl || "#";
    downloadLink.download = payload.downloadName || "";
    downloadLink.classList.remove("disabled");
    downloadLink.setAttribute("aria-disabled", "false");
    const exportedCount = Number.isFinite(Number(summary.accepted)) ? Number(summary.accepted) : rows.length;
    resultSummary.textContent = `已导出 ${exportedCount} 条需求。`;
    const notices = payload.downloadUrl ? [`Excel 已导出：${payload.downloadName || "generated.xlsx"}`] : [];
    if (summary.rejected) notices.push(`${summary.rejected} 条未写入生成结果，原因见 Excel 校验日志。`);
    renderNotices(notices);
    if (payload.downloadUrl) downloadLink.click();
  } catch (error) {
    renderNotices([`导出失败：${error.message}`]);
  } finally {
    exportBtn.textContent = originalText;
    exportBtn.disabled = generatedRows.length === 0;
  }
}

async function handleBrainstormIdeas() {
  const robotInvalid = validateStep(1);
  if (robotInvalid) {
    renderNotices([robotInvalid]);
    return;
  }
  const phase = currentPhaseConfig();
  const ideaCount = plannedIdeaCount();
  if (!Number.isInteger(ideaCount) || ideaCount < 1 || ideaCount > maxGenerationTaskCount) {
    renderNotices([`想生成的 idea/任务数量必须在 1 到 ${maxGenerationTaskCount} 之间。`]);
    return;
  }
  setIdeaBusy(true);
  renderNotices([]);
  try {
    const payload = await jsonFetch("/api/ideas/brainstorm", {
      method: "POST",
      body: JSON.stringify({
        robots: collectRobots(),
        taskPhase: currentTaskPhase(),
        generationTaskCount: ideaCount,
        ideaCount,
        qwenModel: currentQwenModel(),
        qwenEndpoint: controls.qwenEndpoint.value.trim(),
      }),
    });
    const ideas = payload.ideas || [];
    controls.taskIdeas.value = ideas.join("\n");
    syncGenerationCountWithIdeas(`${payload.phaseLabel || phase.label}返回 ${ideas.length} 个 idea，本次输出需求条数已自动匹配。`);
    renderNotices([
      payload.rationale
        ? `Qwen 已生成 ${ideas.length} 个 idea：${payload.rationale}`
        : `Qwen 已生成 ${ideas.length} 个 idea。`,
    ]);
  } catch (error) {
    renderNotices([`自动脑洞失败：${error.message}`]);
    if (ideaStatus) {
      ideaStatus.textContent = "自动脑洞失败，仍可手动填写 idea。";
    }
  } finally {
    setIdeaBusy(false);
    updateReviewSummary();
    updateNav();
  }
}

async function loadSession() {
  try {
    const payload = await jsonFetch("/api/session");
    if (payload.authenticated && payload.user) {
      setAuthenticated(payload.user);
      setNotice(authNotice, "");
      await loadSchema();
    } else {
      setAuthenticated(null);
      if (payload.defaultAdminUsername && !loginUsername.value) {
        loginUsername.value = payload.defaultAdminUsername;
      }
    }
  } catch (error) {
    setAuthenticated(null);
    setNotice(authNotice, error.message);
  }
}

async function handleLogin(event) {
  event.preventDefault();
  const username = loginUsername.value.trim();
  const password = loginPassword.value;
  if (!username || !password) {
    setNotice(authNotice, "请输入用户名和密码。");
    return;
  }
  loginBtn.disabled = true;
  loginBtn.textContent = "登录中...";
  setNotice(authNotice, "");
  try {
    const payload = await jsonFetch("/api/auth/login", {
      method: "POST",
      body: JSON.stringify({ username, password }),
    });
    setAuthenticated(payload.user);
    loginPassword.value = "";
    await loadSchema();
  } catch (error) {
    setNotice(authNotice, error.message);
  } finally {
    loginBtn.disabled = false;
    loginBtn.textContent = "登录";
  }
}

async function handleLogout() {
  try {
    await jsonFetch("/api/auth/logout", { method: "POST", body: JSON.stringify({}) });
  } catch (error) {
    renderNotices([`退出失败：${error.message}`]);
  } finally {
    setAuthenticated(null);
    setNotice(authNotice, "已退出登录。");
  }
}

function renderUsers(users = []) {
  if (!userList) return;
  if (!users.length) {
    userList.innerHTML = `<div class="notice">暂无用户</div>`;
    return;
  }
  userList.innerHTML = users
    .map((user) => {
      const isSelf = currentUser?.id === user.id;
      const disabledText = user.disabled ? "已禁用" : "启用中";
      const roleText = user.role === "admin" ? "管理员" : "普通用户";
      return `
        <article class="user-row">
          <div>
            <strong>${escapeHtml(user.username)}</strong>
            <small>${escapeHtml(user.id)} · ${escapeHtml(user.createdAt || "-")}</small>
          </div>
          <span class="pill">${escapeHtml(roleText)}</span>
          <button class="mini-btn" type="button" data-action="toggle-disabled" data-user-id="${escapeHtml(user.id)}" data-next-disabled="${
            user.disabled ? "false" : "true"
          }" ${isSelf && !user.disabled ? "disabled" : ""}>${user.disabled ? "启用" : "禁用"}</button>
          <div class="user-actions">
            <input data-password-for="${escapeHtml(user.id)}" type="password" placeholder="新密码" autocomplete="new-password" />
            <button class="mini-btn" type="button" data-action="reset-password" data-user-id="${escapeHtml(user.id)}">重置</button>
          </div>
          <small>${escapeHtml(disabledText)}</small>
        </article>
      `;
    })
    .join("");
}

async function loadUsers() {
  const payload = await jsonFetch("/api/admin/users");
  renderUsers(payload.users || []);
}

async function openAdminPanel() {
  if (currentUser?.role !== "admin") return;
  adminPanel?.classList.remove("hidden");
  setNotice(adminNotice, "");
  try {
    await loadUsers();
  } catch (error) {
    setNotice(adminNotice, error.message);
  }
}

async function openApiPanel() {
  apiPanel?.classList.remove("hidden");
  setNotice(apiNotice, "");
  try {
    await loadQwenConfig();
  } catch (error) {
    setNotice(apiNotice, error.message);
  }
}

async function openAvatarPanel() {
  if (!currentUser) return;
  avatarPanel?.classList.remove("hidden");
  setNotice(avatarNotice, "");
  try {
    const payload = await jsonFetch("/api/profile");
    if (Array.isArray(payload.avatarOptions) && payload.avatarOptions.length) {
      avatarOptions.splice(0, avatarOptions.length, ...payload.avatarOptions);
    }
    applyAvatar(payload.avatar || currentAvatar);
  } catch (error) {
    renderAvatarGrid();
    setNotice(avatarNotice, error.message);
  }
}

async function handleAvatarChoice(event) {
  const button = event.target.closest("[data-avatar-id]");
  if (!button) return;
  const avatar = button.dataset.avatarId;
  button.disabled = true;
  setNotice(avatarNotice, "");
  try {
    const payload = await jsonFetch("/api/profile", {
      method: "POST",
      body: JSON.stringify({ avatar }),
    });
    currentUser = { ...(currentUser || {}), avatar: payload.avatar };
    applyAvatar(payload.avatar);
    setNotice(avatarNotice, "头像已更新。");
  } catch (error) {
    setNotice(avatarNotice, `头像更新失败：${error.message}`);
  } finally {
    button.disabled = false;
  }
}

async function handleSaveApiConfig(event) {
  event.preventDefault();
  const model = currentApiModel();
  const endpoint = apiEndpoint?.value.trim() || "";
  if (!model) {
    setNotice(apiNotice, "请填写 Qwen 模型。");
    return;
  }
  if (!endpoint) {
    setNotice(apiNotice, "请填写 Qwen Endpoint。");
    return;
  }
  const button = event.submitter || document.querySelector("#saveApiConfigBtn");
  if (button) button.disabled = true;
  setNotice(apiNotice, "");
  try {
    const payload = await jsonFetch("/api/qwen/config", {
      method: "POST",
      body: JSON.stringify({
        apiKey: apiKeyInput?.value.trim() || "",
        model,
        endpoint,
      }),
    });
    applyQwenConfig(payload);
    setNotice(apiNotice, "API 配置已保存。");
  } catch (error) {
    setNotice(apiNotice, `保存失败：${error.message}`);
  } finally {
    if (button) button.disabled = false;
  }
}

async function handleTestApiConfig() {
  const model = currentApiModel();
  const endpoint = apiEndpoint?.value.trim() || "";
  if (!model || !endpoint) {
    setNotice(apiNotice, "请先填写模型和 Endpoint。");
    return;
  }
  testApiConfigBtn.disabled = true;
  testApiConfigBtn.textContent = "测试中...";
  setNotice(apiNotice, "");
  try {
    const draftKey = apiKeyInput?.value.trim() || "";
    const payload = await jsonFetch("/api/qwen/test", {
      method: "POST",
      body: JSON.stringify({
        apiKey: draftKey,
        model,
        endpoint,
      }),
    });
    if (draftKey) {
      setNotice(apiNotice, `临时 Key 连接测试通过：${payload.model}。点击“保存配置”后才会用于生成。`);
    } else {
      await loadQwenConfig();
      setNotice(apiNotice, `连接测试通过：${payload.model}`);
    }
  } catch (error) {
    setNotice(apiNotice, `连接测试失败：${error.message}`);
  } finally {
    testApiConfigBtn.disabled = false;
    testApiConfigBtn.textContent = "测试连接";
  }
}

async function handleClearApiKey() {
  clearApiKeyBtn.disabled = true;
  setNotice(apiNotice, "");
  try {
    const payload = await jsonFetch("/api/qwen/config", {
      method: "POST",
      body: JSON.stringify({
        clearApiKey: true,
        model: currentApiModel(),
        endpoint: apiEndpoint?.value.trim() || "",
      }),
    });
    applyQwenConfig(payload);
    setNotice(apiNotice, payload.configured ? "已清除用户保存的 Key，当前使用环境变量配置。" : "已清除用户保存的 Key。");
  } catch (error) {
    setNotice(apiNotice, `清除失败：${error.message}`);
  } finally {
    clearApiKeyBtn.disabled = false;
  }
}

function toggleApiKeyVisibility() {
  if (!apiKeyInput || !toggleApiKeyBtn) return;
  const show = apiKeyInput.type === "password";
  apiKeyInput.type = show ? "text" : "password";
  toggleApiKeyBtn.textContent = show ? "隐藏" : "显示";
}

async function handleCreateUser(event) {
  event.preventDefault();
  const username = newUsername.value.trim();
  const password = newPassword.value;
  const role = newRole.value;
  if (!username || !password) {
    setNotice(adminNotice, "请输入新用户名和初始密码。");
    return;
  }
  try {
    const payload = await jsonFetch("/api/admin/users", {
      method: "POST",
      body: JSON.stringify({ username, password, role }),
    });
    newUsername.value = "";
    newPassword.value = "";
    newRole.value = "user";
    renderUsers(payload.users || []);
    setNotice(adminNotice, `已新增用户：${username}`);
  } catch (error) {
    setNotice(adminNotice, error.message);
  }
}

async function handleUserListAction(event) {
  const button = event.target.closest("[data-action]");
  if (!button) return;
  const userId = button.dataset.userId;
  const action = button.dataset.action;
  if (!userId) return;
  button.disabled = true;
  try {
    if (action === "toggle-disabled") {
      const payload = await jsonFetch("/api/admin/users/disabled", {
        method: "POST",
        body: JSON.stringify({ userId, disabled: button.dataset.nextDisabled === "true" }),
      });
      renderUsers(payload.users || []);
      setNotice(adminNotice, "用户状态已更新。");
    }
    if (action === "reset-password") {
      const input = [...userList.querySelectorAll("[data-password-for]")].find((node) => node.dataset.passwordFor === userId);
      const password = input?.value || "";
      if (!password) {
        setNotice(adminNotice, "请输入新密码。");
        return;
      }
      await jsonFetch("/api/admin/users/password", {
        method: "POST",
        body: JSON.stringify({ userId, password }),
      });
      input.value = "";
      setNotice(adminNotice, "密码已重置。");
    }
  } catch (error) {
    setNotice(adminNotice, error.message);
  } finally {
    button.disabled = false;
  }
}

addRobotBtn.addEventListener("click", () => addRobot({ brand: "", model: "", endEffector: "夹爪", arms: "双臂" }));
robotPresetList.addEventListener("click", (event) => {
  const card = event.target.closest(".preset-card");
  if (!card || card.disabled) return;
  const preset = robotPresets.find((item) => item.name === card.dataset.presetName);
  if (!preset) return;
  addRobot(presetToRobot(preset));
  renderNotices([`已选择存量机型：${preset.name}，请按真实硬件继续确认能力。`]);
});
prevBtn.addEventListener("click", () => showStep(currentStep - 1));
nextBtn.addEventListener("click", () => {
  const invalid = validateStep(currentStep);
  if (invalid) {
    renderNotices([invalid]);
    return;
  }
  renderNotices([]);
  showStep(currentStep + 1);
});
generateBtn.addEventListener("click", handleGenerate);
exportBtn?.addEventListener("click", handleExport);
brainstormIdeasBtn.addEventListener("click", handleBrainstormIdeas);
workbookFile?.addEventListener("change", handleWorkbookUpload);
workbookDropzone?.addEventListener("dragenter", (event) => setWorkbookDragState(event, true));
workbookDropzone?.addEventListener("dragover", (event) => setWorkbookDragState(event, true));
workbookDropzone?.addEventListener("dragleave", (event) => setWorkbookDragState(event, false));
workbookDropzone?.addEventListener("drop", handleWorkbookDrop);
loginForm?.addEventListener("submit", handleLogin);
logoutBtn?.addEventListener("click", handleLogout);
avatarPickerBtn?.addEventListener("click", openAvatarPanel);
closeAvatarBtn?.addEventListener("click", () => avatarPanel?.classList.add("hidden"));
avatarGrid?.addEventListener("click", handleAvatarChoice);
apiConfigBtn?.addEventListener("click", openApiPanel);
openApiConfigInline?.addEventListener("click", openApiPanel);
closeApiBtn?.addEventListener("click", () => apiPanel?.classList.add("hidden"));
apiConfigForm?.addEventListener("submit", handleSaveApiConfig);
testApiConfigBtn?.addEventListener("click", handleTestApiConfig);
clearApiKeyBtn?.addEventListener("click", handleClearApiKey);
toggleApiKeyBtn?.addEventListener("click", toggleApiKeyVisibility);
adminUsersBtn?.addEventListener("click", openAdminPanel);
closeAdminBtn?.addEventListener("click", () => adminPanel?.classList.add("hidden"));
createUserForm?.addEventListener("submit", handleCreateUser);
userList?.addEventListener("click", handleUserListAction);
resultsEl.addEventListener("input", (event) => {
  const control = event.target.closest("[data-field]");
  if (!control) return;
  const index = Number(control.dataset.rowIndex);
  const field = control.dataset.field;
  if (generatedRows[index] && field) {
    generatedRows[index][field] = control.value;
    const title = control.closest(".result-card")?.querySelector(".result-title strong");
    if (title && field === "任务名称") title.textContent = control.value || "未命名任务";
  }
});
controls.taskIdeas.addEventListener("input", () => {
  syncGenerationCountWithIdeas();
  updateReviewSummary();
  updateNav();
});
controls.ideaPlanCount.addEventListener("input", () => {
  updateNav();
});
controls.generationTaskCount.addEventListener("input", () => {
  updateReviewSummary();
  updateNav();
});
taskPhaseInputs.forEach((input) => {
  input.addEventListener("change", () => {
    syncPhaseControls();
    updateReviewSummary();
    updateNav();
  });
});
controls.qwenModel.addEventListener("change", () => {
  syncQwenModelCustom();
  updateReviewSummary();
  updateNav();
});
controls.qwenModelCustom.addEventListener("input", () => {
  updateReviewSummary();
  updateNav();
});
controls.qwenEndpoint.addEventListener("input", updateReviewSummary);
apiModel?.addEventListener("change", syncApiModelCustom);
apiModelCustom?.addEventListener("input", () => setNotice(apiNotice, ""));
apiEndpoint?.addEventListener("input", () => setNotice(apiNotice, ""));
syncPhaseControls({ clamp: false });
syncQwenModelCustom();
syncApiModelCustom();
applyAvatar("robot");
syncGenerationCountWithIdeas();
initialRobots.forEach(addRobot);
showStep(0);
loadSession();
