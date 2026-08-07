# Tofino software-model dev box for Coder (csg-tofino-dev)
# Base OS + toolchain for building Intel bf-sde 9.13.4 via nix
# (alexandergall/bf-sde-nixpkgs) and running tofino-model + bf_switchd.
#
# IMPORTANT: hugepages, veth/TAP and CAP_NET_ADMIN are NOT set here — they are
# container *runtime* privileges configured in the Coder template. See README.md.
FROM ubuntu:24.04

ARG USERNAME=coder
ARG SDE_VERSION=9.13.4
ENV DEBIAN_FRONTEND=noninteractive

# ---- OS prerequisites -------------------------------------------------------
# curl/git/xz : fetch nix + clone bf-sde-nixpkgs
# make/cmake/build-essential/pkg-config : bf-sde-nixpkgs `make install`
# jq, default-jre : used by the SDE build/tooling
# python3 + python3-pexpect : the interactive switchd/model driver (drive_cons.py)
# iproute2/kmod/net-tools/tcpdump : veth setup + packet inspection on the model
# psmisc/unzip/procps : sde-env --pkgs deps and general use
RUN apt-get update && apt-get install -y --no-install-recommends \
      sudo curl ca-certificates xz-utils git \
      make cmake build-essential pkg-config \
      jq default-jre \
      python3 python3-pip python3-venv python3-pexpect \
      iproute2 iputils-ping net-tools tcpdump kmod \
      psmisc unzip procps bash locales \
      libssl-dev zlib1g-dev openssh-client \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ---- non-root coder user with passwordless sudo -----------------------------
#RUN useradd -m -s /bin/bash ${USERNAME} \
#    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
#    && chmod 0440 /etc/sudoers.d/${USERNAME} \
#    && mkdir -p /nix && chown ${USERNAME}:${USERNAME} /nix

# ---- Nix (single-user; container-friendly, needs no systemd) ----------------
#USER ${USERNAME}
#ENV USER=${USERNAME}
#RUN curl -L https://nixos.org/nix/install -o /tmp/nix-install.sh \
#    && sh /tmp/nix-install.sh --no-daemon \
#    && rm /tmp/nix-install.sh \
#    && mkdir -p /home/${USERNAME}/.config/nix \
#    && printf 'experimental-features = nix-command flakes\nmax-jobs = auto\ncores = 0\n' \
#       > /home/${USERNAME}/.config/nix/nix.conf
#ENV PATH=/home/${USERNAME}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/home/${USERNAME}/.local/bin:$PATH

# ---- bf-sde nixpkgs (heavy SDE build deferred to first-run provisioning) -----
#RUN git clone --branch master https://github.com/alexandergall/bf-sde-nixpkgs.git \
#      /home/${USERNAME}/bf-sde-nixpkgs \
#    && mkdir -p /home/${USERNAME}/bf-sde

# ---- this experiment's own scripts + P4 (self-clone, no build context needed) -
# Pulls provision-sde.sh, drive_cons.py, cons*.p4, etc. into the image so the
# workspace has them regardless of how Coder supplies the build context.
#ARG REPO_URL=https://github.com/gsankara/tofino-virt.git
#ARG REPO_REF=main
#RUN git clone --depth 1 --branch ${REPO_REF} ${REPO_URL} /home/${USERNAME}/tofino-virt \
#    && chmod +x /home/${USERNAME}/tofino-virt/provision-sde.sh \
#                /home/${USERNAME}/tofino-virt/scripts/*.sh 2>/dev/null || true

# Drop the SDE + BSP source tarballs into ~/bf-sde (NOT in git — Intel-licensed,
# ~403 MB). scp them onto the persistent home volume, then run:
#   bash ~/tofino-virt/provision-sde.sh

#WORKDIR /home/${USERNAME}
CMD ["/bin/bash", "-l"]
