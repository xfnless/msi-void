#!/bin/sh
set -eu

usage() {
	printf '%s\n' \
		'usage: sudo sh install.sh exit' \
		'       sudo sh install.sh hk-relay <domestic-ip>' >&2
	exit 2
}

[ "$(id -u)" -eq 0 ] || { echo '请以 root 运行。' >&2; exit 1; }
[ "$#" -ge 1 ] || usage
role=$1
relay_address=${2:-}
case $role in
	exit) template=exit.json ;;
	hk-relay)
		[ -n "$relay_address" ] || usage
		template=hk-relay.json
		;;
	*) usage ;;
esac

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
template=$dir/$template
xray=/usr/local/bin/xray
config_dir=/usr/local/etc/xray
config=$config_dir/config.json
backup=$config_dir/config.json.before-standalone
server_env=$config_dir/server.env
client_env=$config_dir/client.env
official_installer=${XRAY_INSTALLER:-/tmp/install-release.sh}
archive=${XRAY_ARCHIVE:-/tmp/Xray-linux-64.zip}

[ -r "$template" ] || { echo "缺少模板：$template" >&2; exit 1; }

if [ ! -x "$xray" ]; then
	[ -r "$official_installer" ] || {
		echo "缺少官方安装器：$official_installer" >&2
		exit 1
	}
	[ -r "$archive" ] || {
		echo "缺少已校验安装包：$archive" >&2
		exit 1
	}
	id xray >/dev/null 2>&1 || useradd --system --home-dir /var/lib/xray \
		--create-home --shell /usr/sbin/nologin xray
	printf '\n' | sh "$official_installer" install --local "$archive" --install-user xray
fi

install -d -m 755 "$config_dir"
if [ ! -f "$server_env" ]; then
	umask 077
	UUID="$($xray uuid)"
	key_output="$($xray x25519)"
	PRIVATE_KEY="$(printf '%s\n' "$key_output" | awk -F ': ' '/PrivateKey:/{print $2}')"
	PUBLIC_KEY="$(printf '%s\n' "$key_output" | awk -F ': ' '/^(Password|PublicKey)/{print $2; exit}')"
	SHORT_ID="$(openssl rand -hex 8)"
	: "${UUID:?无法生成 UUID}"
	: "${PRIVATE_KEY:?无法生成私钥}"
	: "${PUBLIC_KEY:?无法生成公钥}"
	: "${SHORT_ID:?无法生成 Short ID}"
	printf '%s\n' "UUID=$UUID" "PRIVATE_KEY=$PRIVATE_KEY" \
		"PUBLIC_KEY=$PUBLIC_KEY" "SHORT_ID=$SHORT_ID" >"$server_env"
	chmod 600 "$server_env"
fi

# shellcheck disable=SC1090
. "$server_env"
: "${UUID:?缺少 UUID}"
: "${PRIVATE_KEY:?缺少 PRIVATE_KEY}"
: "${PUBLIC_KEY:?缺少 PUBLIC_KEY}"
: "${SHORT_ID:?缺少 SHORT_ID}"

tmp=$(mktemp --suffix=.json /tmp/xray-config.XXXXXX)
trap 'rm -f "$tmp"' EXIT HUP INT TERM
sed \
	-e "s|__UUID__|$UUID|g" \
	-e "s|__PRIVATE_KEY__|$PRIVATE_KEY|g" \
	-e "s|__SHORT_ID__|$SHORT_ID|g" \
	-e "s|__RELAY_ADDRESS__|$relay_address|g" \
	"$template" >"$tmp"

$xray run -test -config "$tmp"
[ ! -f "$config" ] || [ -f "$backup" ] || cp -a "$config" "$backup"
install -m 644 "$tmp" "$config"
printf '%s\n' "UUID=$UUID" "PUBLIC_KEY=$PUBLIC_KEY" \
	"SHORT_ID=$SHORT_ID" >"$client_env"
chmod 600 "$client_env"
systemctl restart xray
systemctl enable xray >/dev/null
systemctl is-active --quiet xray

echo "Xray 已安装：角色=$role"
echo "客户端参数：$client_env"
ss -lntp | grep -E ':(443|9443)\b' || true
