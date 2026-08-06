#!/bin/bash
# Usage: build-p4.sh <name> <path-to-p4>
# Compiles via the SDE's blessed p4_build.sh flow, logs to ~/logs/build-<name>.log
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
export NIX_REMOTE=daemon
NAME="$1"
SRC="$2"
LOG=~/logs/build-$NAME.log
{
echo "===== p4_build.sh $NAME  ($SRC)  at $(date) ====="
sde-env-9.13.4 --platform=model --command "p4_build.sh $SRC"
echo "P4_BUILD_EXIT=$?"
echo
echo "===== locate generated artifacts for $NAME ====="
find ~/.bf-sde -path "*$NAME*" \( -name 'tofino.bin' -o -name 'context.json' -o -name '*.conf' -o -name 'bf-rt.json' \) 2>/dev/null | sort
} > "$LOG" 2>&1
echo "build $NAME done -> $LOG"
