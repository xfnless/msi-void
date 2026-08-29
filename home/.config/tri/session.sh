#!/bin/sh
# Minimal River bootstrap. Device and application choices live in config.
set -eu

tri_script=$(readlink -f "$0" 2>/dev/null) || tri_script=$0
tri_dir=$(CDPATH= cd -- "$(dirname "$tri_script")" && pwd)
tri_config=${TRI_CONFIG:-$tri_dir/config}
export TRI_CONFIG=$tri_config

export XCURSOR_THEME=${XCURSOR_THEME:-Adwaita}
export XCURSOR_SIZE=${XCURSOR_SIZE:-28}
export XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-river}
export XDG_SESSION_DESKTOP=${XDG_SESSION_DESKTOP:-river}
export XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-wayland}

OUTPUT=auto
MODE=
SCALE=
SESSION_ENV_NAMES=

if [ -f "$tri_config" ]; then
	while IFS= read -r raw || [ -n "$raw" ]; do
		line=$(printf '%s' "$raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
		case "$line" in
		''|\#*) continue ;;
		esac
		case "$line" in
		*=*) ;;
		*) continue ;;
		esac
		key=${line%%=*}
		val=${line#*=}
		key=$(printf '%s' "$key" | sed 's/[[:space:]]*$//')
		val=$(printf '%s' "$val" | sed 's/^[[:space:]]*//')
		case "$key" in
		env.*)
			env_name=${key#env.}
			case "$env_name" in
			''|[0-9]*|*[!A-Za-z0-9_]*) continue ;;
			esac
			export "$env_name=$val"
			SESSION_ENV_NAMES="$SESSION_ENV_NAMES $env_name"
			[ "${TRI_SESSION_DRY_RUN:-0}" = 1 ] && printf 'ENV %s=%s\n' "$env_name" "$val"
			;;
		output) OUTPUT=$val ;;
		mode) MODE=$val ;;
		scale) SCALE=$val ;;
		cursor_theme) XCURSOR_THEME=$val; export XCURSOR_THEME ;;
		cursor_size) XCURSOR_SIZE=$val; export XCURSOR_SIZE ;;
		esac
	done <"$tri_config"
fi

tri_bin=${TRI_BIN:-$tri_dir/zig-out/bin/tri}

if [ "${TRI_SESSION_DRY_RUN:-0}" = 1 ]; then
	printf 'CURSOR_THEME %s\n' "$XCURSOR_THEME"
	printf 'CURSOR_SIZE %s\n' "$XCURSOR_SIZE"
	printf 'OUTPUT %s\n' "$OUTPUT"
	printf 'MODE %s\n' "$MODE"
	printf 'SCALE %s\n' "$SCALE"
	printf 'TRI_BIN %s\n' "$tri_bin"
	exit 0
fi

set -- DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE \
	XDG_SESSION_DESKTOP XCURSOR_THEME XCURSOR_SIZE $SESSION_ENV_NAMES
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
	dbus-update-activation-environment --systemd "$@" 2>/dev/null ||
		dbus-update-activation-environment "$@" 2>/dev/null || true
fi
if command -v systemctl >/dev/null 2>&1; then
	systemctl --user import-environment "$@" 2>/dev/null || true
fi

if [ -n "$OUTPUT" ] && [ "$OUTPUT" != auto ] && command -v wlr-randr >/dev/null 2>&1; then
	i=0
	while [ "$i" -lt 50 ]; do
		i=$((i + 1))
		if [ -n "$MODE" ] && [ -n "$SCALE" ]; then
			wlr-randr --output "$OUTPUT" --mode "$MODE" --scale "$SCALE" >/dev/null 2>&1 && break
		elif [ -n "$MODE" ]; then
			wlr-randr --output "$OUTPUT" --mode "$MODE" >/dev/null 2>&1 && break
		elif [ -n "$SCALE" ]; then
			wlr-randr --output "$OUTPUT" --scale "$SCALE" >/dev/null 2>&1 && break
		else
			break
		fi
		sleep 0.1
	done
fi

if [ ! -x "$tri_bin" ]; then
	echo "tri: executable not found: $tri_bin" >&2
	exit 1
fi
exec "$tri_bin"
