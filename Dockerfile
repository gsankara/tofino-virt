# csg-tofino-dev — minimal bring-up.
# Base Ubuntu 24.04 + only what the Coder agent bootstrap needs.
# The envbuilder init runs `curl -fsSL https://coder.com/install.sh | sh` then
# `coder agent start`, so the image MUST have curl + CA certs (ubuntu:24.04 has
# neither). Everything else (bf-sde toolchain) is installed by hand inside the
# box after verifying hugepages / veth / prereqs — see README.md.
FROM ubuntu:24.04
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
