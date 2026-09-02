#!/bin/sh
# 下载/更新 Helium 到 ~/.local/opt/helium
set -e
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if ! command -v xz >/dev/null; then
	echo "缺少 xz，请先运行：sh 60-pkg-apps.sh"
	exit 1
fi

opt=$HOME/.local/opt/helium
api="https://api.github.com/repos/imputnet/helium-linux/releases/latest"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "检查 Helium 最新版本..."
url="$(
	curl -fsSL "$api" |
		sed -n 's/.*"browser_download_url": "\(.*x86_64_linux\.tar\.xz\)".*/\1/p' |
		head -n 1
)"

test -n "$url"

archive="${url##*/}"
latest="${archive#helium-}"
latest="${latest%-x86_64_linux.tar.xz}"

if [ -x "$opt/helium" ]; then
	installed="$("$opt/helium" --version | awk '{print $2}')"
	if [ "$installed" = "$latest" ]; then
		echo "已经是最新版：$installed"
		exit
	fi
	echo "更新：$installed -> $latest"
fi

echo "下载：$archive"
curl -fL "$url" -o "$tmp/helium.tar.xz"

echo "解压并检查..."
mkdir "$tmp/new"
tar -xJf "$tmp/helium.tar.xz" \
	--strip-components=1 \
	-C "$tmp/new"

test -x "$tmp/new/helium"

echo "替换旧版本..."
mkdir -p "$HOME/.local/opt"
rm -rf "$opt"
mv "$tmp/new" "$opt"

# 开箱 UI/主题（与 root/etc/helium/initial_preferences 同步）
seed="$dir/root/etc/helium/initial_preferences"
if [ -f "$seed" ]; then
	cp -f "$seed" "$opt/initial_preferences"
	cp -f "$seed" "$opt/master_preferences"
fi

echo "Helium 更新完成。"
