#!/bin/bash
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
export NIX_REMOTE=daemon
LOG=~/logs/explore-env.log
{
echo "===== sde-env-9.13.4 --help ====="
sde-env-9.13.4 --help 2>&1
echo
echo "===== inside env: tool locations ====="
sde-env-9.13.4 --platform=model --command 'echo SDE=$SDE; echo SDE_INSTALL=$SDE_INSTALL; which bf-p4c; bf-p4c --version; which p4_build.sh; which run_switchd.sh; which run_tofino_model.sh; ls $SDE_INSTALL/bin | head -40'
} > "$LOG" 2>&1
echo "explore done -> $LOG"
