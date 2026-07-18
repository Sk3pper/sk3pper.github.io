---
title: "Fix Suspend/Lid Close Freeze on T2 MBP 2019 (MBP 16,1)"
date: 2026-07-03
author:
  name: Sk3pper
hero: /images/hero.png
description: Guide to fix suspend/lid close freeze on T2 MBP 2019
theme: Toha

menu:
    sidebar:
        name: Fix Suspend/Lid Close Freeze
        identifier: lid-close-freeze-on-t2-mbp19
        parent: workstation-setup
        weight: 600
---


This guide documents how I fixed the black-screen-on-resume issue on a MacBook Pro 16,1 running Ubuntu 24.04 with the T2 Linux kernel.

## The Problem

After closing the lid (or triggering suspend), the screen stays black on resume. The OS is alive (touchpad responds), but the display never wakes up.

## Root Cause

The discrete AMD GPU (Radeon RX 5500M) doesn't recover from suspend properly on the MBP 16,1. The fix is to:

1. Switch to the LTS kernel (better suspend/resume support)
2. Set the Intel iGPU as the primary display (the AMD GPU stays available for compute)
3. Add kernel parameters to help with display recovery on resume
4. Disable the now-orphaned AMD eDP connector to silence the resulting `err 28` flood

## Prerequisites

- Ubuntu 24.04 LTS on T2 MacBook (MBP 16,1)
- LTS kernel installed (`6.18.25-1-t2-noble` or newer) — see [switch_to_lts_kernel.md](./switch_to_lts_kernel.md)

## 1. Diagnose the GPU issue

Check kernel logs for AMD GPU/suspend messages across recent boots:

```bash
for i in $(seq 1 10); do
  echo "=== Boot -$i ==="
  journalctl -b -$i -k | grep -i "amdgpu\|SMU\|suspend\|resume"
done > amd_gpu_logs

cat amd_gpu_logs
```

Symptoms confirming the dGPU is the issue:
- `PM: suspend entry (deep)` is the last log before the black screen
- `Runtime PM not available` for `amdgpu`
- `Fence fallback timer expired on ring sdma0` warnings

## 2. Set Intel iGPU as the primary display

Create the `apple-gmux` config to switch the hardware multiplexer to the iGPU:

```bash
sudo tee /etc/modprobe.d/apple-gmux.conf > /dev/null <<EOF
# Enable the iGPU by default if present
options apple-gmux force_igd=y
EOF
```

Reboot:

```bash
sudo reboot
```

### Verify the switch happened

After reboot, check:

```bash
# Should show "Switching to IGD" in dmesg
sudo dmesg | grep -i "gmux\|apple-gmux"

# Confirm Wayland session
echo $XDG_SESSION_TYPE

# Confirm laptop display is now on the Intel iGPU (card1-eDP-1)
for card in /sys/class/drm/card*-*; do
  echo "$card: $(cat $card/status 2>/dev/null)"
done
```

Expected:
- `apple_gmux: Switching to IGD` in dmesg
- `card1-eDP-1: connected` (Intel iGPU is driving the laptop screen)

> **Note:** `glxinfo | grep "OpenGL renderer"` may still show AMD — that's fine. It just means OpenGL rendering uses the AMD GPU, but the **display output** goes through the Intel iGPU.

> **Side effect to be aware of:** Once the internal panel moves to the Intel iGPU, the AMD GPU's own embedded-DisplayPort connector (`eDP-2`) no longer has a panel attached to it. amdgpu doesn't know this and keeps trying to light it up, producing a flood of
> `amdgpu [drm] Adding stream to context failed with err 28!`
> in dmesg (plus `No EDID read` on `eDP-2` and `dm_irq_work_func ... hogged CPU` warnings). This is harmless noise — the external display still works — but it churns the display workqueue. Section 3a disables that dead connector to stop it.

## 3. Add kernel parameters

Edit GRUB config:

```bash
sudo vim /etc/default/grub
```

