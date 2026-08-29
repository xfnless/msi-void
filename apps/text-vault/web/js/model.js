const ID_PATTERN = /^[A-Za-z0-9_-]{16,80}$/;
const KINDS = new Set(["entry", "workspace", "query", "view"]);

export function createEntry({id = newID("entry"), now = new Date().toISOString()} = {}) {
  return {
    schemaVersion: 1,
    id,
    kind: "entry",
    text: "",
    properties: {},
    createdAt: now,
    updatedAt: now,
    revision: 0,
  };
}

export function validateObject(value) {
  if (!value || typeof value !== "object" || Array.isArray(value) || value.schemaVersion !== 1 ||
      !ID_PATTERN.test(value.id) || !KINDS.has(value.kind) ||
      !Number.isSafeInteger(value.revision) || value.revision < 0) {
    throw new TypeError("invalid object");
  }
  if (value.kind === "entry" && (typeof value.text !== "string" || !isPlainObject(value.properties) ||
      typeof value.createdAt !== "string" || typeof value.updatedAt !== "string")) {
    throw new TypeError("invalid entry");
  }
  return value;
}

export function newID(prefix) {
  const random = crypto.getRandomValues(new Uint8Array(16));
  const suffix = Array.from(random, value => value.toString(16).padStart(2, "0")).join("");
  return `${prefix}_${suffix}`;
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
