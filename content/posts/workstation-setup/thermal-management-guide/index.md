---
title: "Thermal Management Guide"
date: 2026-07-03
author:
  name: Sk3pper
# hero: /images/hero.png
description: Thermal Management Guide T2 MBP19
theme: Toha

menu:
    sidebar:
        name: Thermal Management Guide T2 MBP19
        identifier: thermal-management-guide
        parent: workstation-setup
        weight: 600
---


## Overview

This guide covers fan control, CPU temperature monitoring, thermal management, CPU frequency capping, throttle monitoring, power management (TLP), GNOME desktop setup, and keyboard customization for a MacBook Pro Late 2019 running t2linux-ubuntu.

---

## 1. Fan Control with t2fanrd

### Check Service Status

```bash
sudo systemctl status t2fanrd
```

### Manage the Service

```bash
sudo systemctl start t2fanrd
sudo systemctl stop t2fanrd
sudo systemctl restart t2fanrd
sudo systemctl enable t2fanrd    # start on boot
sudo systemctl disable t2fanrd   # disable on boot
```

### View Logs

```bash
journalctl -u t2fanrd -f
```

### Configuration File

```bash
sudo nano /etc/t2fand.conf
```

### Configuration Parameters

| Parameter          | Description                                                                 |
|--------------------|-----------------------------------------------------------------------------|
| `low_temp`         | Temperature (°C) where fans start spinning above minimum speed              |
| `high_temp`        | Temperature (°C) where fans reach maximum speed                             |
| `speed_curve`      | How fan speed scales between low and high (`linear`, `quadratic`, etc.)      |
| `always_full_speed`| If `true`, fans run at max RPM constantly, ignoring the curve               |

### Recommended Configuration

```ini
[Fan1]
low_temp=40
high_temp=80
speed_curve=linear
always_full_speed=false

[Fan2]
low_temp=40
high_temp=80
speed_curve=linear
always_full_speed=false
```

- Below **40°C** → fans at minimum (quiet)
- Between **40–80°C** → fans scale linearly
- At **80°C** → fans at full speed
- CPU is safe up to ~100°C, so 80°C as full-speed trigger is conservative

> [!NOTE] After editing, always restart the service:
> ```bash
> sudo systemctl restart t2fanrd
> ```

---

## 2. Temperature Monitoring

### Quick Snapshot

```bash
sudo apt install lm-sensors
sensors
```

### Detailed Sensor Output

```bash
sensors -u
```

### Real-Time Monitoring

```bash
# Terminal dashboard (CPU temp, frequency, power)
sudo apt install s-tui
s-tui

# System monitor
sudo apt install btop
btop
```

### Monitor with TLP

```bash
sudo apt install tlp tlp-rdw
sudo tlp-stat -t
```

### Continuous Watch

```bash
watch -n 2 'sudo tlp-stat -t'
```

---

## 3. Sensor Layout

This MacBook exposes three fan sensor sources:

| Source             | Sensors        | Notes                                      |
|--------------------|----------------|--------------------------------------------|
| `applesmc-acpi-0`  | fan1, fan2     | **Real fans** (left and right)             |
| `amdgpu-pci-0300`  | fan1           | **Ghost sensor** (always 0 RPM, ignore it) |

The GPU (AMD Radeon Pro) shares the chassis fans — it doesn't have its own. The 0 RPM reading from `amdgpu` is normal.

### Key Temperature Sensors (applesmc)

| Sensor | Meaning              |
|--------|----------------------|
| TC1C–TC8C | CPU core temps    |
| TCMX   | CPU max temp         |
| TG0P   | GPU proximity        |
| TGDD   | GPU diode            |
| TH0X   | Heatsink             |
| TB0T–TB2T | Battery temps     |
| Ts0P/Ts1P | Palm rest temps   |

---

## 4. TLP Power & CPU Management

### Install & Enable

```bash
sudo apt install tlp tlp-rdw
sudo systemctl enable tlp
sudo tlp start
tlp-stat -s    # check status
```

### How TLP Config Works

Settings are loaded in order (last wins):
1. Intrinsic defaults (built-in)
2. `/etc/tlp.d/*.conf` (drop-in overrides)
3. `/etc/tlp.conf` (main config — **this wins over everything**)

> [!IMPORTANT] 
> Keep `/etc/tlp.conf` clean (all defaults, everything commented out). Put all custom CPU settings in drop-in profiles under `/etc/tlp.d/` so you can easily switch between them.

