#!/bin/sh
# void-installer 不写 hosts；重启后 sudo sh 10-set-hosts.sh
h=$(cat /etc/hostname)
cat >/etc/hosts <<EOF
127.0.0.1	localhost.localdomain	localhost
127.0.1.1	${h}.localdomain	${h}
::1		localhost.localdomain	localhost ip6-localhost
EOF
printf '%s\n' 'hosts 已写入，立即生效。'
