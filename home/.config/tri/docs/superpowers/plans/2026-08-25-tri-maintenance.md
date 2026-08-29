# tri Maintenance Implementation Plan

> Historical plan: the special slot 0 requirements below were superseded when tri was simplified to a strict two-window layout.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve tri's observable behavior while making its state transitions, geometry, Wayland resources, configuration, and recovery workflow safe enough for long-term personal use.

**Architecture:** Extract compositor-independent state and geometry into testable Zig modules while keeping `main.zig` as the River adapter. Harden configuration at load boundaries, give shm buffers explicit busy/release ownership, and keep protocol results observable without adding runtime features.

**Tech Stack:** Zig 0.16, zig-wayland, River 0.4 `river-window-management-v1` v4, Wayland shm, fcft, pixman.

**Spec:** `docs/superpowers/specs/2026-08-25-tri-maintenance-design.md`

## Global Constraints

- No new user-facing features.
- Preserve all existing key bindings; the special-slot binding is `Super+'` (`XKB_KEY_apostrophe`).
- Preserve left-master/accordion semantics, monocle, hide-chrome, mirrored columns, and special slot 0.
- Official support remains single-output and single-seat.
- Every production behavior change starts with a failing test.
- Each task must pass `zig build test` and `zig build -Doptimize=ReleaseSafe` before commit.

---

### Task 1: Validated configuration and safe geometry

**Files:**
- Modify: `src/config.zig`
- Create: `src/layout.zig`
- Modify: `build.zig`
- Modify: `src/main.zig`

**Interfaces:**
- Produces: `Config.validate() void`, `layout.columns(i32, f32, bool) Columns`, and `layout.accordion(i32, usize, usize, i32, bool, f32, []Row) usize`.
- `Columns` contains `master_x`, `master_w`, `stack_x`, and `stack_w`.
- `Row` contains `y`, `height`, and `expanded`.

- [x] Write Zig tests proving ratios outside `(0, 1)`, NaN, infinity, and cursor size zero revert to defaults.
- [x] Run `zig build test` and verify failure because validation does not exist.
- [x] Implement `Config.validate()` and call it after loading.
- [x] Run tests and verify configuration tests pass.
- [x] Write layout tests for normal/mirrored columns, normal/special accordion, tiny outputs, and more chips than fit.
- [x] Run tests and verify failure because `src/layout.zig` does not exist.
- [x] Implement saturating geometry that never returns negative sizes or extends beyond output height.
- [x] Replace arithmetic in `main.zig` with the tested layout functions without changing ordinary-screen results.
- [x] Run `zig build test` and both Debug and ReleaseSafe builds.
- [x] Commit as `refactor: validate configuration and isolate geometry`.

### Task 2: Pure window state model

**Files:**
- Create: `src/model.zig`
- Modify: `src/main.zig`
- Modify: `build.zig`

**Interfaces:**
- Produces: generic `Model(comptime WindowId: type)` with `master`, `stack`, `expanded`, `focus_side`, `monocle`, `stack_on_left`, and `special_0`.
- Produces mutation methods `adopt`, `detach`, `moveBy`, `moveTo`, `swapMaster`, `expandBy`, `expandTo`, `toggleFocus`, and `normalize`.
- All mutations preserve: no duplicate window IDs, `expanded == 0` for an empty stack, `expanded < stack.len` otherwise, and `special_0 == false` below two stack items.

- [x] Write state tests capturing current insertion, close/promotion, move, swap, focus, and special-slot behavior.
- [x] Run tests and verify failure because `Model` does not exist.
- [x] Implement the minimum model needed to pass each test, one mutation at a time.
- [x] Adapt `WindowManager` to delegate state mutations to the model while keeping River object ownership in `main.zig`.
- [x] Run all tests and Debug/ReleaseSafe builds after each migrated mutation group.
- [x] Commit as `refactor: extract tested window state model`.

### Task 3: Protocol-safe titlebar buffers

**Files:**
- Create: `src/buffer_state.zig`
- Modify: `src/titlebar.zig`
- Modify: `build.zig`

**Interfaces:**
- Produces: `BufferState` with states `available`, `busy`, and `retired` and transitions `attached`, `released`, and `retire`.
- `Chip` owns at least two buffer slots; an attached slot is never rewritten, unmapped, or destroyed before its `wl_buffer.release` event.

- [x] Write transition tests proving busy buffers cannot be reused and retired buffers are freed only after release.
- [x] Run tests and verify failure because `BufferState` does not exist.
- [x] Implement the transition model.
- [x] Replace the single mutable shm allocation in `Chip` with two listener-backed slots.
- [x] Ensure chip destruction retires busy slots and destroys available slots immediately; release callbacks finish deferred cleanup.
- [x] Add rate-limited error logging for font, shm allocation, and paint failures while preserving graceful degradation.
- [x] Run all tests, Debug build, and ReleaseSafe build.
- [x] Commit as `fix: honor Wayland buffer release lifecycle`.

### Task 4: Protocol cleanup, documentation, and recovery workflow

**Files:**
- Modify: `src/input.zig`
- Modify: `CODE.md`
- Modify: `DESIGN.md`
- Modify: `rebuild.sh`
- Create: `README.md`

**Interfaces:**
- Libinput result listener handles `.success`, `.unsupported`, and `.invalid` destructor events and logs non-success results.
- `rebuild.sh` runs tests and ReleaseSafe build before atomically installing `tri`, retaining `tri.previous` when an installed binary exists.

- [x] Confirm generated Zig semantics for destructor events and write a compile-time listener implementation that handles every result event.
- [x] Replace the ignored result listener with success/error handling and verify the project builds.
- [x] Correct all `Super+\`` references to `Super+'` and document the frozen feature boundary and single-output support.
- [x] Update the build step so tests run before ReleaseSafe output replaces the daily binary; use same-filesystem rename and retain one previous executable.
- [x] Run `zig fmt --check build.zig src/*.zig`, `zig build test`, `zig build`, `zig build -Doptimize=ReleaseSafe`, and `sh -n rebuild.sh session.sh`.
- [x] Confirm `git status` contains only intended source and documentation changes.
- [x] Commit as `chore: document and verify long-term maintenance workflow`.

### Task 5: Final compatibility audit

**Files:**
- Modify only files required by audit findings.

**Interfaces:**
- No new interfaces; this task validates the completed system against the design spec.

- [x] Compare every binding and action in the baseline commit `27798f9` with the final implementation.
- [x] Compare normal-layout geometry on the configured 2560x1600 output for representative stack sizes 0, 1, 2, 5, and 10.
- [x] Run the full verification command set from Task 4 with clean output.
- [x] Inspect all Wayland object creation sites for an ownership and destruction path.
- [x] Record anything requiring a live River session as an explicit manual smoke-test checklist in `README.md`.
- [x] Commit audit fixes as `fix: close maintenance audit findings` if changes are required.