Set the following lines:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i915.enable_guc=3"
GRUB_CMDLINE_LINUX="pcie_ports=compat intel_iommu=on iommu=pt pm_async=off"
```

What each parameter does:
- `i915.enable_guc=3` — enables the Intel GPU firmware microcontroller, helps with display recovery on resume
- `intel_iommu=on iommu=pt` — IOMMU passthrough mode (T2 audio/virtualization)
- `pm_async=off` — forces sequential device suspend (more reliable on T2)

Apply and reboot:

```bash
sudo update-grub
sudo reboot
```

Verify:

```bash
cat /proc/cmdline
```

Should include all four parameters.

## 3a. Disable the orphaned AMD eDP connector (stops the `err 28` flood)

This step removes the dmesg noise created as a side effect of Section 2. It is optional for function (the machine works without it) but recommended to stop amdgpu from continuously retrying a dead connector.

Add `video=eDP-2:d` to the **same** `GRUB_CMDLINE_LINUX` line from Section 3:

```
GRUB_CMDLINE_LINUX="pcie_ports=compat intel_iommu=on iommu=pt pm_async=off video=eDP-2:d"
```

What it does:
- `video=eDP-2:d` — tells the kernel to **disable** (`:d`) the display connector named `eDP-2`. Under this iGPU-primary setup that connector is the AMD GPU's embedded DisplayPort, which now points at nothing. Disabling it stops the failed resource-allocation retries (`err 28`) and the `dm_irq_work_func` workqueue churn.

> **CRITICAL — this parameter is paired with `force_igd=y`.**
> `video=eDP-2:d` is only safe **while the internal panel is on the Intel iGPU** (i.e. while `force_igd=y` from Section 2 is active). In that state `eDP-2` is a dead AMD connector and disabling it costs nothing.
> If you ever remove `force_igd=y` (handing the internal panel back to the AMD GPU), `eDP-2` becomes your **real built-in screen** again, and leaving `video=eDP-2:d` in place would blank it. **Add these two together, remove them together.**

Apply and reboot:

```bash
sudo update-grub
sudo reboot
```

### Verify

```bash
# Confirm the parameter is active
cat /proc/cmdline   # should now include video=eDP-2:d

# Confirm the err 28 flood is gone (should print nothing, or only old pre-reboot lines)
sudo dmesg | grep "err 28"
```

> **If `err 28` is still there:** the kernel may have numbered the phantom connector differently this boot. Confirm the exact name and adjust the parameter to match:
> ```bash
> for c in /sys/class/drm/card*-*/; do echo "$(basename $c): $(cat ${c}status)"; done
> ```
> Look for an `eDP` connector reporting `disconnected` on the AMD card — that is the one to disable. The internal Intel panel (the one you actually use) reports `connected`; never disable that one.

> **Note:** A `video=` parameter that targets a non-existent connector name is silently ignored — it will not break boot. The only failure mode that matters is the pairing warning above.

## 4. Fix touchbar after resume

The touchbar (`tiny-dfr`) doesn't survive suspend because the DRM device gets destroyed. The fix is to unload the touchbar kernel modules before sleep and reload them after resume.

The `apple-bce` driver (version 0.02 with the `no-state-suspend` fix by André Eikmeyer) handles the T2 chip suspend/resume properly, so reloading the touchbar modules after wake-up allows them to re-bind successfully.

Create the systemd service:

```bash
sudo nano /etc/systemd/system/t2-touchbar-sleep.service
```

Paste:

```ini
[Unit]
Description=Stop/start touchbar around suspend
Before=sleep.target
StopWhenUnneeded=yes

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'systemctl stop tiny-dfr; modprobe -r appletbdrm; modprobe -r hid_appletb_kbd; modprobe -r hid_appletb_bl'
ExecStop=/bin/bash -c 'sleep 10; modprobe hid_appletb_bl; sleep 2; modprobe hid_appletb_kbd; sleep 2; modprobe appletbdrm; sleep 5; udevadm trigger; sleep 2; systemctl restart tiny-dfr'

