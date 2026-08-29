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
