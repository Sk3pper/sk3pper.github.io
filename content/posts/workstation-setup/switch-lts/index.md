---
title: "Switch from Mainline to LTS Kernel (T2 MBP19)"
date: 2026-07-03
author:
  name: Sk3pper
# hero: /images/hero.png
description: Guide to switch from Mainline to LTS Kernel (T2 MBP19)
theme: Toha

menu:
    sidebar:
        name: Switch from Mainline to LTS Kernel (T2 MBP19)
        identifier: switch-lts
        parent: workstation-setup
        weight: 600
---


## 1. Install the LTS kernel

```bash
sudo apt install linux-t2-lts
```

## 2. Make GRUB show the boot menu

By default GRUB skips the menu and boots directly. To see the kernel selection screen, edit the GRUB config:

```bash
sudo nano /etc/default/grub
```

Change these lines:

```
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=5
```

Apply and reboot:

```bash
❯ sudo update-grub
❯ sudo reboot
```

## 3. Select the LTS kernel

After the Apple boot manager (Option ⌥), the GRUB menu will appear. Select **Advanced options for Ubuntu**, then choose the LTS kernel (e.g. `6.18.25-1-t2-noble`).

## 4. Verify

```bash
❯ uname -r
6.18.25-1-t2-noble

```

You should see something like `6.18.25-1-t2-noble`.

## 5. Set the LTS kernel as default

Edit GRUB config again:

```bash
❯ sudo vim /etc/default/grub
```

Change the `GRUB_DEFAULT` line to:

```
GRUB_DEFAULT="Advanced options for Ubuntu>Ubuntu, with Linux 6.18.25-1-t2-noble"
```

Apply:

```bash
❯ sudo update-grub
```

> **Note:** GRUB defaults to `GRUB_DEFAULT=0`, which picks the highest version number (e.g. 7.0.1). Since the LTS kernel has a lower version number (6.18.x), you must set it explicitly.

## 6. Clean up old kernel leftovers

To purge leftover configs from previously removed kernels (marked `rc`):

```bash
sudo dpkg --purge $(dpkg --list | grep '^rc' | grep linux-image | awk '{print $2}')
sudo update-grub
```

## 7. (Optional) Remove the old mainline kernel

**Only after confirming the LTS kernel works properly:**

```bash
sudo apt remove linux-headers-7.0.1-1-t2-noble linux-image-7.0.1-1-t2-noble
sudo update-grub
```

> **Warning:** Don't remove the old kernel before rebooting and verifying the LTS one works. If something goes wrong, you still have the mainline kernel to fall back to via GRUB.