[Install]
WantedBy=sleep.target
```

How it works:
- **Before sleep** (`ExecStart`): stops tiny-dfr and unloads all touchbar kernel modules cleanly
- **After resume** (`ExecStop`): reloads modules in the correct order with delays, triggers udev to recreate device nodes, then restarts tiny-dfr
- `StopWhenUnneeded=yes` ensures `ExecStop` runs automatically when `sleep.target` deactivates on resume
- `RemainAfterExit=yes` keeps the service in "active" state so there's something to stop on resume

Enable:

```bash
sudo systemctl daemon-reload
sudo systemctl enable t2-touchbar-sleep.service
```

Verify:

```bash
systemctl is-enabled t2-touchbar-sleep.service
```

> **Note:** After resume, the touchbar takes ~25 seconds to come back (10s initial wait + module loading + udev trigger).

## 5. Test everything

1. Close the lid
2. Wait ~30 seconds
3. Open the lid
4. **Wait up to 2 minutes** for the screen — on the i9-9880H (8 cores), CPU core wake-up time can take up to 2 minutes due to T2 firmware behavior
5. **Wait ~25 more seconds** for the touchbar to come back

## Useful Diagnostic Commands

```bash
# Check current kernel parameters
cat /proc/cmdline

# Check which GPU drives each display
for card in /sys/class/drm/card*-*; do
  echo "$card: $(cat $card/status 2>/dev/null)"
done

# Check apple-gmux module status
sudo dmesg | grep -i "gmux"

# Check the err 28 / phantom-connector noise (should be empty after step 3a)
sudo dmesg | grep -i "err 28\|No EDID read\|dm_irq_work_func"

# Check apple-bce driver version (should have no-state-suspend support)
strings /lib/modules/$(uname -r)/kernel/drivers/staging/apple-bce/apple-bce.ko | grep -i "no.state"

# Check touchbar USB device
lsusb -d 05ac:8302
lsusb -t

# Check which GPUs are available
lspci | grep -i "vga\|3d\|display"

# Recent suspend/resume logs
journalctl -b -k | grep -i "amdgpu\|suspend\|resume"

# Check touchbar sleep service logs
journalctl -u t2-touchbar-sleep.service --no-pager | tail -20

# Check tiny-dfr status
systemctl status tiny-dfr.service
```

## External Monitors (notes)

- External displays on the MBP 16,1 are wired to the **AMD dGPU**, so with `force_igd=y` they go through the dGPU's secondary-output path.
- **HDMI** trains the most reliably and is the low-hassle option.
- **DisplayPort / USB-C → DP** is more fragile: link training can fail on the first hotplug, leaving the monitor detected but black. Unplug/replug once to force a clean re-train. Plugging in *after* login is more reliable than at boot. Lowering the link demand (e.g. 4K@30 instead of 4K@60, or 2560×1440) helps a marginal link train.

## Last Resort: Disable suspend entirely

If nothing above works and you still get a black screen on resume, you can disable lid suspend as a fallback. This prevents the freeze but the laptop will never suspend when closing the lid, draining battery.

Edit logind config:

```bash
sudo vim /etc/systemd/logind.conf
```

Set:

```
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
LidSwitchIgnoreInhibited=yes
HandleSuspendKey=suspend
```

Apply:

```bash
sudo systemctl restart systemd-logind
```

> **Note:** This is not a fix — it just avoids the problem by never suspending. The laptop will stay awake when the lid is closed, draining battery. Use this only while waiting for a proper kernel-level fix.

## References

- [t2linux Wiki — Hybrid Graphics](https://wiki.t2linux.org/guides/hybrid-graphics/)
- [t2linux Wiki — Post Install](https://wiki.t2linux.org/guides/postinstall/)
- [apple-bce with suspend fix](https://github.com/deqrocks/apple-bce)
- [t2linux Discord](https://discord.gg/t2linux)