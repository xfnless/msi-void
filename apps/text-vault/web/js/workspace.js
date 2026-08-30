import {newID} from "./model.js";

export function createWorkspace(initial, {idFactory = () => newID("tab")} = {}) {
  const subscribers = new Set();
  const source = initial?.state ?? initial;
  const firstTab = {id: idFactory(), query: "", selectedEntryId: null, listScrollTop: 0, pinned: false};
  let durableState = source ? normalize(source) : {
    schemaVersion: 1,
    activeTabId: firstTab.id,
    tabs: [firstTab],
    splitRatio: 0.36,
    theme: "warm-paper",
  };
  let mobilePane = selectedTab().selectedEntryId ? "content" : "list";

  function state() {
    const active = selectedTab();
    return {...structuredClone(durableState), selectedEntryId: active.selectedEntryId, mobilePane};
  }

  function durable() {
    return structuredClone(durableState);
  }

  function setQuery(query) {
    updateActive(tab => ({...tab, query: String(query), listScrollTop: 0}));
  }

  function selectEntry(id) {
    updateActive(tab => ({...tab, selectedEntryId: id}));
    mobilePane = "content";
    notify();
  }

  function pinCurrent() {
    updateActive(tab => ({...tab, pinned: true}));
    const scratch = {id: idFactory(), query: "", selectedEntryId: null, listScrollTop: 0, pinned: false};
    durableState = {...durableState, activeTabId: scratch.id, tabs: [...durableState.tabs, scratch]};
    mobilePane = "list";
    notify();
    return scratch.id;
  }

  // Searches opened from selected text use the same durable tab model as all
  // other work, so save, restore and close behavior stay unsurprising.
  function openSearchTab(query) {
    const normalizedQuery = String(query).trim();
    if (!normalizedQuery) return null;
    const tab = {id: idFactory(), query: normalizedQuery, selectedEntryId: null, listScrollTop: 0, pinned: false};
    durableState = {...durableState, activeTabId: tab.id, tabs: [...durableState.tabs, tab]};
    mobilePane = "list";
    notify();
    return tab.id;
  }

  function selectTab(id) {
    if (!durableState.tabs.some(tab => tab.id === id)) return false;
    durableState = {...durableState, activeTabId: id};
    mobilePane = selectedTab().selectedEntryId ? "content" : "list";
    notify();
    return true;
  }

  function closeTab(id) {
    if (durableState.tabs.length === 1) return false;
    const index = durableState.tabs.findIndex(tab => tab.id === id);
    if (index < 0) return false;
    const tabs = durableState.tabs.filter(tab => tab.id !== id);
    const activeTabId = durableState.activeTabId === id ? tabs[Math.max(0, index - 1)].id : durableState.activeTabId;
    durableState = {...durableState, activeTabId, tabs};
    mobilePane = selectedTab().selectedEntryId ? "content" : "list";
    notify();
    return true;
  }

  function showList() {
    mobilePane = "list";
    notify();
  }

  function setSplitRatio(value) {
    durableState = {...durableState, splitRatio: Math.min(0.6, Math.max(0.25, Number(value)))};
    notify();
  }

  function setListScroll(value) {
    updateActive(tab => ({...tab, listScrollTop: Math.max(0, Number(value) || 0)}));
  }

  function subscribe(callback) {
    subscribers.add(callback);
    return () => subscribers.delete(callback);
  }

  function selectedTab() {
    return durableState.tabs.find(tab => tab.id === durableState.activeTabId) ?? durableState.tabs[0];
  }

  function updateActive(transform) {
    durableState = {...durableState, tabs: durableState.tabs.map(tab => tab.id === durableState.activeTabId ? transform(tab) : tab)};
    notify();
  }

  function notify() {
    for (const subscriber of subscribers) subscriber(state());
  }

  return {state, durable, setQuery, selectEntry, pinCurrent, openSearchTab, selectTab, closeTab, showList, setSplitRatio, setListScroll, subscribe};
}

function normalize(value) {
  if (!value || value.schemaVersion !== 1 || !Array.isArray(value.tabs) || value.tabs.length === 0) {
    throw new TypeError("invalid workspace");
  }
  const tabs = value.tabs.map(tab => ({
    id: String(tab.id),
    query: String(tab.query ?? ""),
    selectedEntryId: tab.selectedEntryId ?? null,
    listScrollTop: Math.max(0, Number(tab.listScrollTop) || 0),
    pinned: Boolean(tab.pinned),
  }));
  return {
    schemaVersion: 1,
    activeTabId: tabs.some(tab => tab.id === value.activeTabId) ? value.activeTabId : tabs[0].id,
    tabs,
    splitRatio: Math.min(0.6, Math.max(0.25, Number(value.splitRatio) || 0.36)),
    theme: value.theme === "warm-paper" ? value.theme : "warm-paper",
  };
}
