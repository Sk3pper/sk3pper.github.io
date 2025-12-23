---
title: "Second Life: Installing Ubuntu on MBP 2019 16-inch"
date: 2025-12-22 
author:
  name: Sk3pper
hero: /images/hero.png
description: A practical guide to dual-boot Ubuntu on a MBP 2019 with T2 chip.
theme: Toha

menu:
    sidebar:
        name: Second Life - Installing Ubuntu on MBP-2019 16-inch
        identifier: second-life-installing-ubuntu-on-mbp-2019-16-inch
        parent: workstation-setup
        weight: 600
---

It’s Christmas Eve. I should probably be wrapping gifts or drinking hot cocoa. Instead, I found myself staring at my 2019 MacBook Pro, which was currently hot enough to roast chestnuts on an open fire. 

You know the feeling. You own what was once a "flagship" machine, but now it’s plagued by thermal throttling, fans that sound like a jet engine, and the looming threat of losing official macOS support next year. So, I decided to perform a holiday miracle. 🪄

I know, I know—resurrections are usually scheduled for Easter, not Christmas. But why wait for Spring to give a dead Apple a second life? 

I went down the rabbit hole of the T2 Security Chip, firmware patching, and partition shrinking to see if I could save this hardware from the landfill (and save my wallet from current RAM prices). The result? I successfully dual-booted Ubuntu 24.04. The machine is now cool, silent, and surprisingly fast. It’s a complete resurrection. Long life to Linux!

This guide documents the process of dual-booting **Ubuntu** alongside macOS, ensuring that essential hardware like the keyboard, trackpad, and WiFi work correctly.

---

# 1. Introduction

The installation process involves patching the Ubuntu ISO to support the T2 chip, backing up firmware drivers from macOS, disabling secure boot, partitioning the drive, and finally installing the OS.

