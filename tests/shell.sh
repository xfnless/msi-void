#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
bashrc=$repo/root/home/.bashrc

if grep -Fq "PS1='\\n" "$bashrc"; then
	printf 'not ok - the first shell prompt starts with a blank line\n' >&2
	exit 1
fi

printf 'ok - the shell prompt starts without a blank line\n'
