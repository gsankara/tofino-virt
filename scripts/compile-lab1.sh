#!/bin/bash
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
export NIX_REMOTE=daemon
LOG=~/logs/compile-lab1.log
OUT=~/p4-virt/build_lab1
mkdir -p "$OUT"
{
echo "===== baseline lab1 basic.p4 -> $OUT ====="
sde-env-9.13.4 --platform=model --command "bf-p4c --target tofino --arch tna --std p4-16 -o $OUT --bf-rt-schema $OUT/bf-rt.json ~/P4_labs/lab1/p4src/basic.p4"
echo "BF_P4C_EXIT=$?"
echo "===== output tree ====="
find "$OUT" -maxdepth 2 -type f | sort
} > "$LOG" 2>&1
echo "lab1 compile done -> $LOG"
