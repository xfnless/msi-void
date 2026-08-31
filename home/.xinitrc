export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx

xrdb -merge "$HOME/.Xresources"
xset r rate 250 40
fcitx5 &
tint2 &

exec cwm
