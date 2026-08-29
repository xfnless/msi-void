# tri Portable Configuration Design

## Goal

Keep tri inside `voidlinux-config/home/.config/tri` as it is today, including source, session script and tracked binary. On another Void Linux glibc x86_64 computer, pulling the configuration repository provides everything project-owned; the user edits only `config` and starts River.

## Supported platform

- Linux x86_64 with glibc and baseline x86_64 CPU features, on both AMD and Intel CPUs.
- River 0.4 with the protocols already consumed by tri.
- Wayland client, xkbcommon, fcft and pixman remain system runtime dependencies.
- Void musl and non-x86_64 targets are outside the supported binary boundary.

The tracked `zig-out/bin/tri` is dynamically linked like a normal WM. No archive format, bundled shared libraries, installer or package manager is added.

## Repository workflow

`home/.config/tri` remains the only project directory. It contains config, scripts, build files, source, protocols, vendored Zig packages and `zig-out/bin/tri`.

`rebuild.sh` always targets `x86_64-linux-gnu.2.38` with baseline CPU features, so its tracked result is not specialized for the build machine's AMD or Intel CPU. It runs tests, builds ReleaseSafe into a temporary prefix, atomically replaces the tracked binary and retains `tri.previous` as today.

Another machine obtains source and binary through the normal `voidlinux-config` pull. It does not need Zig unless rebuilding tri.

## Configuration

The single configuration remains `~/.config/tri/config`, overridable through `TRI_CONFIG`:

```ini
master_ratio = 0.62
cursor_theme = Adwaita
cursor_size = 28
output = eDP-1
mode = 2560x1600@60Hz
scale = 1.5

env.QT_IM_MODULE = fcitx
env.XMODIFIERS = @im=fcitx

start.input_method = exec fcitx5
start.audio = exec pipewire
start.terminal = exec alacritty

bind.Super+a = exec alacritty
bind.Super+s = :focus_toggle
```

- `env.<NAME>` exports a session variable before D-Bus activation and tri starts.
- `start.<label>` is an arbitrary shell command started once by tri, in file order, after the child reaper is installed. Labels have no built-in meaning.
- `bind.<key>` keeps the existing command/internal-action behavior.
- Output values are applied by `session.sh`. Setting `output = auto` skips manual `wlr-randr` configuration.
- Invalid binding entries are ignored with warnings. Invalid numeric values use safe defaults. Empty startup commands are ignored with warnings.
- Shell variables such as `$HOME` expand inside `start.*` and external `bind.*` commands. Project defaults and scripts contain no `/home/xiang` path.

The tracked config preserves the current machine's behavior as an editable example. Other devices change or remove output, startup and command lines without editing shell or Zig source.

## Responsibility split

`session.sh` keeps only work that must happen before tri:

1. Locate the script directory and `TRI_CONFIG`.
2. Safely parse `env.*`, cursor and output values without sourcing the config.
3. Set standard Wayland desktop defaults unless overridden.
4. Update D-Bus/systemd activation environment when available.
5. Optionally apply output mode with bounded `wlr-randr` retries.
6. Locate and `exec` `zig-out/bin/tri`, or use `TRI_BIN` when explicitly set.

It contains no named application startup, input-method choice, audio choice, portal restart, absolute wallpaper path or device-specific output default.

The tri binary parses and starts every `start.*` command once at startup. Spawn failures are logged and never block the Wayland event loop. Short commands are reaped; long-running simple commands can use `exec` to avoid a shell wrapper.

## Portability checks

`rebuild.sh` verifies the new binary before replacement:

- ELF machine is x86-64.
- Build target is baseline x86_64 Linux glibc rather than the native CPU.
- Required dynamic libraries resolve on the build machine.
- Unit tests and ReleaseSafe build pass.

Documentation lists the runtime library and River requirements. A target machine missing a required `.so` receives the loader's direct error rather than an opaque installer failure.

## Tests

- Unit tests cover ordered `start.*` parsing, arbitrary labels, empty values and coexistence with bindings.
- A shell-level test runs `session.sh` in a dry-run mode against a temporary config and verifies environment/output parsing without executing user commands.
- Existing binding, layout and child-reaper tests remain.
- Final verification covers script syntax, repeated unit tests, ReleaseSafe baseline build, ELF metadata, `ldd`, tracked/live binary hashes and a clean diff.

## Non-goals

- No release archive, package, AppImage, bundled library tree or installer.
- No glibc/musl universal binary.
- No GUI configurator, hot reload or per-host profile engine.
- No change to window-management behavior.
