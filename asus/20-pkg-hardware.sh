#!/bin/sh
# ASUS AMD graphics stack and Bluetooth.
set -eu
sudo xbps-install -S mesa-dri mesa-vaapi mesa-vulkan-radeon bluez
