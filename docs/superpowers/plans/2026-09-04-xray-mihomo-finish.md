# Xray and Mihomo Finish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the verified standalone HK/CN Xray deployment into a small, repeatable, secret-free `msi-void` configuration and document its operation.

**Architecture:** Keep server installation role-based and transparent: one shell installer renders readable JSON templates, calls the official XTLS installer, and validates before restart. Keep live credentials only on servers and `/etc/mihomo/config.yaml`; the repository stores placeholders and explicit export/apply instructions.

**Tech Stack:** POSIX shell, Xray 26, systemd, Mihomo, runit, OpenSSH.

**Spec:** `docs/superpowers/specs/2026-09-04-standalone-xray-design.md`

## Global Constraints

- Preserve the user's unrelated `root/etc/keyd/new.conf` change.
- Never commit UUIDs, REALITY private/public values, short IDs, or server passwords.
- Keep the old CN Marzban container available until the user separately authorizes removal.
- Validate Xray/Mihomo configuration before replacing live files or restarting.
- Use `23.26.201.235:443` for HK and `23.26.201.235:9443 -> 183.56.224.54:443` for CN.

---

### Task 1: Add repeatable standalone Xray server artifacts

**Files:**
- Create: `servers/xray/install.sh`
- Create: `servers/xray/exit.json`
- Create: `servers/xray/hk-relay.json`
- Create: `tests/xray-server.sh`

**Interfaces:**
- Consumes: official `install-release.sh`, a verified local Xray archive, role `exit` or `hk-relay`.
- Produces: `/usr/local/etc/xray/config.json`, `/root/xray-client.env`, active `xray.service`.

- [ ] **Step 1: Write a failing static/fixture test**

Assert that templates contain VLESS/REALITY 443, that the relay uses native fixed TCP forwarding to the supplied CN address, and that the installer contains backup, `xray run -test`, dedicated-user, and secret-export behavior.

- [ ] **Step 2: Run the test and verify it fails**

Run: `sh tests/xray-server.sh`
Expected: failure because `servers/xray/` does not exist.

- [ ] **Step 3: Implement the templates and installer**

Use the already live-tested JSON shapes. Parse Xray 26 public output with `/^(Password|PublicKey)/`, generate nonempty credentials, render to a `.json` temporary file, validate, back up once, install atomically, restart, and verify active status.

- [ ] **Step 4: Run tests**

Run: `sh tests/xray-server.sh && sh -n servers/xray/install.sh`
Expected: both exit zero.

- [ ] **Step 5: Commit**

```bash
git add servers/xray tests/xray-server.sh
git commit -m "add standalone xray server deployment"
```

### Task 2: Align the Mihomo template and documentation

**Files:**
- Modify: `root/etc/mihomo/config.yaml.example`
- Modify: `tests/mihomo-config.sh`
- Modify: `README.md`

**Interfaces:**
- Consumes: HK/CN client environment exports from Task 1.
- Produces: documented static-node mappings and unchanged `mihomoctl` behavior.

- [ ] **Step 1: Extend the failing Mihomo template test**

Require complete VLESS/REALITY placeholder fields, HK port 443, CN relay port 9443, `www.nvidia.com`, Vision flow, and existing split/adblock rules.

- [ ] **Step 2: Verify the test fails**

Run: `sh tests/mihomo-config.sh`
Expected: failure because the existing placeholder mappings lack REALITY fields and use HK port 8443.

- [ ] **Step 3: Update template and README**

Document exporting only `UUID`, `PUBLIC_KEY`, and `SHORT_ID`; applying them to the root-owned live file; testing; selecting `rule split`; firewall source restriction; and keeping secrets outside Git.

- [ ] **Step 4: Run Mihomo and shell tests**

Run: `sh tests/mihomo-config.sh && sh tests/mihomoctl.sh && sh tests/shell.sh`
Expected: all exit zero.

- [ ] **Step 5: Commit**

```bash
git add root/etc/mihomo/config.yaml.example tests/mihomo-config.sh README.md
git commit -m "document standalone xray mihomo nodes"
```

### Task 3: Verify and hand off operations

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: completed Tasks 1–2 and the currently running deployment.
- Produces: concise operational model, checks, rollback steps, and cleanup boundary.

- [ ] **Step 1: Document the mental model**

Explain Mihomo as the local traffic dispatcher, REALITY as the authenticated disguised door, Xray exit as the remote network socket owner, and 9443 as a fixed wire that does not decrypt CN traffic.

- [ ] **Step 2: Document native operations**

Include `systemctl status/restart xray`, `journalctl -u xray`, `xray run -test`, `ss -lntp`, `sv status/restart mihomo`, and `mihomoctl use` examples.

- [ ] **Step 3: Run the complete repository test suite**

Run: `for test in tests/*.sh; do sh "$test"; done`
Expected: every test exits zero; `git diff --check` exits zero.

- [ ] **Step 4: Review secret and unrelated-change safety**

Run: `git diff --check && git status --short` plus a targeted scan for the live IP credential field names. Confirm only intended files are staged and `root/etc/keyd/new.conf` remains unstaged.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/superpowers/plans/2026-09-04-xray-mihomo-finish.md
git commit -m "document xray operations and rollback"
```