### Profile Setup

#### Step 1: Restore default tlp.conf

```bash
sudo apt install --reinstall tlp
```

This ensures `/etc/tlp.conf` is stock with everything commented out.

#### Step 2: Copy profile files to /etc/tlp.d/

Three profiles are provided with this guide. Copy them to your system:

```bash
sudo cp profile-performance.conf /etc/tlp.d/
sudo cp profile-balanced.conf /etc/tlp.d/
sudo cp profile-powersaver.conf /etc/tlp.d/
```

#### Step 3: Disable all profiles except one

Only one profile should have a `.conf` extension at a time. Rename the others to `.conf.off`:

```bash
# Disable all
sudo rename 's/\.conf$/.conf.off/' /etc/tlp.d/profile-*.conf

# Enable balanced (default)
sudo mv /etc/tlp.d/profile-balanced.conf.off /etc/tlp.d/profile-balanced.conf

# Apply
sudo tlp start
```

### Profile Details

#### profile-performance.conf
```bash
# Use for: heavy workloads, compiling, video rendering
CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=100
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=70
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_performance
```

#### profile-balanced.conf
```bash
# Use for: daily use, browsing, coding, office work
CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=70
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=50
CPU_BOOST_ON_AC=0
CPU_BOOST_ON_BAT=0
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power
```

#### profile-powersaver.conf
```bash
# Use for: max battery life, light tasks, reading
CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=50
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=30
CPU_BOOST_ON_AC=0
CPU_BOOST_ON_BAT=0
CPU_ENERGY_PERF_POLICY_ON_AC=balance_power
CPU_ENERGY_PERF_POLICY_ON_BAT=power
```

### Profile Comparison

| Setting | Performance | Balanced | Powersaver |
|---------|------------|----------|------------|
| AC max    | 100% (4.8 GHz) | 70% (~3.4 GHz) | 50% (~2.4 GHz) |
| BAT max   | 70% (~3.4 GHz) | 50% (~2.4 GHz) | 30% (~1.4 GHz) |
| Turbo AC  | Enabled | Disabled | Disabled |
| Turbo BAT | Disabled | Disabled | Disabled |
| Energy AC | performance | balance_performance | balance_power |
| Energy BAT | balance_performance | balance_power | power |

### Quick Switch Script (tlp-profile)

Install the provided script:

```bash
#!/bin/bash
# tlp-profile - Quick switch between TLP power profiles
# Profiles stored in /etc/tlp.d/ as profile-<name>.conf
# Only one profile can be active at a time (.conf = active, .conf.off = inactive)

PROFILE_DIR="/etc/tlp.d"

if [ -z "$1" ]; then
    echo "Usage: tlp-profile <performance|balanced|powersaver>"
    echo ""
    echo "Active profile:"
    active=$(ls "$PROFILE_DIR"/profile-*.conf 2>/dev/null)
    if [ -n "$active" ]; then
        for f in $active; do
            basename "$f" | sed 's/profile-//;s/\.conf//'
        done
    else
        echo "  none"
    fi
    echo ""
    echo "Available profiles:"
    for f in "$PROFILE_DIR"/profile-*.conf "$PROFILE_DIR"/profile-*.conf.off; do
        [ -f "$f" ] && basename "$f" | sed 's/profile-//;s/\.conf\.off//;s/\.conf//'
    done | sort -u
    exit 0
fi

# Disable all profiles
for f in "$PROFILE_DIR"/profile-*.conf; do
    [ -f "$f" ] && mv "$f" "${f}.off"
done

# Enable selected profile
TARGET="$PROFILE_DIR/profile-${1}.conf.off"
if [ -f "$TARGET" ]; then
    mv "$TARGET" "${TARGET%.off}"
    tlp start
    echo "Switched to: $1"
    echo ""
    echo "Verify:"
    echo "  CPU cap: $(cat /sys/devices/system/cpu/intel_pstate/max_perf_pct)%"
    echo "  Turbo off: $(cat /sys/devices/system/cpu/intel_pstate/no_turbo)"
else
    echo "Profile not found: $1"
    echo "Available: performance, balanced, powersaver"
    exit 1
fi
```

```bash
sudo cp g /usr/local/bin/
sudo chmod +x /usr/local/bin/tlp-profile
```

Usage:

