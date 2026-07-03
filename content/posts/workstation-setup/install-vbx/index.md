---
title: "Installing VirtualBox 7.2 on T2 MacMBP 2019 (Ubuntu 24.04)"
date: 2026-07-03
author:
  name: Sk3pper
# hero: /images/hero.png
description: Guide to install vbx on T2 MBP 2019
theme: Toha

menu:
    sidebar:
        name: Installing VirtualBox 7.2 on T2 MacMBP 2019
        identifier: install-vbx
        parent: workstation-setup
        weight: 600
---


## Prerequisites

- Ubuntu 24.04 LTS (Noble) on a T2 MacBook
- LTS kernel installed (`linux-t2-lts`)
- Kernel: `6.18.25-1-t2-noble`

## 1. Remove the old Ubuntu VirtualBox

Ubuntu's repo ships VirtualBox 7.0.16 which doesn't compile against kernel 6.18+. Remove it first:

```bash
❯ sudo apt remove virtualbox virtualbox-dkms virtualbox-qt
```

## 2. Add Oracle's VirtualBox repository

Install required tools:

```bash
❯ sudo apt install curl ca-certificates gpg lsb-release
```

Import Oracle's signing key:

```bash

curl -fsSL https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --dearmor --yes -o /usr/share/keyrings/oracle-virtualbox-2016.gpg
```

Add the repository using the new Ubuntu 24.04 `.sources` format:

```bash

export UBUNTU_CODENAME="noble"
cat <<EOF | ❯ sudo tee /etc/apt/sources.list.d/oracle-virtualbox.sources
Types: deb
URIs: https://download.virtualbox.org/virtualbox/debian
Suites: $UBUNTU_CODENAME
Components: contrib
Architectures: amd64
Signed-By: /usr/share/keyrings/oracle-virtualbox-2016.gpg
EOF
```

## 3. Install VirtualBox 7.2

```bash
❯ sudo apt update
❯ sudo apt install virtualbox-7.2 build-essential dkms linux-headers-$(uname -r)
```

Verify the service is running:

```bash
systemctl status vboxdrv
```

## 4. Add your user to the vboxusers group

```bash
❯ sudo usermod -aG vboxusers "$USER"
```

## 5. Install the Extension Pack

The Extension Pack adds USB 2.0/3.0 support, RDP, disk encryption, etc.

```bash
VBOX_VERSION=$(VBoxManage -v | sed -E 's/[_r].*$//')
echo "$VBOX_VERSION"

cd ~/Downloads
curl -fLO "https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/Oracle_VirtualBox_Extension_Pack-${VBOX_VERSION}.vbox-extpack"

❯ sudo VBoxManage extpack install --replace "Oracle_VirtualBox_Extension_Pack-${VBOX_VERSION}.vbox-extpack"
```

Verify:

```bash
VBoxManage list extpacks
```

## 6. Reboot and launch

```bash
❯ sudo reboot
```

After reboot:

```bash
virtualbox
```



## Reference

- [LinuxCapable guide](https://linuxcapable.com/install-virtualbox-on-ubuntu-linux/)
- [Oracle VirtualBox Linux Downloads](https://www.virtualbox.org/wiki/Linux_Downloads)