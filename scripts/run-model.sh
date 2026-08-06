#!/bin/bash
# Best-effort: bring up tofino-model + bf_switchd with a consolidated program,
# confirm both pipeline profiles load, then tear down. Time-bounded.
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
export NIX_REMOTE=daemon
NAME="$1"
LOG=~/logs/run-$NAME.log
mkdir -p ~/logs
{
echo "===== veth setup at $(date) ====="
sde-env-9.13.4 --platform=model --command "sudo \$(type -p veth_setup.sh)" 2>&1 | tail -5
echo "===== launch tofino-model (bg) ====="
sde-env-9.13.4 --platform=model --command "run_tofino_model.sh -p $NAME > ~/logs/model-$NAME.log 2>&1 &  sleep 12; echo model-launched"
echo "===== launch bf_switchd (bg), let it init, capture log ====="
sde-env-9.13.4 --platform=model --command "run_switchd.sh -p $NAME --background > ~/logs/switchd-$NAME.log 2>&1 & sleep 35; echo switchd-waited"
echo "===== switchd log: pipeline-load evidence ====="
grep -iE 'pipeline|pipe_scope|pipeA|pipeB|program|forward|Added the p4|ready|bf_switchd' ~/logs/switchd-$NAME.log | head -60
echo "===== tail switchd log ====="
tail -25 ~/logs/switchd-$NAME.log
echo "===== teardown ====="
pkill -f tofino-model 2>/dev/null; pkill -f bf_switchd 2>/dev/null; pkill -f switchd 2>/dev/null
echo "RUN_DONE $(date)"
} > "$LOG" 2>&1
echo "run $NAME done -> $LOG"
