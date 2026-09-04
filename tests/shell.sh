#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
bashrc=$repo/root/home/.bashrc

if grep -Fq "PS1='\\n" "$bashrc"; then
	printf 'not ok - the first shell prompt starts with a blank line\n' >&2
	exit 1
fi

printf 'ok - the shell prompt starts without a blank line\n'

has() {
	grep -Fq "$1" "$bashrc" || {
		printf 'not ok - missing SSH wrapper behavior: %s\n' "$1" >&2
		exit 1
	}
}

has 'ssh() {'
has '通过工作跳板机连接？[Y/n]'
has 'command ssh -J work-bastion'
has 'sshw() {'

printf 'ok - interactive SSH offers the work bastion and sshw forces it\n'
