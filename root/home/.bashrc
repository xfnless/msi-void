#
# ~/.bashrc
#

# 非交互 shell 不加载这些配置
[[ $- != *i* ]] && return
# Prompt
PS1='\[\e[1m\]\A \W\$ \[\e[0m\]'

# 补全和 fzf
[[ $PS1 && -f /usr/share/bash-completion/bash_completion ]] &&
	. /usr/share/bash-completion/bash_completion

if command -v fzf >/dev/null 2>&1; then
	# 加载 fzf 快捷键和补全：Ctrl-T 文件，Alt-C 目录，Ctrl-R 历史。
	eval "$(fzf --bash)"
	# 紧凑样式，默认按精确匹配筛选。
	export FZF_COMPLETION_OPTS='--info=inline'
	export FZF_DEFAULT_OPTS='--style minimal --layout reverse --info inline --exact'
	# 选中文件/目录时只预览，不打开。
	export FZF_CTRL_T_OPTS="--preview 'sed -n \"1,120p\" {}' --preview-window right,50%,noborder"
	export FZF_ALT_C_OPTS="--preview 'ls -la --color=always {}' --preview-window right,50%,noborder"
	# 用 fd 列文件：包含隐藏文件；忽略规则集中放在 ~/.config/fd/ignore。
	export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow'
	export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# shell 行为
set -o noclobber
shopt -s checkwinsize

export EDITOR=vis
export VISUAL=vis

# Keep the shell in the directory last visited by lf.
lfcd() {
	cd "$(command lf -print-last-dir "$@")" || return
}
alias lf=lfcd

alias ld='ls -Alh --color=auto'
alias cx='chmod +x'
alias gl='git clone --depth=1'

# Interactive SSH asks whether to use the fixed work bastion. Programs that
# execute /usr/bin/ssh directly (Git, scripts and automation) are unaffected.
_ssh_via_work_bastion() {
	local hostname
	hostname=$(command ssh -G work-bastion 2>/dev/null |
		awk '$1 == "hostname" { print $2; exit }') || return
	if [[ -z $hostname || $hostname == work-bastion ]]; then
		printf '%s\n' \
			'未配置 work-bastion；请先在 ~/.ssh/config 中添加跳板机。' >&2
		return 2
	fi
	command ssh -J work-bastion "$@"
}

ssh() {
	if [[ ${1:-} == work-bastion ]]; then
		command ssh "$@"
		return
	fi
	if [[ -t 0 && -t 1 ]]; then
		local answer
		read -r -p '通过工作跳板机连接？[Y/n] ' answer
		case $answer in
			n|N) command ssh "$@" ;;
			*) _ssh_via_work_bastion "$@" ;;
		esac
	else
		command ssh "$@"
	fi
}

sshw() {
	_ssh_via_work_bastion "$@"
}

# Start Niri from a TTY.
ni() {
	if [[ -n ${WAYLAND_DISPLAY:-} || -n ${DISPLAY:-} ]]; then
		printf 'Graphical session already running.\n' >&2
		return 1
	fi
	export XDG_RUNTIME_DIR="/tmp/xdg-runtime-$UID"
	install -d -m 700 "$XDG_RUNTIME_DIR" || return
	dbus-run-session niri --session
}


# 历史记录
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth:erasedups
# 多行命令按一条记录保存；追加历史，不覆盖；保留换行。
shopt -s cmdhist histappend lithist
# Update the terminal title and append new history at every prompt.
_set_title() {
	printf '\033]0;%s@%s:%s\033\\' "$USER" "${HOSTNAME%%.*}" "${PWD/#$HOME/~}"
}

PROMPT_COMMAND='_set_title; history -a'
