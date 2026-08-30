import van from "../vendor/van-1.6.1.js";
import {createAPI, APIError} from "./api.js";
import {createVault, decryptObject, deriveVaultAccess} from "./crypto.js";
import {createEntry, validateObject} from "./model.js";
import {createRepository} from "./repository.js";
import {createSaveCoordinator} from "./save.js";
import {createWorkspace} from "./workspace.js";

const {button, div, form, h1, input, label, main, p, section, span, textarea} = van.tags;
const root = document.querySelector("#app");
const api = createAPI();

initialize();

async function initialize() {
  try {
    renderUnlock(await api.vault());
  } catch (cause) {
    if (cause instanceof APIError && cause.status === 404) renderSetup();
    else mount(authShell("无法连接", "暂时无法读取保险库。", button({type: "button", class: "primary", onclick: initialize}, "重试")));
  }
}

function renderSetup() {
  const error = van.state("");
  const password = input({type: "password", autocomplete: "new-password", minlength: 12, required: true});
  const repeated = input({type: "password", autocomplete: "new-password", minlength: 12, required: true});
  const submit = button({type: "submit", class: "primary"}, "创建保险库");
  mount(authShell("创建保险库", "主密码只在这个浏览器中用于解密，服务器不会收到它。", form({onsubmit: async event => {
    event.preventDefault();
    if (password.value !== repeated.value) { error.val = "两次主密码不一致"; return; }
    submit.disabled = true;
    error.val = "正在生成密钥…";
    try {
      const created = await createVault(password.value);
      await api.setup(created.header, created.credential);
      await openWorkspace(created.key, {manifest: {generation: 0, objects: {}}, objects: {}});
    } catch (cause) {
      error.val = cause?.message || "创建失败";
      submit.disabled = false;
    }
  }}, label({class: "field"}, span("新主密码"), password), label({class: "field"}, span("重复主密码"), repeated), p({class: "form-error", role: "alert"}, error), submit)));
  password.focus();
}

function renderUnlock(header) {
  const error = van.state("");
  const password = input({type: "password", autocomplete: "current-password", required: true});
  const submit = button({type: "submit", class: "primary"}, "解锁");
  mount(authShell("解锁保险库", "明文仅存在于当前页面内存。", form({onsubmit: async event => {
    event.preventDefault();
    submit.disabled = true;
    error.val = "正在解锁…";
    try {
      const access = await deriveVaultAccess(password.value, header);
      await api.login(access.credential);
      await openWorkspace(access.key, await api.snapshot());
    } catch {
      error.val = "主密码不正确，或保险库数据已损坏";
      submit.disabled = false;
    }
  }}, label({class: "field"}, span("主密码"), password), p({class: "form-error", role: "alert"}, error), submit)));
  password.focus();
}

async function openWorkspace(key, snapshot) {
  const decrypted = [];
  for (const encrypted of Object.values(snapshot.objects ?? {})) {
    const metadata = {id: encrypted.id, kind: encrypted.kind, revision: encrypted.revision};
    decrypted.push(validateObject(await decryptObject(key, metadata, encrypted.envelope)));
  }
  const repository = createRepository(decrypted);
  let workspaceObject = decrypted.find(object => object.kind === "workspace");
  const workspace = createWorkspace(workspaceObject?.state);
  if (!workspaceObject) {
    workspaceObject = {schemaVersion: 1, id: "workspace_main_01", kind: "workspace", revision: 0, state: workspace.durable()};
    repository.upsert(workspaceObject);
  }
  const saver = createSaveCoordinator({repository, api, key, generation: snapshot.manifest?.generation ?? 0});
  renderApplication({repository, workspace, saver, workspaceID: workspaceObject.id});
}

