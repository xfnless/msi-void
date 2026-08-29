# Portable tri Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the tracked tri source, binary and session portable across AMD and Intel Void Linux glibc x86_64 machines by moving device/application choices into `config` and forcing a baseline x86_64 build.

**Architecture:** `config.zig` stores ordered startup commands alongside bindings; tri launches them after installing its child reaper. `session.sh` parses only pre-WM environment/output settings without sourcing configuration. `rebuild.sh` cross-targets baseline x86_64 glibc and verifies the ELF before atomically replacing the tracked binary.

**Tech Stack:** Zig 0.16, POSIX shell, River 0.4, Wayland, xkbcommon, fcft, pixman

**Spec:** `docs/superpowers/specs/2026-08-29-portable-project-design.md`

## Global Constraints

- Keep source, scripts, config and the tracked binary inside `home/.config/tri`.
- Support Void Linux glibc x86_64 on baseline AMD and Intel CPUs; musl and other architectures are out of scope.
- Keep runtime libraries as system dependencies; add no release package or bundled libraries.
- Remove device/application choices and `/home/xiang` paths from Zig and shell code.
- Preserve all window-management behavior and existing config behavior.
- Bad optional config must warn or skip without preventing River startup.

---

### Task 1: Ordered startup command configuration

**Files:**
- Modify: `src/config.zig`
- Modify: `src/tests.zig`
- Modify: `src/main.zig`

**Interfaces:**
- Produces: `Config.startup_specs: ArrayListUnmanaged(CommandSpec)` where `CommandSpec` contains `label` and `command` slices owned by `Config.strings`.
- Consumes: existing `spawnSh([]const u8)` and installed child reaper.

- [ ] Add tests applying `start.audio = exec pipewire`, `start.input = exec fcitx5`, an empty command and a binding; assert startup order, arbitrary labels and binding coexistence.
- [ ] Run `zig build test --summary all`; expect failure because `startup_specs` does not exist.
- [ ] Add `CommandSpec`, ordered storage and deinit handling to `config.zig`; store every `start.<nonempty-label>` entry and let empty values remain available for validation.
- [ ] Add `startConfiguredCommands()` in `main.zig`, called once after `child_reaper.install()` and config load; skip empty label/command with a warning and call `spawnSh` for valid entries.
- [ ] Run `zig fmt src build.zig` and `zig build test --summary all`; expect all tests to pass.
- [ ] Commit `src/config.zig`, `src/tests.zig` and `src/main.zig` with message `tri: configure startup commands`.

### Task 2: Portable session configuration

**Files:**
- Create: `test-session.sh`
- Modify: `session.sh`
- Modify: `config`

**Interfaces:**
- Consumes config keys `env.<NAME>`, `output`, `mode`, `scale`, `cursor_theme`, `cursor_size`.
- Produces `TRI_SESSION_DRY_RUN=1` output containing normalized `ENV`, `OUTPUT`, `MODE`, `SCALE`, and `TRI_BIN` records without launching external services.

- [ ] Create a shell test using `mktemp -d` and a temporary config containing spaces, `env.QT_IM_MODULE`, `env.XMODIFIERS`, `output = auto`, cursor values and malicious-looking shell text; assert dry-run output treats values as data and executes nothing.
- [ ] Run `sh test-session.sh`; expect failure because `session.sh` has no dry-run parser interface.
- [ ] Rewrite `session.sh` to locate config, validate environment names against `[A-Za-z_][A-Za-z0-9_]*`, export values without sourcing/eval, keep standard XDG defaults, conditionally update D-Bus activation, skip `wlr-randr` for `output=auto`, and locate tri via `TRI_BIN` then source-tree sibling path.
- [ ] Remove portal killing, named portal/input/audio/sunset/mouse/terminal/idle startups and absolute wallpaper paths from `session.sh`.
- [ ] Move current startups into ordered `start.*` config lines, express `$HOME` paths in shell commands and add explicit portal commands only where they remain desired.
- [ ] Run `sh -n session.sh test-session.sh` and `sh test-session.sh`; expect success.
- [ ] Commit scripts and config with message `tri: move session choices into config`.

### Task 3: Baseline x86_64 glibc build

**Files:**
- Modify: `rebuild.sh`
- Modify: `.gitignore` if the build produces a new stable temporary name

**Interfaces:**
- Produces: tracked `zig-out/bin/tri` built using `-Dtarget=x86_64-linux-gnu.2.38 -Dcpu=baseline`.
- Preserves: atomic replacement and `tri.previous` fallback.

- [ ] Add pre-replacement checks in `rebuild.sh` asserting `readelf -h` reports `Advanced Micro Devices X86-64`, `readelf -d` contains expected shared-library entries, and `ldd` contains no `not found` line.
- [ ] Temporarily invoke the checks against a non-ELF file in a shell test function or test mode; expect the script to reject it before replacement.
- [ ] Change both candidate build and verification commands to pass the explicit target and CPU options; keep unit tests native so they execute on the build host.
- [ ] Add `TRI_REBUILD_TEST_FILE` test mode that runs only artifact checks, allowing `test-session.sh` or a dedicated shell assertion to verify rejection without rebuilding.
- [ ] Run `./rebuild.sh`; expect tests, baseline ReleaseSafe build, ELF/dependency checks and atomic installation to succeed.
- [ ] Run `readelf -h zig-out/bin/tri`, `readelf -n zig-out/bin/tri`, and `ldd zig-out/bin/tri`; confirm x86-64 and all dependencies resolved.
- [ ] Commit `rebuild.sh` and the rebuilt binary with message `tri: build portable x86_64 binary`.

### Task 4: Project documentation and final verification

**Files:**
- Modify: `README.md`
- Modify: `CODE.md`
- Modify: `DESIGN.md`
- Modify: repository configuration docs only where they describe tri installation

**Interfaces:**
- Documents `env.*`, `start.*`, `output=auto`, `TRI_CONFIG`, `TRI_BIN`, runtime dependencies and the pull-config workflow.

- [ ] Update documentation with a minimal second-device procedure: pull `voidlinux-config`, link/copy `home/.config/tri`, edit config, verify `ldd`, start River; state Zig is needed only to rebuild.
- [ ] Search project-owned source/config/scripts for `/home/xiang`, hard-coded output/application startups and native-only build commands; allow current-device values only in the tracked example config.
- [ ] Run `zig fmt --check src build.zig`, `zig build test --summary all`, `sh -n session.sh rebuild.sh test-session.sh`, `sh test-session.sh`, `git diff --check`, and `./rebuild.sh`.
- [ ] Compare SHA-256 of `zig-out/bin/tri` and the live `~/.local/bin/tri`; expect equality.
- [ ] Request code review, resolve Critical/Important findings, repeat the full verification suite, commit documentation/fixes and push `main`.
