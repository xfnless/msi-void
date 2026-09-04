# Void Linux configuration

One small Niri terminal desktop, shared by two laptops.

- `root/etc/` mirrors files installed into `/etc`; they are copied because they rarely change.
- `root/home/` mirrors files linked into the user's home; edits take effect immediately.
- `msi/` and `asus/` contain only the three device-specific setup scripts: hardware, GRUB and power.
- `archive/` keeps inactive Emacs and Neovim configuration; nothing there is linked or installed.

Follow the common commands in `flow.txt`, then run only the block for the machine being installed. The scripts are literal on purpose: there is no host detection, generator or overlay system.

Personal documents, accounts, histories, caches and credentials stay outside this repository.

## Standalone Xray servers

`servers/xray/install.sh` installs or reconfigures one transparent Xray role.
Copy the whole `servers/xray/` directory to the server alongside the official
XTLS installer and a separately verified `Xray-linux-64.zip`, then run one of:

```sh
sudo sh servers/xray/install.sh exit
sudo sh servers/xray/install.sh hk-relay 183.56.224.54
```

Use `exit` for any standalone overseas or domestic exit. Use `hk-relay` only
on the Hong Kong server that owns both its Reality exit on TCP 443 and the
fixed TCP 9443 relay to the domestic Reality listener. Build and test in this
order: HK `exit`, CN `exit`, then rerun HK as `hk-relay`. This keeps every
failure attributable to one layer.

The script uses `/tmp/install-release.sh` and
`/tmp/Xray-linux-64.zip` only when Xray is absent. It generates credentials
with native Xray/OpenSSL commands, validates a temporary `.json` file, keeps
the first old configuration as `config.json.before-standalone`, and restarts
only after validation. Server secrets stay in
`/usr/local/etc/xray/server.env`; the client-only export is
`/usr/local/etc/xray/client.env`. Both are mode 600 and must not be committed.

Native server maintenance remains visible:

```sh
sudo /usr/local/bin/xray run -test -config /usr/local/etc/xray/config.json
systemctl status xray --no-pager
sudo systemctl restart xray
sudo journalctl -u xray -n 50 --no-pager
sudo ss -lntp | grep -E ':(443|9443)\b'
```

Keep HK public TCP 22, 443 and 9443 only. Restrict CN TCP 443 to the HK
address `/32`. Keep the old CN Marzban container stopped-but-present until a
reboot and both exit tests pass; rollback means stopping standalone Xray and
starting that retained container.

### Mental model

Think of Mihomo as the dispatcher in the local station. TUN brings it selected
application traffic; `rule split` reads the destination and sends Chinese
sites to the `国内` platform, other work-app sites to `香港`, and leaves other
processes on `DIRECT`. `global` temporarily sends everything to one selected
platform. The stored `global:` choice shown by `mihomoctl status` is inert
while the active mode is `rule`.

An Xray Reality listener is a guarded remote door. The UUID, server public
parameter and short ID let the client prove it belongs there; the server keeps
the private key. After that handshake, VLESS carries the requested TCP stream
and the remote Xray opens the real Internet connection, so websites see that
server's exit address. `www.nvidia.com` is the believable TLS target/SNI, not
an HTTP reverse proxy and not where authenticated user traffic is sent.

HK TCP 9443 is only a sealed pipe. `dokodemo-door` accepts raw TCP and forwards
it to CN TCP 443 without understanding or decrypting the inner CN Reality
session. The CN UUID and Reality handshake therefore remain end-to-end between
local Mihomo and the CN Xray. The two paths are:

```text
HK: local Mihomo -> HK:443 Reality -> Internet
CN: local Mihomo -> HK:9443 raw relay -> CN:443 Reality -> Internet
```

For another overseas-only server, copy the verified archive, official
installer and this directory, then run only `sudo sh install.sh exit`; add its
client fields to the private Mihomo configuration. For a new HK+CN pair: test
HK `exit`, test CN `exit` directly while its firewall temporarily allows the
client IP, restrict CN 443 to HK, change HK to `hk-relay`, point the Mihomo CN
entry at HK 9443, and finally restore `mihomoctl use rule split`.

## Mihomo

`sh 45-mihomo.sh` installs the existing Mihomo binary as a root-run runit
service. On its first run it creates the private
`/etc/mihomo/config.yaml` without enabling the service. Paste the two complete
static Mihomo proxy mappings, remove the `REPLACE_STATIC_NODE_VALUES` marker,
then run `sh 45-mihomo.sh` again. The second run validates the configuration
before enabling `/var/service/mihomo`; later runs preserve the private nodes.

The controller is deliberately a thin wrapper over Mihomo's native API:

```sh
mihomoctl status
mihomoctl use rule split
mihomoctl use global hk
mihomoctl use global cn
mihomoctl use global 'exact node name'
mihomoctl use direct
mihomoctl nodes
mihomoctl update  # explains how static nodes are updated
mihomoctl adblock on
mihomoctl adblock off
mihomoctl adblock status
mihomoctl check
mihomoctl log
```

In the normal `rule split` mode, Mihomo's TUN sends Firefox, Google Chrome and
Telegram through the split rules (China through `国内`, everything else
through `香港`). Other applications fall through to `DIRECT`. Use
`mihomoctl use global cn` or `mihomoctl use global hk` temporarily when the
split mode is unsuitable, then restore it with `mihomoctl use rule split`.
In split mode, `GEOSITE,category-ads-all` provides lightweight blocking for
the three work applications. `mihomoctl adblock off` disables that rule until
Mihomo restarts; `mihomoctl adblock on` enables it again.

Interactive `ssh` and `scp` ask whether to use an OpenSSH jump host; `sshw`
and `scpw` always use it. Configure the single shared jump host locally without
putting private addresses or keys in this repository:

```sshconfig
Host work-bastion
    HostName <fixed-work-egress-ip>
    User <user>
    IdentityFile ~/.ssh/id_ed25519
    ProxyJump none
```

Choosing `n` in either prompt connects directly. A destination of
`work-bastion` itself is always direct. Git and other programs that invoke SSH
non-interactively are not wrapped.

`use` changes Mihomo's native mode and policy-group selection. Process control
remains runit's job: use `sudo sv up mihomo`, `sudo sv down mihomo`, or
`sudo sv restart mihomo`.
