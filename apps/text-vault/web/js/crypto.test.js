import test from "node:test";
import assert from "node:assert/strict";
import {
  createVault,
  unlockVault,
  encryptObject,
  decryptObject,
} from "./crypto.js";

test("correct password decrypts an object", async () => {
  const {header, key} = await createVault("a long unique passphrase");
  const metadata = {id: "entry_1234567890", kind: "entry", revision: 1};
  const envelope = await encryptObject(key, metadata, {text: "1.2.3.4 客户A"});
  const unlocked = await unlockVault("a long unique passphrase", header);

  assert.deepEqual(await decryptObject(unlocked, metadata, envelope), {text: "1.2.3.4 客户A"});
});

test("wrong password and modified metadata fail authentication", async () => {
  const {header, key} = await createVault("a long unique passphrase");
  await assert.rejects(() => unlockVault("wrong password", header));

  const metadata = {id: "entry_1234567890", kind: "entry", revision: 1};
  const envelope = await encryptObject(key, metadata, {text: "secret"});
  await assert.rejects(() => decryptObject(key, {...metadata, revision: 2}, envelope));
});
