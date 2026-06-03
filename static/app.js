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
const feishuDot = document.querySelector("#feishuDot");
const qwenReadiness = document.querySelector("#qwenReadiness");
const sheetReadiness = document.querySelector("#sheetReadiness");
const workbookFile = document.querySelector("#workbookFile");
const workbookSourceText = document.querySelector("#workbookSourceText");
const wizardTitle = document.querySelector("#wizardTitle");
const wizardHint = document.querySelector("#wizardHint");
const stepMeter = document.querySelector("#stepMeter");
const prevBtn = document.querySelector("#prevBtn");
const nextBtn = document.querySelector("#nextBtn");
const generateBtn = document.querySelector("#generateBtn");
const brainstormIdeasBtn = document.querySelector("#brainstormIdeasBtn");
const testFeishuBtn = document.querySelector("#testFeishuBtn");
const downloadLink = document.querySelector("#downloadLink");
const resultSummary = document.querySelector("#resultSummary");
const acceptedMeter = document.querySelector("#acceptedMeter");
const noticesEl = document.querySelector("#notices");
const resultsEl = document.querySelector("#results");
const reviewSummary = document.querySelector("#reviewSummary");
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
  sendFeishu: document.querySelector("#sendFeishu"),
  feishuWebhook: document.querySelector("#feishuWebhook"),
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
    title: "步骤 4：审核并生成",
    hint: "确认摘要后调用 Qwen，结果会先校验再导出。",
  },
];

const initialRobots = [];

let currentStep = 0;
let healthState = { ok: false, qwenConfigured: false, sheetReady: false };
let robotPresets = [];
let schemaState = null;
let taskPhases = {
  pretrain: { label: "预训练", maxTargetTimes: 60 },
  posttrain: { label: "后训练", maxTargetTimes: 600 },
};
const maxGenerationTaskCount = 200;
let ideaBusy = false;

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
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

async function jsonFetch(url, options = {}) {
  const headers = options.body instanceof FormData ? options.headers || {} : { "Content-Type": "application/json", ...(options.headers || {}) };
  const response = await fetch(url, { ...options, headers });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || payload.ok === false) {
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
      refreshCapabilities();
      updateReviewSummary();
    });
    input.addEventListener("change", () => {
      refreshCapabilities();
      updateReviewSummary();
    });
  });
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
    sendFeishu: controls.sendFeishu.checked,
    feishuWebhook: controls.feishuWebhook.value.trim(),
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
    if (!healthState.qwenConfigured) return "服务端未配置 DASHSCOPE_API_KEY。";
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
  if (step === 3 && controls.sendFeishu.checked && !controls.feishuWebhook.value.trim()) {
    return "已开启飞书推送，请填写 webhook。";
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
  nextBtn.textContent = currentStep === stepMeta.length - 1 ? "已到审核" : "下一步";
  nextBtn.disabled = currentStep === stepMeta.length - 1;
  generateBtn.disabled = Boolean(validateReadyToGenerate());
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
  if (!reviewSummary) return;
  const robots = collectRobots();
  const ideas = splitIdeas();
  const phase = currentPhaseConfig();
  const generationCount = ideas.length;
  const maxTargetTimes = Number(phase.maxTargetTimes || 60);
  reviewSummary.innerHTML = `
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
    <div class="summary-card">
      <strong>飞书</strong>
      <small>${controls.sendFeishu.checked ? "生成后推送" : "不推送"}</small>
    </div>
  `;
}