```bash
# Switch profiles
sudo tlp-profile balanced
sudo tlp-profile performance
sudo tlp-profile powersaver

# Check active profile
tlp-profile
```

The script disables all profiles, enables the selected one, runs `tlp start`, and shows the current CPU cap and turbo status.

### Manual Profile Switching (without the script)

```bash
# Disable all
sudo rename 's/\.conf$/.conf.off/' /etc/tlp.d/profile-*.conf

# Enable desired profile (e.g. performance)
sudo mv /etc/tlp.d/profile-performance.conf.off /etc/tlp.d/profile-performance.conf

# Apply[
sudo tlp start
```

### Verify Settings

```bash
# Check CPU cap percentage
cat /sys/devices/system/cpu/intel_pstate/max_perf_pct

# Check turbo boost is off (1 = disabled)
cat /sys/devices/system/cpu/intel_pstate/no_turbo

# Check current frequencies
grep "MHz" /proc/cpuinfo

# Full TLP power report
tlp-stat -p
```

### Temporary Overrides (don't survive reboot)

```bash
# Temporarily set to 100%
echo 100 | sudo tee /sys/devices/system/cpu/intel_pstate/max_perf_pct

# Set back to 70%
echo 70 | sudo tee /sys/devices/system/cpu/intel_pstate/max_perf_pct
```

### Frequency Reference Table

| CPU_MAX_PERF | Approx Max Frequency |
|--------------|---------------------|
| 100% | 4.8 GHz (full) |
| 80% | ~3.8 GHz |
| 70% | ~3.4 GHz |
| 60% | ~2.9 GHz |
| 50% | ~2.4 GHz |
| 30% | ~1.4 GHz |

**Turbo Boost explained:** Intel feature that temporarily pushes cores above base clock (up to 4.8 GHz). Generates a lot of heat in thin laptops. Disabling it keeps temps stable and avoids the boost→throttle→boost cycle.

> [!Note]
> The GNOME Quick Settings power profile toggle (Balanced/Power Saver/Performance) requires `power-profiles-daemon`, which conflicts with TLP. Since TLP is installed, manage power via profiles or terminal commands instead.

---

## 5. CPU Frequency Monitoring (cpufrequtils)

### Install

```bash
sudo apt install cpufrequtils
```

### Usage

```bash
# Full CPU frequency info
cpufreq-info

# Current governor and policy
cpufreq-info -p

# Set governor to performance (all cores)
for i in $(seq 0 15); do sudo cpufreq-set -c $i -g performance; done

# Set governor back to powersave
for i in $(seq 0 15); do sudo cpufreq-set -c $i -g powersave; done
```

### Governors

| Governor | Behavior |
|----------|----------|
| `performance` | Always max frequency |
| `powersave`   | Scales on demand (default with intel_pstate, smart) |

> [!Note]
> With `intel_pstate` driver, `powersave` is the recommended default — it still scales up on demand, unlike the old cpufreq powersave which locked to minimum.
> `cpupower` / `linux-tools` is not available for t2linux custom kernels. Use `cpufrequtils` instead.


---

## 6. Throttle Monitoring

### Check Throttle Events Since Boot

```bash
# Package-level throttle count
cat /sys/devices/system/cpu/cpu0/thermal_throttle/package_throttle_count

# Per-core throttle counts
for i in /sys/devices/system/cpu/cpu*/thermal_throttle/core_throttle_count; do echo "$i: $(cat $i)"; done
```

If the counts are 0, no throttling has occurred since boot.

### Check If Throttling Is Active Now

```bash
# Current frequency vs max — if well below max, something is limiting it
grep "MHz" /proc/cpuinfo

# CPU hardware limits
lscpu | grep "MHz"

# Kernel throttle messages
dmesg | grep -i throttl
```

### Real-Time Monitoring

```bash
# Best visual tool — shows freq, temp, power in real-time
s-tui
```

### Quick One-Liner

```bash
echo "Throttle count: $(cat /sys/devices/system/cpu/cpu0/thermal_throttle/package_throttle_count)" && echo "CPU MHz:" && grep "MHz" /proc/cpuinfo | head -4
```

> [!Tip]
> Reboot to reset throttle counters, then monitor over a day to see if your config changes improved things.

---

## 7. thermald (Intel Thermal Daemon)

Safety net that automatically throttles CPU before critical temps. Works alongside t2fanrd (fans) — thermald handles CPU throttling if fans alone aren't enough.

### Install & Enable

