import test from "node:test";
import assert from "node:assert/strict";
import {createRepository} from "./repository.js";
import {createSaveCoordinator} from "./save.js";

function seededRepository() {
  return createRepository([{
    schemaVersion: 1, id: "entry_1234567890", kind: "entry", text: "base", properties: {},
    createdAt: "2026-08-29T00:00:00.000Z", updatedAt: "2026-08-29T00:00:00.000Z", revision: 1,
  }]);
}

test("one save commits every dirty object and preserves edits made in flight", async () => {
  const pending = Promise.withResolvers();
  let submitted;
  const api = {commit: request => { submitted = request; return pending.promise; }};
  const key = await crypto.subtle.generateKey({name: "AES-GCM", length: 256}, false, ["encrypt", "decrypt"]);
  const repository = seededRepository();
  repository.updateEntryText("entry_1234567890", "first edit", "2026-08-29T01:00:00.000Z");
  const saver = createSaveCoordinator({repository, api, key, generation: 3});

  const saving = saver.save();
  repository.updateEntryText("entry_1234567890", "second edit", "2026-08-29T02:00:00.000Z");
  pending.resolve({manifest: {generation: 4, objects: {entry_1234567890: {kind: "entry", revision: 2}}}});
  await saving;

  assert.equal(submitted.baseGeneration, 3);
  assert.equal(submitted.objects.length, 1);
  assert.equal(saver.status(), "dirty");
  assert.equal(repository.get("entry_1234567890").text, "second edit");
});

test("conflict preserves memory and exposes one global state", async () => {
  const repository = seededRepository();
  repository.updateEntryText("entry_1234567890", "local", "2026-08-29T01:00:00.000Z");
  const key = await crypto.subtle.generateKey({name: "AES-GCM", length: 256}, false, ["encrypt", "decrypt"]);
  const error = new Error("conflict");
  error.name = "ConflictError";
  const saver = createSaveCoordinator({repository, key, generation: 1, api: {commit: async () => { throw error; }}});

  await assert.rejects(() => saver.save(), /conflict/);

  assert.equal(saver.status(), "conflict");
  assert.equal(repository.get("entry_1234567890").text, "local");
});
