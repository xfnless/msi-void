import test from "node:test";
import assert from "node:assert/strict";
import {
  createVault,
  deriveVaultAccess,
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

test("one password derives a stable server credential separately from the data key", async () => {
  const created = await createVault("a long unique passphrase");
  const first = await deriveVaultAccess("a long unique passphrase", created.header);
  const second = await deriveVaultAccess("a long unique passphrase", created.header);

  assert.equal(created.credential, first.credential);
  assert.equal(first.credential, second.credential);
  assert.match(first.credential, /^[A-Za-z0-9_-]{43}$/);
  assert.notEqual(first.credential, created.header.wrap.ciphertext);
});

test("wrong password and modified metadata fail authentication", async () => {
  const {header, key} = await createVault("a long unique passphrase");
  await assert.rejects(() => unlockVault("wrong password", header));

  const metadata = {id: "entry_1234567890", kind: "entry", revision: 1};
  const envelope = await encryptObject(key, metadata, {text: "secret"});
  await assert.rejects(() => decryptObject(key, {...metadata, revision: 2}, envelope));
});
