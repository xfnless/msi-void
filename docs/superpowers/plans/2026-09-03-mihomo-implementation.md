# Mihomo Command-Line Proxy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a boot-enabled, root-run Mihomo service with native Marzban provider updates, China/domestic versus Hong Kong split routing, a thin API controller, and repository hygiene that tracks only `htoprc`.

**Architecture:** Void runit starts Mihomo from `/usr/local/bin` with private live configuration in `/etc/mihomo` and state in `/var/lib/mihomo`. The public repository contains an install-once example configuration and a POSIX-shell `mihomoctl` that maps a small CLI onto Mihomo's controller API. Shell tests use fake commands so behavior is verified without changing the live network.

**Tech Stack:** POSIX shell, Void Linux runit/xbps, Mihomo YAML and REST API, Marzban Clash/Mihomo subscription, shell fixture tests.

**Spec:** `docs/superpowers/specs/2026-09-03-mihomo-design.md`

## Global Constraints

- Run Mihomo as root under runit and enable it before user login.
- Bind the controller to `127.0.0.1:9090`; keep `allow-lan: false`.
- First and every boot starts in `rule` mode with the `split` policy.
- In `split`, Chinese domains/IPs use `国内`; unmatched traffic uses `香港`.
- Support exactly one private Marzban subscription in the first version.
- Never commit a subscription URL, UUID, generated provider, cache, or live configuration.
- `mihomoctl` remains a thin wrapper over Mihomo's native API and validation command.
- Preserve unrelated changes in `root/etc/keyd/new.conf`.

---

### Task 1: Keep only persistent htop configuration

**Files:**
- Modify: `.gitignore`
- Verify: `root/home/.config/htop/htoprc`

**Interfaces:**
- Consumes: the existing whole-directory symlink created by `70-link-apps.sh`.
- Produces: a tracked `htoprc` and ignored `htop_history` in the same linked directory.

- [ ] **Step 1: Run a failing repository hygiene assertion**

```sh
git check-ignore root/home/.config/htop/htop_history
```

Expected: nonzero because history is not ignored.

- [ ] **Step 2: Ignore only htop history**

Add under the local-state section of `.gitignore`:

```gitignore
**/.config/htop/htop_history
```

Do not ignore the directory or `htoprc`.

- [ ] **Step 3: Verify and commit**

```sh
git check-ignore root/home/.config/htop/htop_history
if git check-ignore root/home/.config/htop/htoprc; then exit 1; fi
git add .gitignore root/home/.config/htop/htoprc
git commit -m "track only persistent htop configuration"
```

Expected: history is ignored and `htoprc` remains tracked.

### Task 2: Define the public Mihomo configuration template

**Files:**
- Create: `root/etc/mihomo/config.yaml.example`
- Create: `tests/mihomo-config.sh`

**Interfaces:**
- Consumes: a user-supplied Marzban URL replacing `MARZBAN_SUBSCRIPTION_URL`.
- Produces: groups `香港`, `国内`, and provider-backed `GLOBAL`, controller port 9090, and provider `marzban`.

- [ ] **Step 1: Write the failing static test**

Create `tests/mihomo-config.sh` to assert that the example exists; contains the URL placeholder but no `uuid:`; binds `127.0.0.1:9090`; disables LAN; enables TUN/auto-route/DNS hijacking; defines provider `marzban`; defines the three groups; contains `GEOSITE,cn,国内`, `GEOIP,cn,国内,no-resolve`, final `MATCH,香港`; and enables `store-selected`.

- [ ] **Step 2: Verify failure**

```sh
sh tests/mihomo-config.sh
```

Expected: FAIL because the example is absent.

- [ ] **Step 3: Implement the template**

Use this base and complete its DNS, groups, filters, and rules:

