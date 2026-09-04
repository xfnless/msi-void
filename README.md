# Void Linux configuration

One small Niri terminal desktop, shared by two laptops.

- `root/etc/` mirrors files installed into `/etc`; they are copied because they rarely change.
- `root/home/` mirrors files linked into the user's home; edits take effect immediately.
- `msi/` and `asus/` contain only the three device-specific setup scripts: hardware, GRUB and power.
- `archive/` keeps inactive Emacs and Neovim configuration; nothing there is linked or installed.

Follow the common commands in `flow.txt`, then run only the block for the machine being installed. The scripts are literal on purpose: there is no host detection, generator or overlay system.

Personal documents, accounts, histories, caches and credentials stay outside this repository.

## Mihomo

`sh 45-mihomo.sh` installs the existing Mihomo binary as a root-run runit
service. On its first run it creates the private
`/etc/mihomo/config.yaml` without enabling the service. Replace
`MARZBAN_SUBSCRIPTION_URL` using `sudoedit /etc/mihomo/config.yaml`, then run
`sh 45-mihomo.sh` again. The second run validates the configuration before
enabling `/var/service/mihomo`; later runs preserve the private configuration.

The controller is deliberately a thin wrapper over Mihomo's native API:

```sh
mihomoctl status
mihomoctl use rule split
mihomoctl use global hk
mihomoctl use global cn
mihomoctl use global 'exact node name'
mihomoctl use direct
mihomoctl nodes
mihomoctl update
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

Interactive `ssh` asks whether to connect through an OpenSSH jump host;
`sshw` always uses it. Configure the single shared jump host locally without
putting private addresses or keys in this repository:

```sshconfig
Host work-bastion
    HostName <fixed-work-egress-ip>
    User <user>
    IdentityFile ~/.ssh/id_ed25519
    ProxyJump none
```

Choosing `n` in the prompt connects directly. Git and other programs that
invoke SSH non-interactively are not wrapped.

`use` changes Mihomo's native mode and policy-group selection. Process control
remains runit's job: use `sudo sv up mihomo`, `sudo sv down mihomo`, or
`sudo sv restart mihomo`.
