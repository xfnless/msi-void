import test from "node:test";
import assert from "node:assert/strict";
import {createAPI} from "./api.js";

test("setup and login send only a derived credential to authentication endpoints", async () => {
  const requests = [];
  const api = createAPI(async (path, options) => {
    requests.push({path, body: JSON.parse(options.body)});
    return new Response(JSON.stringify({csrfToken: "csrf"}), {status: 200, headers: {"Content-Type": "application/json"}});
  });

  await api.setup({schemaVersion: 1}, "derived-credential");
  await api.login("derived-credential");

  assert.deepEqual(requests, [
    {path: "/api/setup", body: {header: {schemaVersion: 1}, credential: "derived-credential"}},
    {path: "/api/login", body: {credential: "derived-credential"}},
  ]);
});
