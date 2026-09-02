#!/bin/sh
# ASUS AMD graphics stack.
set -eu
sudo xbps-install -S mesa-dri mesa-vaapi mesa-vulkan-radeon
printf '%s\n' 'ASUS 图形包已安装；重新打开图形程序后使用新组件。'
