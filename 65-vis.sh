#!/bin/sh
# 从官方 master 构建 vis 到用户目录；系统 XBPS 不安装 vis 包。
set -eu

src=$HOME/.local/src/vis
prefix=$HOME/.local

sudo xbps-install -Sy \
	base-devel pkg-config \
	ncurses-devel \
	lua54-devel lua54-lpeg \
	tre-devel acl-devel

mkdir -p "$(dirname "$src")"
if [ -d "$src/.git" ]; then
	git -C "$src" pull --ff-only
else
	git clone --depth=1 https://github.com/martanne/vis.git "$src"
fi

cd "$src"
make distclean >/dev/null 2>&1 || true
./configure \
	--prefix="$prefix" \
	--enable-curses=yes \
	--enable-lua=yes \
	--disable-lpeg-static \
	--enable-tre=yes \
	--enable-acl=yes
make -j2
make -C test/core
make -C test/lua
make -C test/vis
make install

"$prefix/bin/vis" -v
printf '%s\n' 'Vis 已安装；重新打开 Vis 即使用新版本。'