```bash
sudo apt install thermald
sudo systemctl enable thermald
sudo systemctl start thermald
```

### Check Status & Logs

```bash
sudo systemctl status thermald
journalctl -u thermald --no-pager | tail -30
```

### Check Thermal Zones

```bash
cat /sys/class/thermal/thermal_zone*/type
cat /sys/class/thermal/thermal_zone*/temp
```

Config file (usually no need to edit): `/etc/thermald/thermal-conf.xml`

---

## 8. GNOME Desktop Setup

### Install Extension Manager

```bash
sudo apt install gnome-shell-extension-manager
```

Open it from the app launcher or run `extension-manager`. Use the **Browse** tab to search and install extensions.

### Useful Extensions

| Extension             | Description                                           |
|-----------------------|-------------------------------------------------------|
| **Vitals**            | Shows CPU temp, fan speed, memory, network in top bar |
| **Freon**             | Shows temperatures and fan speeds from lm-sensors     |
| **AppIndicator**      | Adds system tray support for apps like Discord, Slack |
| **Top Bar Organizer** | Rearrange items in the top panel                      |
| **Lilypad**           | Hide, reorder, and collapse top bar icons             |

> [!Tip]
> After installing extensions, restart GNOME Shell with **Alt+F2 → type `r` → Enter**, or log out and back in.

### Vitals Configuration

In Vitals settings, set the temperature sensor to **TC0F** (CPU filtered) for the most accurate CPU temperature reading in the top bar. This is an applesmc sensor that tracks the CPU's thermal state on the logic board.

---

## 9. GNOME Tweaks (Keyboard & UI Customization)

### Install

```bash
sudo apt install gnome-tweaks
```

Open it from the app launcher or run `gnome-tweaks`.

### Swap Cmd and Ctrl Keys (macOS-like shortcuts)

On a MacBook, the Cmd key maps to Super in Linux. To make Cmd+C/V/Z work like macOS:

1. Open **Tweaks**
2. Go to **Keyboard & Mouse → Additional Layout Options**
3. Expand **Ctrl position**
4. Check **"Swap Left Win with Left Ctrl"**


### Verify Key Mappings

```bash
# Interactive — press keys to see what they map to
xev -event keyboard

# Show current modifier map
xmodmap -pm
```

---

## 10. Clipboard (xclip)

### Install

```bash
sudo apt install xclip
```

### Usage

```bash
# Copy command output to clipboard
echo "hello" | xclip -selec[tion clipboard

# Copy file contents to clipboard
cat somefile.txt | xclip -selection clipboard

# Paste from clipboard
xclip -selection clipboard -o
```

> [!Tip] 
> `-selection clipboard` targets the Ctrl+V clipboard. Without it, xclip uses the X primary selection (middle-click paste).

---

## 11. Quick Reference Commands

```bash
# Fan service
sudo systemctl status t2fanrd
sudo systemctl restart t2fanrd
journalctl -u t2fanrd -f

# Edit fan curve
sudo nano /etc/t2fand.conf

# Switch TLP profiles
sudo tlp-profile balanced
sudo tlp-profile performance
sudo tlp-profile powersaver
tlp-profile                     # show active profile

# Apply TLP changes
sudo tlp start

# Check CPU cap & turbo
cat /sys/devices/system/cpu/intel_pstate/max_perf_pct
cat /sys/devices/system/cpu/intel_pstate/no_turbo

# Temporary CPU cap override
echo 70 | sudo tee /sys/devices/system/cpu/intel_pstate/max_perf_pct

# Check current frequencies
grep "MHz" /proc/cpuinfo

# Check throttle events
cat /sys/devices/system/cpu/cpu0/thermal_throttle/package_throttle_count

# Check temps
sensors
sensors | grep -E "Package|Core"
sudo tlp-stat -t
watch -n 2 'sudo tlp-stat -t'

# Detailed sensor dump
sensors -u

# Full TLP power report
tlp-stat -p

# Check what's using CPU
top -o %CPU -n 1 | head -20

# CPU frequency info
cpufreq-info
cpufreq-info -p

# Check GNOME desktop
echo $XDG_CURRENT_DESKTOP

# Swap Cmd/Ctrl
gsettings set org.gnome.desktop.input-sources xkb-options "['ctrl:swap_lwin_lctl']"

# Copy to clipboard
echo "text" | xclip -selection clipboard

# Clean unused packages
sudo apt autoremove
```

---