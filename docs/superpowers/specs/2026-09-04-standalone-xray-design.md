# Standalone Xray deployment design

## Goal

Replace both Marzban-managed deployments with two standalone Xray services.
Keep configuration readable and make a later server migration repeatable without
a panel, Docker, a subscription endpoint, or a domain owned by the user.

## Topology

```text
Hong Kong route:
client -> 23.26.201.235:443 -> HK Xray VLESS/REALITY -> Internet

Domestic route:
client -> 23.26.201.235:9443 -> HK Xray tunnel
       -> 183.56.224.54:443 -> CN Xray VLESS/REALITY -> Internet
```

Both exit servers use TCP/RAW VLESS with REALITY. The HK tunnel forwards raw
TCP to exactly `183.56.224.54:443`; it is not a general-purpose proxy and does
not terminate the domestic REALITY session.

## Protocol choices

- Listen on TCP 443 at both exits.
- Listen on TCP 9443 for the HK-to-CN fixed tunnel.
- Use `www.nvidia.com:443` as the REALITY target and `www.nvidia.com` as the
  only allowed server name because it was already tested successfully on both
  routes.
- Use `xtls-rprx-vision`, one freshly generated UUID, one fresh X25519 keypair,
  and one non-empty eight-byte short ID per exit.
- Do not reuse the old REALITY private key disclosed in chat.
- Block proxy requests to private destination ranges.
- Run Xray under the unprivileged account installed by the official XTLS
  systemd installer.

## Repository artifacts

Add a small `servers/xray/` directory:

- `install.sh`: transparent Debian/Ubuntu systemd installer. It invokes the
  official XTLS installer, generates credentials with native Xray/OpenSSL
  commands, renders one selected template, validates it with Xray, and only
  then enables/restarts the service.
- `exit.json`: readable template for an exit listening on 443.
- `hk-relay.json`: readable template for the HK exit on 443 plus the fixed
  tunnel on 9443.
- `README.md`: exact commands for CN first, HK second, client update, tests,
  rollback, and later migration.

The script accepts a role rather than hiding topology:

```sh
sudo sh install.sh exit
sudo sh install.sh hk-relay 183.56.224.54
```

It writes the active root-owned config to
`/usr/local/etc/xray/config.json` and writes a root-readable client parameter
file beside it. It never writes private values into this repository. Before
replacement it preserves the first existing config as `config.json.before-standalone`
and never overwrites that backup.

## Migration sequence

1. Inspect OS, ports, firewall and current Docker Compose location on CN.
2. Install the Xray binary and prepare the new CN config while the old container
   remains available.
3. Stop the CN Marzban-node container, start standalone Xray on 443, and retain
   the stopped container/config for rollback.
4. Install the HK Xray config with the direct 443 inbound and 9443 tunnel.
5. Allow 22/443/9443 on HK. Allow CN port 443 only from `23.26.201.235` when the
   provider firewall supports source restrictions. Keep XRDP on loopback.
6. Replace the two private proxy mappings in `/etc/mihomo/config.yaml`: both
   use the HK IP, while the HK mapping uses port 443/HK credentials and the CN
   mapping uses port 9443/CN credentials.
7. Validate HK and CN public exit IPs separately, restore `rule split`, reboot
   both servers once, and validate again.
8. Decommission the old HK server only after the new paths pass. Retain stopped
   CN Docker data briefly for rollback.

## Traffic-abuse posture

VLESS/REALITY authentication prevents an attacker without the UUID, public
parameter and short ID from using either exit as a proxy. The 9443 tunnel can
only reach one fixed destination and is not an open relay. Scans and volumetric
traffic can still consume the provider's 1 TB monthly allowance before Xray
rejects them; host firewall rules cannot stop upstream saturation.

Keep only 22/443/9443 public on HK, use SSH keys, disable SSH password login
after key access is verified, restrict CN:443 to the HK source IP, enable
provider traffic alerts, and inspect provider counters periodically. Do not add
complex host rate limiting initially; it can break browser concurrency while
offering little protection from distributed traffic. If abuse is observed,
handle it using provider filtering or change the public ports/addresses.

## Verification and rollback

- Validate generated JSON with `xray run -test` before restarting.
- Confirm listeners with `ss -lntp`.
- Confirm services with `systemctl is-active xray` and recent journal logs.
- Confirm the HK route returns `23.26.201.235` and the CN route returns
  `183.56.224.54`.
- Verify `mihomoctl use rule split`, app routing and ad blocking after testing.
- On CN failure, stop standalone Xray and restart the retained Marzban-node
  Compose project.
- On HK failure, restore the previous local Mihomo config and keep using the
  old HK server.
