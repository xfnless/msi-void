import {validateObject} from "./model.js";

export function createRepository(initialObjects = []) {
  const objects = new Map();
  const sequences = new Map();
  const committedSequences = new Map();
  const baseRevisions = new Map();
  const contentDirty = new Map();
  const subscribers = new Set();

  for (const value of initialObjects) {
    const object = structuredClone(validateObject(value));
    objects.set(object.id, object);
    sequences.set(object.id, 0);
    committedSequences.set(object.id, 0);
    baseRevisions.set(object.id, object.revision);
    contentDirty.set(object.id, false);
  }

  function get(id) {
    return objects.get(id);
  }

  // Quiet objects (workspace/layout) join the next persistence batch without
  // presenting themselves as unsaved user content.
  function upsert(value, {quiet = false} = {}) {
    const object = structuredClone(validateObject(value));
    const nextSequence = (sequences.get(object.id) ?? 0) + 1;
    objects.set(object.id, object);
    sequences.set(object.id, nextSequence);
    if (!committedSequences.has(object.id)) committedSequences.set(object.id, -1);
    if (!baseRevisions.has(object.id)) baseRevisions.set(object.id, object.revision);
    if (!quiet) contentDirty.set(object.id, true);
    notify({type: "upsert", id: object.id});
    return object;
  }

  function updateEntryText(id, text, now = new Date().toISOString()) {
    const current = objects.get(id);
    if (!current || current.kind !== "entry") throw new TypeError("entry not found");
    if (current.text === text) return current;
    return upsert({...current, text, updatedAt: now});
  }

  function remove(id) {
    if (!objects.has(id)) return false;
    objects.delete(id);
    sequences.set(id, (sequences.get(id) ?? 0) + 1);
    notify({type: "remove", id});
    return true;
  }

  function search(query) {
    const needle = String(query ?? "").trim().toLocaleLowerCase();
    return [...objects.values()]
      .filter(object => object.kind === "entry" && (!needle || object.text.toLocaleLowerCase().includes(needle)))
      .sort((left, right) => right.updatedAt.localeCompare(left.updatedAt))
      .map(object => ({id: object.id, updatedAt: object.updatedAt, snippet: snippet(object.text, needle)}));
  }

  function isDirty() {
    return isContentDirty();
  }

  function isContentDirty() {
    return [...contentDirty.values()].some(Boolean);
  }

  function hasPendingChanges() {
    return [...sequences].some(([id, sequence]) => sequence !== committedSequences.get(id));
  }

  function dirtyObjects() {
    return captureDirty().map(item => item.object);
  }

  function captureDirty() {
    const result = [];
    for (const [id, sequence] of sequences) {
      if (sequence === committedSequences.get(id)) continue;
      const object = objects.get(id);
      if (object) result.push({id, sequence, baseRevision: baseRevisions.get(id) ?? 0, object: structuredClone(object)});
    }
    return result;
  }

  function markCommitted(snapshot, returnedRevisions) {
    for (const captured of snapshot) {
      const revision = returnedRevisions[captured.id];
      if (!Number.isSafeInteger(revision)) continue;
      baseRevisions.set(captured.id, revision);
      const current = objects.get(captured.id);
      if (current) objects.set(captured.id, {...current, revision});
      if (sequences.get(captured.id) === captured.sequence) {
        committedSequences.set(captured.id, captured.sequence);
        contentDirty.set(captured.id, false);
      }
    }
    notify({type: "commit"});
  }

  function subscribe(callback) {
    subscribers.add(callback);
    return () => subscribers.delete(callback);
  }

  function notify(event) {
    for (const subscriber of subscribers) subscriber(event);
  }

  return {get, upsert, remove, search, isDirty, isContentDirty, hasPendingChanges, dirtyObjects, captureDirty, markCommitted, updateEntryText, subscribe, values: () => [...objects.values()]};
}

function snippet(value, needle) {
  const compact = value.replace(/\s+/g, " ").trim();
  if (!compact) return "空白条目";
  if (!needle) return compact.slice(0, 120);
  const index = compact.toLocaleLowerCase().indexOf(needle);
  const start = Math.max(0, index - 30);
  return `${start > 0 ? "…" : ""}${compact.slice(start, start + 120)}${start + 120 < compact.length ? "…" : ""}`;
}
