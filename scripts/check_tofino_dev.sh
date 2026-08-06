#!/bin/bash
# Prerequisite check for a Tofino SW-model coder box.
echo "===== IDENTITY ====="
hostname; id; uname -a

echo "===== CPU ====="
echo "nproc=$(nproc)"
echo "cpuinfo_count=$(grep -c ^processor /proc/cpuinfo)"
echo -n "cpuset.effective: "; cat /sys/fs/cgroup/cpuset.cpus.effective 2>/dev/null || echo "n/a"
echo -n "cpu.max: "; cat /sys/fs/cgroup/cpu.max 2>/dev/null || echo "n/a"

echo "===== MEM ====="
grep MemTotal /proc/meminfo
echo -n "mem.max(cgroup): "; cat /sys/fs/cgroup/memory.max 2>/dev/null || echo "n/a"

echo "===== HUGEPAGES ====="
grep -i huge /proc/meminfo
echo -n "nr_hugepages(current): "; cat /proc/sys/vm/nr_hugepages 2>/dev/null || echo "n/a"
echo "-- try sysctl set 128 --"
sudo sysctl -w vm.nr_hugepages=128 2>&1 | sed 's/^/  /'
echo -n "nr_hugepages(after sysctl): "; cat /proc/sys/vm/nr_hugepages 2>/dev/null
echo "-- try echo to /proc --"
sudo bash -c 'echo 128 > /proc/sys/vm/nr_hugepages' 2>&1 | sed 's/^/  /'
echo -n "nr_hugepages(after echo): "; cat /proc/sys/vm/nr_hugepages 2>/dev/null
echo -n "sysfs hugepages dir: "; ls /sys/kernel/mm/hugepages/ 2>/dev/null || echo "n/a"
echo -n "/dev/hugepages: "; ls -ld /dev/hugepages 2>/dev/null || echo "absent"
echo -n "vfio: "; ls /dev/vfio 2>/dev/null || echo "absent"

echo "===== CAPABILITIES ====="
if command -v capsh >/dev/null 2>&1; then capsh --print | grep -i -E 'current|bounding' | sed 's/^/  /'; else echo "  capsh not installed"; fi
grep -E 'CapEff|CapBnd' /proc/self/status | sed 's/^/  /'

echo "===== VETH / NET PRIVS ====="
# iproute2 may only be in nix env; test system ip first
if command -v ip >/dev/null 2>&1; then
  sudo ip link add veth-tst0 type veth peer name veth-tst1 2>&1 | sed 's/^/  add: /'
  ip link show veth-tst0 >/dev/null 2>&1 && echo "  VETH CREATE: OK" || echo "  VETH CREATE: FAILED"
  sudo ip link del veth-tst0 2>/dev/null
else
  echo "  system 'ip' not found (iproute2 likely only inside nix env)"
fi
echo -n "/dev/net/tun: "; ls -l /dev/net/tun 2>/dev/null || echo "absent"

echo "===== TOOLING ====="
for t in nix nix-store git make jq java python3 gcc curl scp; do
  printf "  %-8s " "$t"; command -v $t 2>/dev/null || echo "MISSING"
done
echo -n "  sde-env: "; ls /nix/var/nix/profiles/default/bin 2>/dev/null | grep -i sde-env || echo "not installed"
echo -n "  ~/bf-sde: "; ls ~/bf-sde 2>/dev/null || echo "absent"
echo -n "  ~/.bf-sde builds: "; ls ~/.bf-sde/9.13.4/build 2>/dev/null || echo "absent"

echo "===== NET (for nix/github pulls) ====="
curl -sS -m 10 -o /dev/null -w "  nixos.org https=%{http_code}\n" https://nixos.org/ 2>&1 || echo "  curl nixos FAILED"
curl -sS -m 10 -o /dev/null -w "  github https=%{http_code}\n" https://github.com/ 2>&1 || echo "  curl github FAILED"

echo "===== DISK ====="
df -h ~ | sed 's/^/  /'
echo "===== DONE ====="
