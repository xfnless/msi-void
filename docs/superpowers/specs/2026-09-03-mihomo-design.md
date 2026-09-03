# Mihomo command-line proxy design

## Goal

Add a small, system-wide Mihomo setup to `msi-void` for two self-hosted
Marzban nodes. It starts at boot on Void Linux, uses a practical split rule by
default, and exposes a thin command-line wrapper around Mihomo's native API.

## Operating model

Mihomo runs as root under runit. This keeps TUN creation, automatic routes and
DNS interception reliable across binary upgrades and before user login.

The three native Mihomo modes remain visible in the control interface:

```text
mihomoctl use rule split    China sites use the domestic-IP node; all else uses Hong Kong
mihomoctl use global hk     all traffic uses the Hong Kong node
mihomoctl use global cn     all traffic uses the domestic-IP node
mihomoctl use direct        all traffic connects directly
```

`mihomoctl` does not implement routing. It translates these commands into
requests to Mihomo's controller API on `127.0.0.1:9090`. Service lifecycle
continues to use native runit commands such as `sv up`, `sv down`, and
`sv restart`.

The service starts in `rule` mode after every boot. Runtime node selections may
be stored by Mihomo, but a temporary global or direct mode must not become the
next boot's mode.

## Files and ownership

Repository-managed files:

```text
root/etc/mihomo/config.yaml.example  public configuration template
root/etc/sv/mihomo/run               runit service
root/etc/sv/mihomo/log/run           runit logger
root/home/.local/bin/mihomoctl        user-facing API wrapper
45-mihomo.sh                          installation and service setup
tests/mihomo.sh                       static and command tests
```

Installed files and state:

```text
/usr/local/bin/mihomo       core executable
/etc/mihomo/config.yaml     private live configuration containing the subscription URL
/var/lib/mihomo/            cache, provider downloads, and Geo data
/var/log/sv/mihomo/         service logs
```

The installer creates `/etc/mihomo/config.yaml` from the example only when it
does not already exist. It never overwrites a configured subscription URL.
The live configuration is mode `0600`. Cache, provider output, subscription
URLs, UUIDs and other credentials never enter Git.

## Subscription and policy groups

There is one Marzban subscription configured as one native HTTP
`proxy-provider`. It requests Mihomo/Clash-compatible YAML with a Mihomo user
agent and refreshes periodically. A health check measures node availability.

Node names are filtered into two policy groups:

- `香港`: names matching Hong Kong aliases.
- `国内`: names matching the domestic/CN aliases used by the self-hosted node.

The `split` rule policy sends private/local traffic directly, Chinese domains
and IP ranges through `国内`, and unmatched traffic through `香港`. Common
GeoSite and GeoIP rule data provide the classification. `GLOBAL` offers the
Hong Kong node, domestic node, and `DIRECT` for native global-mode selection.

## Controller commands

The first version supports:

```text
mihomoctl status
mihomoctl use rule split
mihomoctl use global hk
mihomoctl use global cn
mihomoctl use global <exact-node-name>
mihomoctl use direct
mihomoctl nodes
mihomoctl update
mihomoctl check
mihomoctl log
```

Missing or invalid arguments print valid modes and currently available nodes.
Aliases `hk` and `cn` are resolved by inspecting the appropriate Mihomo policy
group rather than duplicating full subscription-generated node names.

`update` asks the native provider API to refresh. `check` invokes Mihomo's
native configuration validation. `log` reads the runit service log.

## Safety and failures

- The controller binds only to loopback and LAN access remains disabled.
- Configuration is validated before installation-time service activation.
- A failed provider refresh leaves Mihomo's cached provider usable.
- The runit service restarts after crashes and records logs without a network
  refresh loop in the service entrypoint.
- The controller reports unavailable services, malformed API responses, empty
  node groups and failed configuration checks with nonzero exit status.
- Existing unrelated worktree changes are not modified or committed.

## Verification

Tests cover shell syntax, repository layout, secret placeholders, command
argument validation, API request construction with a fake controller, and the
expected rule/group topology. Installation verification runs Mihomo's native
configuration checker before the service is enabled.
