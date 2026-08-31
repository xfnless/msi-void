#!/bin/sh
# ASUS Bluetooth; network recovery hooks are installed by 85-power.sh.
set -eu

sudo ln -sfn /etc/sv/bluetoothd /var/service/bluetoothd