function renderResults(payload) {
  const summary = payload.summary || { generated: 0, accepted: 0, rejected: 0 };
  acceptedMeter.textContent = summary.accepted || 0;
  const phaseText = summary.taskPhase ? `${summary.taskPhase} · ` : "";
  const requestedText = summary.requested ? `，本次输出 ${summary.requested} 条需求` : "";
  const targetText = summary.maxTargetTimes ? `，单任务目标次数 ≤ ${summary.maxTargetTimes} 次` : "";
  resultSummary.textContent = `${phaseText}生成 ${summary.generated || 0} 条${requestedText}${targetText}，通过 ${
    summary.accepted || 0
  } 条，拒绝 ${summary.rejected || 0} 条`;
  sourceStatus.textContent = `Qwen: ${payload.model || currentQwenModel() || "-"}`;
  renderNotices(payload.notices || []);

  if (payload.downloadUrl) {
    downloadLink.href = payload.downloadUrl;
    downloadLink.download = payload.downloadName || "";
    downloadLink.classList.remove("disabled");
    downloadLink.setAttribute("aria-disabled", "false");
  }

  const items = payload.items || [];
  resultsEl.innerHTML = items
    .map((item) => {
      const row = item.row || {};
      const status = item.status === "accepted" ? "accepted" : "rejected";
      const statusText = status === "accepted" ? "通过" : "拒绝";
      const issues = [...(item.errors || []), ...(item.warnings || [])];
      return `
        <article class="result-card ${status}">
          <div class="result-title">
            <strong>${escapeHtml(row["任务名称"] || "未命名任务")}</strong>
            <span class="pill ${status}">${statusText}</span>
          </div>
          <div class="result-meta">
            <span>${escapeHtml(row["采集设备"] || "-")}</span>
            <span>${escapeHtml(row["采集模式"] || "-")}</span>
            <span>${escapeHtml(row["场景域分类"] || "-")}</span>
            <span>${escapeHtml(row["任务级别"] || "-")}</span>
          </div>
          <pre class="step-box">${escapeHtml(row["任务步骤描述"] || "")}</pre>
          ${
            issues.length
              ? `<pre class="issue-list">${escapeHtml(issues.map((text) => `- ${text}`).join("\n"))}</pre>`
              : ""
          }
        </article>
      `;
    })
    .join("");
}

async function loadSchema() {
  try {
    const health = await jsonFetch("/api/health");
    healthState.ok = Boolean(health.ok);
    healthState.qwenConfigured = Boolean(health.qwenConfigured);
    setQwenModel(health.qwenModel || currentQwenModel());
    controls.qwenEndpoint.value = health.qwenEndpoint || controls.qwenEndpoint.value;

    serverStatus.textContent = health.ok ? "后端已连接" : "后端依赖异常";
    serverStatus.classList.toggle("ok", Boolean(health.ok));
    serverStatus.classList.toggle("bad", !health.ok);
    sourceStatus.textContent = health.qwenConfigured ? `Qwen: ${currentQwenModel()}` : "Qwen: 未配置";
    setDot(qwenDot, health.qwenConfigured);
    qwenReadiness.textContent = health.qwenConfigured ? "服务端已配置" : "缺少 DASHSCOPE_API_KEY";

    const schema = await jsonFetch("/api/schema");
    schemaState = schema;
    healthState.sheetReady = Boolean(schema.ok);
    robotPresets = schema.robotPresets || [];
    normalizeTaskPhases(schema.taskPhases || {});
    syncPhaseControls({ clamp: false });
    renderRobotPresets();
    setDot(sheetDot, schema.ok);
    setDot(feishuDot, null);
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

async function handleWorkbookUpload() {
  const file = workbookFile?.files?.[0];
  if (!file) return;
  if (!file.name.toLowerCase().endsWith(".xlsx")) {
    renderNotices(["请选择 .xlsx 格式的存量数据表。"]);
    workbookFile.value = "";
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
    workbookFile.value = "";
    updateReviewSummary();
    updateNav();
  }
}

async function handleGenerate() {
  const invalid = validateReadyToGenerate();
  if (invalid) {
    renderNotices([invalid]);
    return;
  }
  setBusy(true);
  renderNotices([]);
  resultsEl.innerHTML = "";
  resultSummary.textContent = "Qwen 生成中";
  acceptedMeter.textContent = "0";
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

async function handleFeishuTest() {
  testFeishuBtn.disabled = true;
  try {
    await jsonFetch("/api/feishu/test", {
      method: "POST",
      body: JSON.stringify({ feishuWebhook: controls.feishuWebhook.value.trim() }),
    });
    setDot(feishuDot, true);
    renderNotices(["飞书 webhook 已连通。"]);
  } catch (error) {
    setDot(feishuDot, false);
    renderNotices([`飞书测试失败：${error.message}`]);
  } finally {
    testFeishuBtn.disabled = false;
    updateReviewSummary();
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
brainstormIdeasBtn.addEventListener("click", handleBrainstormIdeas);
testFeishuBtn.addEventListener("click", handleFeishuTest);
workbookFile?.addEventListener("change", handleWorkbookUpload);
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
controls.sendFeishu.addEventListener("change", () => {
  updateReviewSummary();
  updateNav();
});
controls.feishuWebhook.addEventListener("input", updateNav);

syncPhaseControls({ clamp: false });
syncQwenModelCustom();
syncGenerationCountWithIdeas();
initialRobots.forEach(addRobot);
showStep(0);
loadSchema();
