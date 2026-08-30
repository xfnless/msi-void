import {encryptObject} from "./crypto.js";

export function createSaveCoordinator({repository, api, key, generation = 0}) {
  let currentGeneration = generation;
  let currentStatus = repository.isContentDirty() ? "dirty" : "clean";
  let activeSave = null;
  const subscribers = new Set();

  repository.subscribe(() => {
    if (!activeSave && currentStatus !== "conflict" && currentStatus !== "failed") {
      setStatus(repository.isContentDirty() ? "dirty" : "clean");
    }
  });

  function save() {
    if (activeSave) return activeSave;
    // captureDirty includes quiet workspace changes. The status shown to the
    // user is computed separately from content dirtiness below.
    const captured = repository.captureDirty();
    if (captured.length === 0) {
      setStatus("clean");
      return Promise.resolve({generation: currentGeneration});
    }
    setStatus("saving");
    activeSave = perform(captured).finally(() => { activeSave = null; });
    return activeSave;
  }

  async function perform(captured) {
    try {
      const objects = await Promise.all(captured.map(async item => {
        const revision = item.baseRevision + 1;
        const value = {...item.object, revision};
        const metadata = {id: value.id, kind: value.kind, revision};
        return {...metadata, envelope: await encryptObject(key, metadata, value)};
      }));
      const response = await api.commit({baseGeneration: currentGeneration, objects});
      currentGeneration = response.manifest.generation;
      const revisions = Object.fromEntries(Object.entries(response.manifest.objects).map(([id, ref]) => [id, ref.revision]));
      repository.markCommitted(captured, revisions);
      setStatus(repository.isContentDirty() ? "dirty" : "clean");
      return response.manifest;
    } catch (error) {
      setStatus(error?.name === "ConflictError" ? "conflict" : "failed");
      throw error;
    }
  }

  function setStatus(value) {
    currentStatus = value;
    for (const subscriber of subscribers) subscriber(value);
  }

  function subscribe(callback) {
    subscribers.add(callback);
    return () => subscribers.delete(callback);
  }

  return {save, status: () => currentStatus, generation: () => currentGeneration, subscribe};
}
