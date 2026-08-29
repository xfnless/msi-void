#!/bin/sh
# ASUS AMD graphics stack.
set -eu
sudo xbps-install -S mesa-dri mesa-vaapi mesa-vulkan-radeon
