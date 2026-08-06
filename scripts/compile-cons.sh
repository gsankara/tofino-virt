#!/bin/bash
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
export NIX_REMOTE=daemon
NAME="$1"
LOG=~/logs/compile-$NAME.log
OUT=~/p4-virt/build_$NAME
SRC=~/p4-virt/$NAME.p4
mkdir -p "$OUT"
{
echo "===== consolidated $NAME.p4 -> $OUT ====="
sde-env-9.13.4 --platform=model --command "bf-p4c --target tofino --arch tna --std p4-16 -o $OUT --bf-rt-schema $OUT/bf-rt.json $SRC"
echo "BF_P4C_EXIT=$?"
echo "===== output tree ====="
find "$OUT" -maxdepth 2 -type f | sort
echo "===== generated .conf files ====="
find "$OUT" -name '*.conf' -exec echo '--- {} ---' \; -exec cat {} \;
} > "$LOG" 2>&1
echo "cons $NAME compile done -> $LOG"
