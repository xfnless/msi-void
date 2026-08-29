#
# ~/.bashrc
#

# 非交互 shell 不加载这些配置
[[ $- != *i* ]] && return
# Prompt
PS1='\n\[\e[1m\]\A \W\$ \[\e[0m\]'

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

# Start River + tri from a TTY.
rv() {
	if [[ -n ${WAYLAND_DISPLAY:-} ]]; then
		printf 'Wayland session already running.\n' >&2
		return 1
	fi
	export XDG_RUNTIME_DIR="/tmp/xdg-runtime-$UID"
	export XDG_CURRENT_DESKTOP=river
	export XDG_SESSION_DESKTOP=river
	export XDG_SESSION_TYPE=wayland
	export XCURSOR_THEME=Adwaita
	export XCURSOR_SIZE=24
	unset GTK_IM_MODULE
	export QT_IM_MODULE=fcitx
	export QT_IM_MODULES="wayland;fcitx"
	export XMODIFIERS=@im=fcitx
	export PATH="$HOME/.local/bin:$PATH"
	install -d -m 700 "$XDG_RUNTIME_DIR" || return
	dbus-run-session river -c "$HOME/.local/bin/tri-session"
}


# 历史记录
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth:erasedups
# 多行命令按一条记录保存；追加历史，不覆盖；保留换行。
shopt -s cmdhist histappend lithist
# Update tri's titlebar and append new history at every prompt.
_tri_set_title() {
	printf '\033]0;%s@%s:%s\033\\' "$USER" "${HOSTNAME%%.*}" "${PWD/#$HOME/~}"
}

PROMPT_COMMAND='_tri_set_title; history -a'
