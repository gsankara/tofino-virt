#!/usr/bin/env python3
"""pexpect driver: bring up tofino-model + bf_switchd for a consolidated
multi-Pipeline program, keep both alive, and confirm each pipeline profile
loads and is addressable via bfrt_python.  Usage: drive_cons.py <prog>"""
import pexpect, sys, time, os, traceback

PROG = sys.argv[1] if len(sys.argv) > 1 else "cons2"
LOGDIR = os.path.expanduser("~/logs")
os.makedirs(LOGDIR, exist_ok=True)
SDE = ("source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; "
       "export NIX_REMOTE=daemon; ")
PORTMAP = os.path.expanduser("~/tofino-portmap.json")

def spawn(cmd, logname):
    lf = open(os.path.join(LOGDIR, logname), "w")
    c = pexpect.spawn("/bin/bash", ["-lc", SDE + cmd], timeout=180, encoding="utf-8", codec_errors="replace")
    c.logfile = lf
    return c

print(f"=== [1] launch tofino-model for {PROG} ===", flush=True)
model = spawn(f"sde-env-9.13.4 --platform=model --command "
              f"'run_tofino_model.sh -p {PROG} -f {PORTMAP}'",
              f"drv-model-{PROG}.log")
# model prints per-port setup then sits waiting; give it time
try:
    model.expect([r"Starting.*[Mm]odel", r"bmi_port_interface_add", r"Model.*nitialized"], timeout=60)
except Exception as e:
    print("model expect note:", repr(e)); traceback.print_exc()
time.sleep(8)
print("model up (child alive: %s)" % model.isalive(), flush=True)

print(f"=== [2] launch bf_switchd for {PROG}, wait bfshell> ===", flush=True)
sw = spawn(f"sde-env-9.13.4 --platform=model --command 'run_switchd.sh -p {PROG}'",
           f"drv-switchd-{PROG}.log")
try:
    sw.expect(r"bfshell>", timeout=180)
    print(">>> reached bfshell> prompt", flush=True)
except Exception as e:
    print("!!! never reached bfshell>:", repr(e)); traceback.print_exc()
    print("switchd tail:\n" + (sw.before or "")[-2000:], flush=True)
    sys.exit(2)

def bf(cmd, prompt=r"bf-sde>", to=30, label=None):
    sw.sendline(cmd)
    try:
        sw.expect(prompt, timeout=to)
    except Exception as e:
        print(f"[{label or cmd}] expect fail: {e}", flush=True)
    out = sw.before or ""
    print(f"----- {label or cmd} -----\n{out}\n", flush=True)
    return out

print("=== [3] ucli: pm show (pipes/ports) ===", flush=True)
sw.sendline("ucli")
sw.expect(r"bf-sde>", timeout=30)
bf("pm show", label="pm show")
# port add (will likely warn: no veths) - capture behavior
bf("pm port-add 1/- 10G NONE", label="port-add 1")
bf("pm port-add 2/- 10G NONE", label="port-add 2")
bf("pm port-enb 1/-", label="port-enb 1")
bf("pm port-enb 2/-", label="port-enb 2")
bf("pm show", label="pm show after")
# leave ucli back to bfshell
sw.sendline("exit")
try:
    sw.expect(r"bfshell>", timeout=20)
except Exception:
    pass

print("=== [4] bfrt_python: enumerate pipeline profiles + tables ===", flush=True)
sw.sendline("bfrt_python")
try:
    sw.expect([r"bfrt_python>", r"In \[\d+\]:", r">>>"], timeout=90)
    print(">>> in bfrt_python", flush=True)
    def py(cmd, to=30, label=None):
        sw.sendline(cmd)
        try:
            sw.expect([r"bfrt_python>", r"In \[\d+\]:", r">>>"], timeout=to)
        except Exception as e:
            print(f"[py {label or cmd}] expect fail: {e}", flush=True)
        print(f"--- py: {label or cmd} ---\n{sw.before}\n", flush=True)
    py(f"print('PROFILES:', [n for n in dir(bfrt.{PROG}) if not n.startswith('_')])", label="profiles")
    py(f"bfrt.{PROG}.dump(from_bfrt=True)", to=40, label="dump-all")
    sw.sendline("exit")
    try: sw.expect(r"bfshell>", timeout=20)
    except Exception: pass
except Exception as e:
    print(f"bfrt_python not reached: {e}", flush=True)

print("=== [5] teardown ===", flush=True)
try:
    sw.sendline("exit"); time.sleep(2)
except Exception: pass
for c in (sw, model):
    try: c.close(force=True)
    except Exception: pass
os.system("pkill -f tofino_model 2>/dev/null; pkill -f bf_switchd 2>/dev/null; pkill -f switchd 2>/dev/null")
print("=== DONE ===", flush=True)
