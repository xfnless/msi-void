#!/bin/sh
# wpa 掉线后自动 reconnect（无日志）
IFACE=$1
EVENT=$2
[ "$EVENT" = DISCONNECTED ] || exit 0
sleep 2
wpa_cli -i "$IFACE" reconnect >/dev/null 2>&1 || true
