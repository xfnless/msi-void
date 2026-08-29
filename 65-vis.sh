#!/bin/sh
# 从官方 master 构建 vis 到用户目录；系统 XBPS 不安装 vis 包。
set -eu

src=$HOME/.local/src/vis
prefix=$HOME/.local

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
make test
make install

"$prefix/bin/vis" -v
