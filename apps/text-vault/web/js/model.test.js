import test from "node:test";
import assert from "node:assert/strict";
import {createEntry, validateObject} from "./model.js";

test("createEntry returns a schema-versioned untitled text object", () => {
  const entry = createEntry({id: "entry_1234567890", now: "2026-08-29T00:00:00.000Z"});
  assert.deepEqual(entry, {
    schemaVersion: 1,
    id: "entry_1234567890",
    kind: "entry",
    text: "",
    properties: {},
    createdAt: "2026-08-29T00:00:00.000Z",
    updatedAt: "2026-08-29T00:00:00.000Z",
    revision: 0,
  });
  assert.equal(validateObject(entry), entry);
});
