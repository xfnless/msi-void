import test from "node:test";
import assert from "node:assert/strict";
import {createRepository} from "./repository.js";

const initial = {
  schemaVersion: 1,
  id: "entry_1234567890",
  kind: "entry",
  text: "客户A old",
  properties: {},
  createdAt: "2026-08-29T00:00:00.000Z",
  updatedAt: "2026-08-29T00:00:00.000Z",
  revision: 1,
};

test("unsaved edits immediately change search results", () => {
  const repository = createRepository([initial]);
  assert.equal(repository.search("1.2.3.4").length, 0);

  repository.updateEntryText("entry_1234567890", "客户A 1.2.3.4", "2026-08-29T01:00:00.000Z");

  assert.equal(repository.search("1.2.3.4")[0].id, "entry_1234567890");
  assert.equal(repository.isDirty(), true);
  assert.equal(repository.dirtyObjects().length, 1);
});

test("typing during save remains dirty after older snapshot commits", () => {
  const repository = createRepository([initial]);
  repository.updateEntryText("entry_1234567890", "first", "2026-08-29T01:00:00.000Z");
  const snapshot = repository.captureDirty();
  repository.updateEntryText("entry_1234567890", "second", "2026-08-29T02:00:00.000Z");

  repository.markCommitted(snapshot, {entry_1234567890: 2});

  assert.equal(repository.get("entry_1234567890").text, "second");
  assert.equal(repository.isDirty(), true);
});

test("empty query returns newest entries first and search is case insensitive", () => {
  const repository = createRepository([
    initial,
    {...initial, id: "entry_second_0001", text: "Example.COM", updatedAt: "2026-08-29T03:00:00.000Z"},
  ]);
  assert.equal(repository.search("")[0].id, "entry_second_0001");
  assert.equal(repository.search("example.com")[0].id, "entry_second_0001");
});