```yaml
mixed-port: 7890
external-controller: 127.0.0.1:9090
allow-lan: false
mode: rule
log-level: warning
ipv6: false

profile:
  store-selected: true

tun:
  enable: true
  stack: system
  dns-hijack: [any:53]
  auto-route: true
  auto-detect-interface: true

proxy-providers:
  marzban:
    type: http
    url: MARZBAN_SUBSCRIPTION_URL
    path: ./providers/marzban.yaml
    interval: 21600
    header:
      User-Agent: [mihomo]
    health-check:
      enable: true
      url: https://www.gstatic.com/generate_204
      interval: 600
```

Define `香港` and `国内` as provider-backed select groups with filters matching the current Chinese names plus `HK|Hong Kong` and `CN|China`. Define `GLOBAL` over `香港`, `国内`, and `DIRECT`, and also attach provider `marzban` so an exact node can be selected. Rules route private traffic direct, China GeoSite/GeoIP to `国内`, and `MATCH` to `香港`.

- [ ] **Step 4: Verify and commit**

```sh
sh tests/mihomo-config.sh
git diff --check
git add root/etc/mihomo/config.yaml.example tests/mihomo-config.sh
git commit -m "add mihomo split-routing template"
```

Expected: PASS.

### Task 3: Install Mihomo and enable its runit service safely

**Files:**
- Create: `root/etc/sv/mihomo/run`
- Create: `root/etc/sv/mihomo/log/run`
- Create: `45-mihomo.sh`
- Create: `tests/mihomo-install.sh`
- Modify: `flow.txt`
- Modify: `README.md`

**Interfaces:**
- Consumes: the template and a Mihomo binary from `MIHOMO_BIN`, `~/.local/bin/mihomo`, or PATH.
- Produces: `/usr/local/bin/mihomo`, private config, state/log directories, and `/var/service/mihomo`.

- [ ] **Step 1: Write failing install assertions**

Create `tests/mihomo-install.sh` to verify executable run files; the service invokes `/usr/local/bin/mihomo -d /var/lib/mihomo -f /etc/mihomo/config.yaml`; logging uses `svlogd -tt /var/log/sv/mihomo`; the installer copies live config only when absent with mode 0600; rejects the placeholder; runs `mihomo -t`; and enables only after validation. The template's `mode: rule` supplies the boot mode; Mihomo has no command-line mode override.

- [ ] **Step 2: Verify failure**

```sh
sh tests/mihomo-install.sh
```

Expected: FAIL because service files are absent.

- [ ] **Step 3: Add runit files**

The foreground service command is:

```sh
exec /usr/local/bin/mihomo \
  -d /var/lib/mihomo \
  -f /etc/mihomo/config.yaml 2>&1
```

The logger creates its directory and execs `svlogd -tt /var/log/sv/mihomo`. Mark both executable.

- [ ] **Step 4: Add the idempotent installer**

Implement these exact stages in `45-mihomo.sh`:

1. Resolve the source binary in the order documented above; do not embed a moving download URL.
2. Install it to `/usr/local/bin/mihomo` mode 0755 and install runit files.
3. Create `/var/lib/mihomo/providers` and `/var/log/sv/mihomo` mode 0700.
4. If live config is absent, install the example mode 0600, print the `sudoedit` instruction, and exit without enabling.
5. Otherwise reject the placeholder, run native validation, then link the service into `/var/service`.

- [ ] **Step 5: Document and verify**

Add `sudo sh 45-mihomo.sh` to `flow.txt`. Explain the two-pass private configuration setup in `README.md`.

```sh
sh tests/mihomo-install.sh
sh -n 45-mihomo.sh root/etc/sv/mihomo/run root/etc/sv/mihomo/log/run
git diff --check
git add 45-mihomo.sh root/etc/sv/mihomo flow.txt README.md tests/mihomo-install.sh
git commit -m "install mihomo as a runit service"
```

Expected: PASS.

### Task 4: Implement the thin native API controller

**Files:**
- Create: `root/home/.local/bin/mihomoctl`
- Create: `tests/mihomoctl.sh`
- Modify: `70-link-apps.sh`
- Modify: `README.md`

