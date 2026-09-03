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
mihomoctl check
mihomoctl log
```

`use` changes Mihomo's native mode and policy-group selection. Process control
remains runit's job: use `sudo sv up mihomo`, `sudo sv down mihomo`, or
`sudo sv restart mihomo`.
