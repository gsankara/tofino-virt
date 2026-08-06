# tofino-virt

Coder workspace + experiment for **multi-user virtualization of an Intel Tofino 1
switch** (up to 4 users, one hardware pipe each) using a single consolidated P4
program with per-pipe `Pipeline()` instances. Builds and validates against the
**Tofino software model** (`tofino-model` + `bf_switchd`) — **no ASIC required**.

NRP Coder builds the workspace image from the `Dockerfile` at the repo root.

## Layout
- `Dockerfile` — Ubuntu 24.04 + toolchain (nix, python/pexpect, iproute2, JRE, build deps). Self-clones this repo into `~/tofino-virt`.
- `provision-sde.sh` — idempotent first-run build of bf-sde 9.13.4 under nix.
- `p4/` — `cons2.p4`, `cons4.p4`: consolidated multi-`Pipeline()` programs (2- and 4-user).
- `scripts/` — `drive_cons.py` (pexpect driver for the interactive model+switchd), `build-p4.sh`, `run-model.sh`, `compile-*.sh`, `check_tofino_dev.sh` (box prereq check).
- `artifacts/` — generated `.conf` (the `pipe_scope` mapping) + build/switchd logs from the validated runs.

## The critical part the Dockerfile CANNOT provide

`bf_switchd` needs **hugepage-backed DMA memory**, and creating veths needs
**CAP_NET_ADMIN**. Both are container *runtime* privileges set by the **Coder
template** (the Terraform launching the container), not by the Dockerfile.
Without them switchd dies at DMA init:

```
sysctl: setting key "vm.nr_hugepages", ignoring: Read-only file system
ERROR: DR pool create failed ... size 2093568 failed(-1)
```

### Required runtime settings (Coder template `docker_container`)

| Need | Why | How |
|------|-----|-----|
| **8 vCPUs / ≥16 GiB RAM** | nix SDE build + compiles | template resource sizing |
| **Hugepages** | switchd DMA (DR pool) | reserve on the **Docker host** (`vm.nr_hugepages` is host-global, non-namespaced — a container can't set it) + bind-mount `/dev/hugepages` |
| **CAP_NET_ADMIN** | create veth pairs for model port I/O | container capability |
| **CAP_IPC_LOCK** | mlock hugepage DMA memory | container capability |
| **CAP_NET_RAW** (opt) | raw packet sockets for PTF tests | container capability |
| **/dev/net/tun** (opt) | TAP interfaces | device mapping |

On the Docker host, once:
```bash
sudo sysctl -w vm.nr_hugepages=256
sudo mkdir -p /dev/hugepages
grep -q hugetlbfs /proc/mounts || sudo mount -t hugetlbfs none /dev/hugepages
```

Coder template snippet (Terraform):
```hcl
resource "docker_container" "workspace" {
  # ... existing coder fields ...
  capabilities { add = ["NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN"] }  # or privileged = true
  mounts { target = "/dev/hugepages"  source = "/dev/hugepages"  type = "bind" }
  devices { host_path = "/dev/net/tun" }
  cpu_shares = 8192
  memory     = 16384   # MiB
}
```
`docker run` equivalents: `--cap-add NET_ADMIN --cap-add NET_RAW --cap-add IPC_LOCK --cap-add SYS_ADMIN -v /dev/hugepages:/dev/hugepages --device /dev/net/tun --cpus 8 --memory 16g` (or `--privileged`).

## First-run provisioning (inside the workspace)
The heavy SDE build is deferred so the image builds fast.

1. Put the Intel source tarballs on the persistent home volume (NOT in git):
   `~/bf-sde/bf-sde-9.13.4.tgz` and `~/bf-sde/bf-reference-bsp-9.13.4.tgz`.
2. Build the SDE:
   ```bash
   bash ~/tofino-virt/provision-sde.sh
   ```
3. Verify the runtime privileges actually landed:
   ```bash
   bash ~/tofino-virt/scripts/check_tofino_dev.sh
   cat /proc/sys/vm/nr_hugepages          # > 0
   sudo ip link add v0 type veth peer name v1 && echo VETH_OK && sudo ip link del v0
   ```

## Run the experiment
```bash
sde-env-9.13.4 --platform=model --command "p4_build.sh ~/tofino-virt/p4/cons4.p4"
python3 ~/tofino-virt/scripts/drive_cons.py cons4     # brings up model + switchd
```
With hugepages present, switchd should clear DMA init, reach `bfshell>`, and
allow the per-pipe bfrt addressability proof.

## Validated result (on the software model)
One `Switch()` with **heterogeneous** per-pipe `Pipeline()` instances **compiles
and places on Tofino 1** for both 2 and 4 pipelines (0 errors); heterogeneous
per-pipe header/metadata/parser types need no superset workaround; pipe mapping
is driven by `Switch()` arg order and materialized as `pipe_scope` in the `.conf`
(with 2 pipelines the profiles replicate across the 4 pipes — use 4 instances for
strict per-user 1:1). See `artifacts/`.

## Reference
nix packaging: `github.com/alexandergall/bf-sde-nixpkgs`. Interactive-driving
pattern adapted from the FABRIC Tofino SW-model L2 lab notebook.