**Interfaces:**
- Consumes: `MIHOMO_API` default `http://127.0.0.1:9090`, groups `香港`/`国内`/`GLOBAL`, provider `marzban`, and overridable command paths for tests.
- Produces: `status`, `use`, `nodes`, `update`, `check`, and `log`.

- [ ] **Step 1: Write failing CLI contract tests**

Create fake `curl`, `sv`, and `mihomo` commands in a temporary directory. Record API method/path/body and return fixture JSON. Assert:

```text
use rule split  -> PATCH /configs with {"mode":"rule"}
use global hk   -> PUT /proxies/GLOBAL selecting 香港; PATCH mode global
use global cn   -> PUT /proxies/GLOBAL selecting 国内; PATCH mode global
use direct      -> PATCH /configs with {"mode":"direct"}
use global NAME -> reject NAME unless present in the API node list
update          -> PUT /providers/proxies/marzban
invalid forms   -> nonzero with exact accepted syntax
```

Assert JSON values are created with Python `json.dumps`, preventing malformed node names.

- [ ] **Step 2: Verify failure**

```sh
sh tests/mihomoctl.sh
```

Expected: FAIL because the controller is absent.

- [ ] **Step 3: Implement API helpers and commands**

Write POSIX helpers `api_get PATH`, `api_patch PATH JSON`, `api_put PATH JSON`, and `json_name NAME` using `curl --fail --silent --show-error`. Implement exactly:

```text
mihomoctl status
mihomoctl use rule split
mihomoctl use global hk|cn|EXACT_NAME
mihomoctl use direct
mihomoctl nodes
mihomoctl update
mihomoctl check
mihomoctl log
```

Aliases select subgroup `香港` or `国内` in `GLOBAL`. Exact names are checked against API output first. `status` prints runit state, native mode, and current groups. `check` invokes native `mihomo -t`; `log` tails 100 runit log lines.

- [ ] **Step 4: Link, document, verify, and commit**

Add `mihomoctl` to explicit bin links in `70-link-apps.sh`. Document that `use` controls native modes/groups and `sv` controls the process.

```sh
sh tests/mihomoctl.sh
sh -n root/home/.local/bin/mihomoctl
sh tests/mihomo-config.sh
sh tests/mihomo-install.sh
git diff --check
git add root/home/.local/bin/mihomoctl tests/mihomoctl.sh 70-link-apps.sh README.md
git commit -m "add native mihomo command controller"
```

Expected: PASS.

### Task 5: Verify the complete integration

**Files:**
- Modify if required: only files introduced by Tasks 1-4.

**Interfaces:**
- Consumes: all prior outputs.
- Produces: evidence that the repository is ready for privileged live installation.

- [ ] **Step 1: Run focused and repository tests**

```sh
sh tests/mihomo-config.sh
sh tests/mihomo-install.sh
sh tests/mihomoctl.sh
for test_file in tests/*.sh; do sh "$test_file"; done
```

Expected: all exit zero. Record an exact hardware/session-dependent failure rather than weakening an existing test.

- [ ] **Step 2: Inspect secrets and unrelated state**

```sh
rg -n 'https?://.*(/sub/|token=)|uuid:' root/etc/mihomo root/home/.local/bin/mihomoctl 45-mihomo.sh
git status --short
git diff --check
```

Expected: no real subscription URL or UUID; the pre-existing keyd modification remains unstaged; no whitespace errors.

- [ ] **Step 3: Run native parse validation**

Copy the example to a temporary directory, replace only the placeholder with `https://example.invalid/subscription`, and run the available Mihomo binary with `-t -d TEMP_DIR -f TEMP_CONFIG`. Expected: configuration parses without starting TUN.

- [ ] **Step 4: Commit verification fixes only if required**

```sh
git add <only the files corrected during verification>
git commit -m "fix mihomo integration verification"
```

Skip when verification changes no files.
