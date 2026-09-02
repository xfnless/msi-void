#!/bin/sh

# xdg-desktop-portal-termfilechooser wrapper for lf.
# Keep navigation on l/right, and use Enter as the explicit confirmation key.

set -eu

multiple=$1
directory=$2
save=$3
path=$4
out=$5
debug=$6

[ "$debug" = 1 ] && set -x

termcmd=${TERMCMD:-alacritty --title termfilechooser -e}
file_config=$HOME/.config/lf/xdg-file.lfrc
directory_config=$HOME/.config/lf/xdg-directory.lfrc
export LF_XDG_OUT=$out

if [ "$directory" = 1 ]; then
    # lf's stock -last-dir-path selects the directory after entering it and
    # quitting.  Use an explicit output variable so Enter can select the
    # highlighted directory instead.
    set -- -config "$directory_config" "$path"
else
    set -- -config "$file_config" "$path"
fi

command="$termcmd lf"
for arg in "$@"; do
    escaped=$(printf '%s' "$arg" | sed 's/"/\\"/g')
    command="$command \"$escaped\""
done

sh -c "$command"