For the most up-to-date information and troubleshooting, always refer to the official [T2 Linux Wiki](https://wiki.t2linux.org).

{{< alert type="warning" >}} Mid the gap: backup your data{{< /alert >}}

# 2. T2-Ubuntu installation steps

## 2.1 Download ISO

We will use the scripts provided by the **t2linux** community to download a patched ISO that includes necessary drivers.

1. Download the `iso.sh` script from the [T2-Ubuntu releases](https://github.com/t2linux/T2-Ubuntu/releases/download/v6.17.8-1/iso.sh).
2. Make it executable and run it:

```bash
chmod +x iso.sh
./iso.sh
```

Follow the interactive prompts to select the flavor and version:

1. **Flavour:** Choose `1` for Ubuntu.
2. **Version:** Choose `1` for **24.04 LTS - Noble Numbat**.

The script will download the parts, verify checksums, and save the ISO to your Downloads folder.

## 2.2 Create Bootable USB

Once the ISO is downloaded, flash it to a USB drive. A 4GB stick is sufficient.

1. Plug in your USB drive.
2. Open Terminal. If you don't have `coreutils` installed (which provides the faster `gdd` command), install it via Homebrew:

```bash
brew install coreutils
```

3. Identify the disk number (e.g., `/dev/disk4`) using `diskutil list`.
4. Unmount the disk and write the ISO:

```bash
diskutil umountDisk /dev/diskX
sudo gdd bs=4M if=ubuntu-24.04-6.17.8-t2-noble.iso of=/dev/diskX conv=fdatasync status=progress
```

*Replace `/dev/diskX` with your actual disk identifier (e.g., `/dev/disk4`). **Be extremely careful not to overwrite your internal hard drive.***

## 2.3 Backup Firmware

The T2 chip requires specific firmware for WiFi and Bluetooth. We must copy this from macOS to the USB stick's EFI partition so we can install it on Ubuntu later.

1. Download `firmware.sh` from the releases page.
2. Run it:

```bash
./firmware.sh
```

The script will present three options. Select **Option 1: Copy the firmware to the EFI partition**.

**Why choose Option 1?**
I strongly recommend **Option 1** because I have **FileVault** active. When FileVault is enabled, your macOS data volume is encrypted, making it very difficult to mount and access from the Linux Live USB. By using Option 1 while still logged into macOS, we bypass the encryption hurdle entirely and stage the drivers safely in the unencrypted EFI partition.

# 3. macOS Preparation

## 3.1 Disable Secure Boot

To boot a third-party OS like Linux, we must lower the security settings on the T2 chip.

1. Restart your Mac.
2. Hold **Command (⌘) + R** immediately to enter **macOS Recovery**.
3. In the menu bar, select **Utilities > Startup Security Utility**.
4. Set **Secure Boot** to "No Security".
5. Set **Allowed Boot Media** to "Allow booting from external or removable media".

{{< img src="images/A.png" align="center" title="Startup Security Utility configuration" >}}

## 3.2 Partitioning the Disk

We need to shrink the macOS partition to make space for Ubuntu.

1. Reboot into macOS and open **Disk Utility**.
2. If you use FileVault, the data volume might be locked. Select **Macintosh HD - Data** (or similar) and click **Mount**.

{{< img src="images/B.png" align="center" title="Mounting the Data volume in Disk Utility" >}}

3. Enter your password to unlock the drive.

{{< img src="images/C.png" align="center" title="Unlocking the encrypted volume" >}}

4. Select the top-level container/disk and click **Partition**.
5. Click the **(+)** button to add a partition.

{{< alert type="info" >}} Important: When prompted, select Add Partition, NOT "Add Volume". Linux requires a distinct partition, whereas Volumes share space within the APFS container. {{< /alert >}}

{{< img src="images/D.png" align="center" title="Selecting 'Add Partition'" >}}

6. Configure the new partition:

* **Name:** `Untitled` (or `Linux`)
* **Format:** `ExFAT` (Easy to identify later; we will format this to ext4 during installation).
* **Size:** Choose your desired size (e.g., 500 GB).

{{< img src="images/E.png" align="center" title="Setting partition size and format" >}}

7. Click **Apply** to resize the disk.

# 4. Ubuntu Installation

## 4.1 Booting the Installer

1. Shut down the Mac and plug in the Ubuntu USB.
2. Power on and hold the **Option (Alt)** key.
3. You will see the boot menu. Select **EFI Boot**.

* *Tip:* If you see multiple "EFI Boot" icons, it is often the **last one on the right**. If the first one fails, try the others.

{{< img src="images/F.png" align="center" title="Mac Boot Manager selecting EFI Boot" >}}

## 4.2 Partitioning in Ubuntu

Proceed through the installation steps until you reach **Installation type**.

1. Select **Something else** (Manual partitioning).

{{< img src="images/1A.png" align="center" title="Selecting Manual Partitioning" >}}

2. Locate the partition you created in macOS. It will likely show as `unknown` or `fat32` matching the size you set (e.g., 500GB).
3. Select it and click the **(-)** button to delete it. It will become **free space**.

### 4.2.1 Creating Swap Area (Optional but Recommended)

Before creating the main partition, we should create a Swap area. This acts as "overflow" RAM and is **required if you want to use Hibernation**.

1. Select the `free space` and click **(+)**.
2. Set the size roughly equivalent to your RAM (e.g., 16384 MB for 16GB RAM).
3. Set **Use as** to **swap area**.
4. **Location:** Select **End of this space**.

{{< img src="images/2A.png" align="center" title="Creating the Swap partition" >}}

### 4.2.2 Creating the Root Partition

Now we will use the rest of the space for the operating system and files.

1. Select the remaining `free space` and click **(+)**.
2. Create the root partition:

* **Size:** Maximum available.
* **Type:** Primary.
* **Location:** Beginning of this space.
* **Use as:** Ext4 journaling file system.
* **Mount point:** `/`

{{< img src="images/3A.png" align="center" title="Creating the root Ext4 partition" >}}

## 4.3 Finalize Configuration

Ensure the bootloader is pointing to the correct EFI partition.

1. Check the **Device for boot loader installation** dropdown.
2. It should point to your existing EFI partition (usually `/dev/nvme0n1p1`, Type `efi`). **Do not format this partition.**

{{< img src="images/4A.png" align="center" title="Reviewing partition layout" >}} {{< img src="images/5B.png" align="center" title="Bootloader configuration" >}}

3. Click **Install Now** and review the changes.

{{< img src="images/6A.png" align="center" title="Confirming changes to disk" >}}

Complete the installation (Timezone, User setup) and reboot.

# 5. Post-Installation Setup

After rebooting into Ubuntu, your WiFi will not work yet. We need to install the firmware we extracted earlier.

1. Open a terminal.
2. Mount the EFI partition where the script is stored:

```bash
sudo mkdir -p /tmp/apple-wifi-efi
sudo mount /dev/nvme0n1p1 /tmp/apple-wifi-efi
```

3. Run the firmware script:

```bash
bash /tmp/apple-wifi-efi/firmware.sh
```

4. Unmount and cleanup:

```bash
sudo umount /tmp/apple-wifi-efi
```

Reboot your system. WiFi and Bluetooth should now be functional.

# 6. Recommended Tweaks

## 6.1 Fan Control

The MBP 2019 16-inch can get hot. While the standard drivers are ok, you may want more control. The **t2fanrd** daemon is the recommended solution for T2 Macs.

1. **Install the repo:**
If you don't already have the T2 Ubuntu repo (you likely do from the installation), add it.
2. **Install the daemon:**

```bash
sudo apt install t2fanrd
```

3. **Enable and Start:**

```bash
sudo systemctl enable --now t2fanrd
```

4. **Configuration (Optional):**
The config file is located at `/etc/t2fand.conf`. You can edit this file to change the activating temperature or the fan curve. If you edit it, remember to restart the service:

```bash
sudo systemctl restart t2fanrd
```

*For more details, check the [official Fan Guide](https://wiki.t2linux.org/guides/fan/).*

## 6.2 Audio Setup

For the audio setup follow the [official guide](https://wiki.t2linux.org/guides/audio-config/).

## 6.3 Configuring the Touch Bar

If your Mac has a Touch Bar, you can install the **tiny-dfr** app to make it useful in Linux. This daemon provides dynamic function rows and media controls.

1. **Install tiny-dfr:**
Run the following command to update your repositories and install the package:

```bash
sudo apt update && sudo apt install tiny-dfr
```

2. **Restart:**
Make sure you restart your Mac after installing the app for the changes to take effect.
3. **Customizing the Configuration:**
If you want to make changes to the config for `tiny-dfr`:

* Copy the default config file:

```bash
sudo cp /usr/share/tiny-dfr/config.toml /etc/tiny-dfr/config.toml
```

* Edit the file using your preferred text editor (like nano):

```bash
sudo nano /etc/tiny-dfr/config.toml
```

Follow the instructions given inside that file to customize your function keys and media controls.

# Acknowledgments & Resources
A massive thank you to the [t2linux.org](https://t2linux.org) community. Without their efforts, this hardware would be destined for the landfill. And, of course, a huge thanks to Apple for their generous contribution of 'timeless' hardware that totally isn't designed to become an expensive paperweight the moment a new model drops. Finally, thank you to Linux for giving us the freedom to actually use it how we see fit.

**Official Links:**
- [t2linux.org](https://t2linux.org) - The main hub for Linux on T2 Macs.
- [Audio Configuration](https://wiki.t2linux.org/guides/audio-config/) - Specific guides for setting up audio on different models.
- [Fan Control Guide](https://wiki.t2linux.org/guides/fan/) - Official documentation for `t2fanrd`.
