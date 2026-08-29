#!/bin/sh
# Load the MSI Meteor Lake SOF modules during boot.
set -eu
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sudo install -d /etc/modules-load.d
sudo install -m 644 "$dir/etc/modules-load.d/sof-mtl.conf" \
	/etc/modules-load.d/sof-mtl.conf
