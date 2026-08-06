#!/usr/bin/env bash
# Idempotent first-run provisioning of bf-sde 9.13.4 under nix.
# Safe to re-run: each step is guarded. Run as the `coder` user.
#
#   ~/bf-sde/bf-sde-9.13.4.tgz          (required, ~403 MB)
#   ~/bf-sde/bf-reference-bsp-9.13.4.tgz (required, ~0.5 MB)
#
# Usage:  bash ~/provision-sde.sh
set -euo pipefail

SDE_VERSION="${SDE_VERSION:-9.13.4}"
SDE_TGZ="$HOME/bf-sde/bf-sde-${SDE_VERSION}.tgz"
BSP_TGZ="$HOME/bf-sde/bf-reference-bsp-${SDE_VERSION}.tgz"

# shellcheck disable=SC1090
source "$HOME/.nix-profile/etc/profile.d/nix.sh" 2>/dev/null || true

log() { printf '### %s\n' "$*"; }

log "Checking source tarballs"
if [[ ! -f "$SDE_TGZ" || ! -f "$BSP_TGZ" ]]; then
  echo "ERROR: place the SDE + BSP tarballs in ~/bf-sde/ first:" >&2
  echo "  $SDE_TGZ" >&2
  echo "  $BSP_TGZ" >&2
  exit 1
fi

log "Adding tarballs to the nix store (fixed-output)"
( cd "$HOME/bf-sde" && nix-store --add-fixed sha256 \
    "bf-sde-${SDE_VERSION}.tgz" "bf-reference-bsp-${SDE_VERSION}.tgz" )

log "Installing bf-sde nixpkgs (this is the long compile — be patient)"
if ! command -v "sde-env-${SDE_VERSION}" >/dev/null 2>&1; then
  ( cd "$HOME/bf-sde-nixpkgs" && make install )
else
  log "sde-env-${SDE_VERSION} already present — skipping make install"
fi

log "First sde-env invocation (model platform, pulls python/pkg deps)"
sde-env-"${SDE_VERSION}" --platform=model \
  --pkgs=psmisc,unzip --python-modules=yappi,grpcio,pexpect \
  --command exit

log "Verifying toolchain"
sde-env-"${SDE_VERSION}" --platform=model --command "which bf-p4c p4_build.sh run_switchd.sh run_tofino_model.sh run_bfshell.sh" \
  || { echo "ERROR: SDE tools not on PATH inside sde-env" >&2; exit 1; }

log "DONE — bf-sde ${SDE_VERSION} ready. Enter it with:  sde-env-${SDE_VERSION} --platform=model"
