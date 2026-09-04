#!/bin/sh
# Install Mihomo and its boot service without storing private nodes here.
set -eu

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
template=$dir/root/etc/mihomo/config.yaml.example

if [ -n "${MIHOMO_BIN:-}" ]; then
	source_bin=$MIHOMO_BIN
elif [ -x "$HOME/.local/bin/mihomo" ]; then
	source_bin=$HOME/.local/bin/mihomo
else
	source_bin=$(command -v mihomo 2>/dev/null || true)
fi

[ -n "${source_bin:-}" ] && [ -x "$source_bin" ] || {
	printf '%s\n' '未找到 Mihomo；请先安装到 ~/.local/bin/mihomo，或设置 MIHOMO_BIN。' >&2
	exit 1
}

sudo install -m 755 "$source_bin" /usr/local/bin/mihomo
sudo install -d -m 755 /etc/mihomo /etc/sv/mihomo/log
sudo install -d -m 700 /var/lib/mihomo/providers /var/log/sv/mihomo
sudo install -m 755 "$dir/root/etc/sv/mihomo/run" /etc/sv/mihomo/run
sudo install -m 755 "$dir/root/etc/sv/mihomo/log/run" /etc/sv/mihomo/log/run

if ! sudo test -f /etc/mihomo/config.yaml; then
	sudo install -m 600 "$template" /etc/mihomo/config.yaml
	printf '%s\n' \
		'已创建 /etc/mihomo/config.yaml。' \
		'请执行 sudoedit /etc/mihomo/config.yaml，填入两个完整节点并删除 REPLACE_STATIC_NODE_VALUES 标记，' \
		'然后重新运行 sh 45-mihomo.sh。'
	exit 0
fi

if sudo grep -Fq 'REPLACE_STATIC_NODE_VALUES' /etc/mihomo/config.yaml; then
	printf '%s\n' '请先填入 /etc/mihomo/config.yaml 中的两个静态节点。' >&2
	exit 1
fi

sudo chmod 600 /etc/mihomo/config.yaml
sudo /usr/local/bin/mihomo -t -d /var/lib/mihomo -f /etc/mihomo/config.yaml
sudo ln -sfnT /etc/sv/mihomo /var/service/mihomo
printf '%s\n' 'Mihomo 配置有效，runit 服务已启用并将自动启动。'
