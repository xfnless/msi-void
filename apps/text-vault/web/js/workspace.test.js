import test from "node:test";
import assert from "node:assert/strict";
import {createWorkspace} from "./workspace.js";

test("tabs retain independent query selection and mobile pane", () => {
  let counter = 0;
  const workspace = createWorkspace(undefined, {idFactory: () => `tab_test_000000${++counter}`});
  workspace.setQuery("1.2.3.4");
  workspace.selectEntry("entry_1234567890");
  const first = workspace.state().activeTabId;
  workspace.pinCurrent();
  workspace.setQuery("example.com");
  workspace.showList();
  workspace.selectTab(first);

  assert.equal(workspace.state().tabs.find(tab => tab.id === first).query, "1.2.3.4");
  assert.equal(workspace.state().selectedEntryId, "entry_1234567890");
  assert.equal(workspace.state().mobilePane, "content");
});

test("durable snapshot excludes transient mobile pane and clamps split", () => {
  const workspace = createWorkspace();
  workspace.showList();
  workspace.setSplitRatio(0.9);
  const durable = workspace.durable();

  assert.equal(durable.splitRatio, 0.6);
  assert.equal("mobilePane" in durable, false);
  assert.equal(workspace.closeTab(workspace.state().activeTabId), false);
});

test("selected text opens an independent searchable tab", () => {
  let counter = 0;
  const workspace = createWorkspace(undefined, {idFactory: () => `tab_test_000000${++counter}`});
  const original = workspace.state().activeTabId;

  const opened = workspace.openSearchTab("  1.2.3.4  ");

  assert.notEqual(opened, original);
  assert.equal(workspace.state().activeTabId, opened);
  assert.equal(workspace.state().tabs.length, 2);
  assert.equal(workspace.state().tabs.find(tab => tab.id === opened).query, "1.2.3.4");
  assert.equal(workspace.state().mobilePane, "list");
});

test("every tab can close while one workspace tab always remains", () => {
  let counter = 0;
  const workspace = createWorkspace(undefined, {idFactory: () => `tab_test_000000${++counter}`});
  const first = workspace.state().activeTabId;
  const second = workspace.openSearchTab("second");
  const third = workspace.openSearchTab("third");

  assert.equal(workspace.closeTab(second), true);
  assert.equal(workspace.closeTab(third), true);
  assert.equal(workspace.state().activeTabId, first);
  assert.equal(workspace.state().tabs.length, 1);
  assert.equal(workspace.closeTab(first), false);
});