function renderApplication({repository, workspace, saver, workspaceID}) {
  const repositoryTick = van.state(0);
  const workspaceState = van.state(workspace.state());
  const saveState = van.state(saver.status());
  const message = van.state("");
  const content = textarea({class: "editor", "aria-label": "条目内容", spellcheck: false, oninput: event => {
    const id = workspace.state().selectedEntryId;
    if (id) repository.updateEntryText(id, event.target.value);
  }});

  const syncEditor = () => {
    const selected = workspace.state().selectedEntryId;
    const object = selected ? repository.get(selected) : null;
    content.disabled = !object;
    content.placeholder = object ? "直接输入内容" : "从左侧选择条目，或新建一条";
    if (content.dataset.objectId !== (selected ?? "")) content.value = object?.text ?? "";
    content.dataset.objectId = selected ?? "";
  };

  workspace.subscribe(state => {
    workspaceState.val = state;
    repository.upsert({...repository.get(workspaceID), state: workspace.durable()});
    syncEditor();
  });
  repository.subscribe(() => { repositoryTick.val++; });
  saver.subscribe(status => { saveState.val = status; });

  const searchBox = input({type: "search", class: "search-input", "aria-label": "搜索条目", autocomplete: "off", autocapitalize: "off", spellcheck: false, placeholder: "搜索 IP、域名、客户……", value: () => activeTab(workspaceState.val).query, oninput: event => workspace.setQuery(event.target.value)});
  const newEntry = () => {
    const entry = createEntry();
    repository.upsert(entry);
    workspace.selectEntry(entry.id);
    queueMicrotask(() => content.focus());
  };
  const resultList = () => {
    repositoryTick.val;
    const current = activeTab(workspaceState.val);
    const results = repository.search(current.query);
    return div({class: "results", role: "listbox", "aria-label": "搜索结果"}, results.length === 0 ? p({class: "empty"}, "没有匹配条目") : results.map(result => button({type: "button", class: `result-row${result.id === current.selectedEntryId ? " selected" : ""}`, role: "option", "aria-selected": result.id === current.selectedEntryId, "aria-label": result.snippet, onclick: () => workspace.selectEntry(result.id)}, span({class: "result-text"}, result.snippet), span({class: "result-time"}, shortDate(result.updatedAt)))));
  };
  const tabs = () => {
    const state = workspaceState.val;
    return div({class: "tabs-track"}, state.tabs.map(tab => div({class: `tab${tab.id === state.activeTabId ? " active" : ""}`}, button({type: "button", class: "tab-select", onclick: () => workspace.selectTab(tab.id), title: tab.query || "全部条目"}, tab.query || "全部条目"), tab.pinned ? button({type: "button", class: "tab-close", "aria-label": `取消固定 ${tab.query || "全部条目"}`, title: "取消固定", onclick: event => { event.stopPropagation(); workspace.closeTab(tab.id); }}, "×") : null)));
  };
  const doSave = async () => {
    message.val = "";
    try { await saver.save(); }
    catch (cause) { message.val = cause?.name === "ConflictError" ? "服务器已有新版本，本地内容未被覆盖。" : "保存失败，本地内容仍在当前页面内存中。"; }
  };
  window.addEventListener("beforeunload", event => {
    if (repository.isDirty()) { event.preventDefault(); event.returnValue = ""; }
  });
  const resizeFromPointer = event => {
    const area = event.currentTarget.parentElement;
    const bounds = area.getBoundingClientRect();
    const move = pointer => workspace.setSplitRatio((pointer.clientX - bounds.left) / bounds.width);
    const stop = () => {
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", stop);
      document.body.classList.remove("resizing");
    };
    document.body.classList.add("resizing");
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", stop, {once: true});
    move(event);
  };

  mount(main({class: "app-shell"},
    section({class: "topbar"}, button({type: "button", class: "mobile-back", onclick: () => workspace.showList(), "aria-label": "返回结果"}, "返回"), div({class: "search-wrap"}, searchBox), div({class: "top-actions"}, span({class: () => `save-state ${saveState.val}`}, () => statusLabel(saveState.val)), button({type: "button", class: "save-button", onclick: doSave, disabled: () => saveState.val === "saving"}, "保存"))),
    div({class: "work-area", style: () => `--list-ratio:${workspaceState.val.splitRatio}`},
      section({class: () => `list-pane ${workspaceState.val.mobilePane === "list" ? "mobile-active" : ""}`}, div({class: "list-tools"}, button({type: "button", class: "new-button", onclick: newEntry, "aria-label": "新建条目"}, "＋ 新建"), span({class: "result-count"}, () => `${repository.search(activeTab(workspaceState.val).query).length} 条`)), van.derive(resultList)),
      div({class: "divider", role: "separator", tabindex: "0", "aria-label": "调整列表宽度", "aria-orientation": "vertical", "aria-valuemin": "25", "aria-valuemax": "60", "aria-valuenow": () => String(Math.round(workspaceState.val.splitRatio * 100)), onpointerdown: resizeFromPointer, onkeydown: event => {
        if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
          event.preventDefault();
          workspace.setSplitRatio(workspace.state().splitRatio + (event.key === "ArrowLeft" ? -0.02 : 0.02));
        }
      }}),
      section({class: () => `content-pane ${workspaceState.val.mobilePane === "content" ? "mobile-active" : ""}`}, div({class: "editor-meta"}, span(() => workspaceState.val.selectedEntryId ? "纯文本条目" : "未选择条目"), span({class: "global-message", role: "status"}, message)), content)),
    section({class: "tabbar", "aria-label": "查询标签"}, van.derive(tabs), button({type: "button", class: "pin-button", "aria-label": "固定当前搜索", onclick: () => workspace.pinCurrent(), title: "固定当前搜索"}, "固定 ＋"))));
  syncEditor();
  searchBox.focus();
}

function authShell(title, subtitle, body) {
  return main({class: "auth-shell"}, section({class: "auth-paper"}, div({class: "brand-mark", "aria-hidden": "true"}, "T"), h1(title), p({class: "auth-subtitle"}, subtitle), body));
}
function activeTab(state) { return state.tabs.find(tab => tab.id === state.activeTabId) ?? state.tabs[0]; }
function statusLabel(status) { return ({clean: "已保存", dirty: "未保存", saving: "保存中…", failed: "保存失败", conflict: "版本冲突"})[status] ?? "未保存"; }
function shortDate(value) { const date = new Date(value); return Number.isNaN(date.valueOf()) ? "" : new Intl.DateTimeFormat("zh-CN", {month: "2-digit", day: "2-digit"}).format(date); }
function mount(node) { root.replaceChildren(); van.add(root, node); }
