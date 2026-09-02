# Void Linux configuration

One small Niri terminal desktop, shared by two laptops.

- `root/etc/` mirrors files installed into `/etc`; they are copied because they rarely change.
- `root/home/` mirrors files linked into the user's home; edits take effect immediately.
- `msi/` and `asus/` contain only the three device-specific setup scripts: hardware, GRUB and power.
- `archive/` keeps inactive Emacs and Neovim configuration; nothing there is linked or installed.

Follow the common commands in `flow.txt`, then run only the block for the machine being installed. The scripts are literal on purpose: there is no host detection, generator or overlay system.

Personal documents, accounts, histories, caches and credentials stay outside this repository.
