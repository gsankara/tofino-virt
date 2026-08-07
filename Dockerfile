# csg-tofino-dev — minimal bring-up.
# Deliberately just the base image: get a bare Ubuntu 24.04 box up, verify
# hugepages / veth / CAP_NET_ADMIN and other prerequisites, THEN install the
# bf-sde toolchain by hand inside the machine (see README.md + provision-sde.sh).
FROM ubuntu:24.04
