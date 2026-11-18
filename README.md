# OpenWrt x86/64 firmware on GitHub Actions — official source, 92 NIC drivers, six languages

[![OpenWrt](https://img.shields.io/badge/OpenWrt-25.12-00B5E2)](https://github.com/openwrt/openwrt/tree/openwrt-25.12)
[![Target](https://img.shields.io/badge/target-x86%2F64%20generic-lightgrey)](#artifacts-and-flashing)
[![Kernel](https://img.shields.io/badge/kernel-6.12-lightgrey)](.diffconfig)
[![NIC drivers](https://img.shields.io/badge/NIC%20drivers-92-blueviolet)](#network-drivers-92-packages)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

**This repository builds its own OpenWrt image for x86/64 PCs, mini-PCs and
servers** — no prebuilt firmware from someone else, no patch files, and no
private packages beyond the Passwall feeds. The whole recipe is one
`.diffconfig`, two shell hooks and two workflows; a manual run, or a change in
the upstream sources, starts a fresh build on `ubuntu-24.04` and publishes the
images to a GitHub Release.

The result is a router image that boots on ordinary PC hardware and in KVM,
Hyper-V, Xen, VMware and AWS Nitro guests, recognises 92 network adapters
(69 wired NICs, 3 virtual/cloud NICs, 20 PHYs) without adding a driver by hand,
speaks the six UN languages, and carries Passwall with sing-box and Hysteria 2.
Every driver, every theme and every LuCI app comes from an official OpenWrt
feed, so there is no forked package tree to keep in sync.

> **Actions-OpenWrt-x86** is a GitHub Actions build of the **official OpenWrt
> 25.12 source** for `x86/64 generic`: UEFI and Legacy BIOS images in squashfs
> and ext4 flavour, 92 official `kmod-*` NIC/PHY driver packages, six UN
> languages, three LuCI themes, Passwall (sing-box 1.14.4 + Hysteria 2 2.13.0),
> the complete legacy iptables stack for third-party plug-ins, and firmware
> flashing from LuCI. The images come from `openwrt-25.12` with kernel 6.12 and
> the `apk` package manager.

## Contents

- [Features](#features)
- [Quick start: a firmware image in one click](#quick-start-a-firmware-image-in-one-click)
- [What is in the image](#what-is-in-the-image)
- [Network drivers (92 packages)](#network-drivers-92-packages)
- [Virtual machines and cloud guests](#virtual-machines-and-cloud-guests)
- [WAN protocols and IPv6](#wan-protocols-and-ipv6)
- [iptables / ip6tables support](#iptables--ip6tables-support)
- [Passwall](#passwall)
- [Languages](#languages)
- [LuCI themes](#luci-themes)
- [Artifacts and flashing](#artifacts-and-flashing)
- [Updating and rebuilding](#updating-and-rebuilding)
- [Repository layout](#repository-layout)
- [FAQ](#faq)
- [License](#license)

## Features

- **Official source, and a branch chosen for a reason**: `openwrt-25.12` is the
  first branch whose Go toolchain is 1.26, which the current Passwall packages
  need (sing-box >= 1.25.5, hysteria >= 1.26, geoview >= 1.25). On 24.10 the
  build dies with
  `go.mod requires go >= 1.25.5 (running go 1.23.12; GOTOOLCHAIN=local)`
- **92 network driver packages, all official `kmod-*`**: 69 wired NICs, the
  `vmxnet3` / `amazon-ena` / `amd-xgbe` trio for virtual machines, and 20
  Ethernet PHY drivers — counted per driver package, so `r8169` alone covers
  RTL8111/8168/8125 and `igc` covers I225/I226
- **Bare metal and guests in one image**: `virtio-net`, `hv_netvsc` and
  `xen-netfront` are compiled into the x86/64 kernel, so a KVM, Hyper-V/Azure or
  Xen guest has a NIC before any module loads
- **Six UN languages** — Arabic, English, French, Russian, Spanish and Chinese
  (both scripts), installed for exactly the LuCI components that are built
  (see [Languages](#languages))
- **Passwall** with transparent proxy in nftables mode, sing-box and Hysteria 2
  cores, `geoview` for rule-set conversion, and `geoip.dat` / `geosite.dat`
  pre-installed so split routing works on first boot
- **Legacy iptables/ip6tables stack** next to `firewall4`: filter, mangle, nat,
  raw, bridge and ARP tables, ipset, flow offload, plus the iptables and
  xtables-addons extension packages that most plug-ins still expect
- **Serial console off by default**: the image boots on the VGA console only, so
  a phantom UART (Intel AMT SOL, IPMI, SuperIO) cannot stall the boot — one
  variable in `diy-part2.sh` brings it back
- **Firmware flashing from LuCI**: `luci-mod-system` uploads the image to
  `/tmp/firmware.bin`, validates it with `sysupgrade --test`, prints the SHA256
  and offers "Force upgrade". Attended Sysupgrade (`owut` / ASU) is deliberately
  not included
- **No secrets, no personal access token**: both workflows run on the built-in
  `GITHUB_TOKEN`, so a fork works the moment it is created (see
  [Updating and rebuilding](#updating-and-rebuilding))
- **Microcode loaded at boot**: `intel-microcode` and `amd64-microcode` (the x86
  kernel already has `CONFIG_MICROCODE` and `MICROCODE_LATE_LOADING` built in)

## Quick start: a firmware image in one click

1. **Fork this repository** (the workflows are already active; a fork needs
   no secrets and no configuration).
2. Open **Actions → Build OpenWrt → Run workflow**, leave `ssh` at `false` and
   start it. A full build takes roughly two hours on the free runner: OpenWrt
   25.12, the official feeds and the Passwall packages are cloned and compiled
   from scratch.
3. When the job finishes, open **Releases** and download the image that matches
   the machine (see [Artifacts and flashing](#artifacts-and-flashing)).

You can also build locally:

```sh
git clone https://github.com/openwrt/openwrt -b openwrt-25.12 openwrt
cd openwrt
cp /path/to/this/repository/.diffconfig .config   # the .diffconfig of this repo
make defconfig && make download -j"$(nproc)" && make -j"$(nproc)"
```

On Ubuntu the kernel Kconfig step needs `gawk` (`mawk` has no `asort`), so
`sudo apt install gawk flex bison` before the first `make`; the workflow
installs the same packages.

## What is in the image

| Component | Choice |
| --- | --- |
| Source | official `openwrt/openwrt`, branch `openwrt-25.12`, kernel 6.12 |
| Target | `x86/64` device `generic`, 16 MB kernel partition, 1024 MB rootfs |
| Package manager | **apk** (25.12 moved away from opkg); LuCI "Software" and Passwall were checked against it, but an opkg-only command in some plug-in no longer applies |
| Config | `.diffconfig` only — no patch files and no private packages; the single source change is the serial-console `sed` in `diy-part2.sh` |
| Feeds | official `feeds.conf.default` (packages / luci / routing / telephony) plus the two Passwall feeds added by `diy-part1.sh` |
| LuCI | the official `luci` collection (status / system / network / firewall / package manager), HTTPS via `luci-ssl` (self-signed), UPnP IGD via `luci-app-upnp` + `miniupnpd-nftables` |
| Themes | `luci-theme-material` (default), `luci-theme-openwrt-2020`, `luci-theme-bootstrap` |
| Languages | ar, en, es, fr, ru, zh-cn, zh-tw — the six UN working languages |
| Microcode | `intel-microcode` + `amd64-microcode`, loaded from `/lib/firmware/{intel-ucode,amd-ucode}` at boot |
| Firewall | `firewall4` (nftables) plus the full legacy xtables stack for plug-ins |
| Extras | serial console disabled, `accept_ra=2` for WAN SLAAC, Material as the default theme regardless of package order |

## Network drivers (92 packages)

72 Ethernet controller drivers (69 in the table plus `vmxnet3`, `amazon-ena`
and `amd-xgbe` in the VM section) and 20 Ethernet PHY drivers. Counted per
driver package, not per chip.

| Vendor | Drivers | Count |
| --- | --- | --- |
| Intel | `e100` `e1000` `e1000e` `igb` `igbvf` `igc` `ixgbe` `ixgbevf` `i40e` `iavf` `ice` `dwmac-intel` | 12 |
| Realtek | `r8169` (RTL8111/8168/8125) `8139too` `8139cp` | 3 |
| Atheros/Qualcomm Attansic | `atl1` `atl1c` `atl1e` `atl2` `alx` | 5 |
| Aquantia / Marvell AQtion | `atlantic` (AQC107/108/111/112) | 1 |
| Broadcom | `tg3` `bnx2` `bnx2x` `bnxt-en` `b44` | 5 |
| NVIDIA nForce | `forcedeth` | 1 |
| Marvell / SysKonnect | `skge` `sky2` | 2 |
| Mellanox ConnectX | `mlx4-core` `mlx5-core` | 2 |
| Server / 10G+ | `qlcnic` `be2net` `sfc` `sfc-falcon` `sfc-siena` `hinic` `lan743x` `et131x` `mhi-net` | 9 |
| Legacy / soft-router | `natsemi` `ne2k-pci` `pcnet32` `tulip` `3c59x` `via-rhine` `via-velocity` `sis190` `sis900` `r6040` | 10 |
| USB Ethernet | `usb-net` `asix` `asix-ax88179` `aqc111` `cdc-ether` `cdc-eem` `cdc-ncm` `cdc-subset` `dm9601-ether` `kaweth` `lan78xx` `mcs7830` `pegasus` `rndis` `rtl8150` `rtl8152` `smsc75xx` `smsc95xx` `sr9700` | 19 |
| Virtual / cloud | `vmxnet3` `amazon-ena` `amd-xgbe` | 3 |
| PHY | `phy-realtek` `phy-marvell` `phy-marvell-10g` `phy-broadcom` `phy-aquantia` `phy-micrel` `phy-motorcomm` `phy-microchip` `phy-smsc` `phy-vitesse` `phy-amd` `phy-aeonsemi-as21xxx` `phy-airoha-en8811h` `phy-ax88796b` `phy-bcm7xxx` `phy-bcm84881` `phy-intel-xway` `phy-maxlinear` `phy-qca83xx` `phy-rtl8261n` | 20 |

Notes:

- `virtio-net`, `hv_netvsc`, `xen-netfront` and `veth` are built into the
  x86/64 kernel, so no package is needed for them (see the VM section below).
- The official tree has no `r8125` / `r8168`; 2.5G Realtek NICs are handled by
  `r8169`.
- `kmod-niu` was dropped: `niu` is SPARC-only and cannot be built for x86, the
  package would have ended up empty.
- `kmod-phy-at803x` was dropped as well: `AT803X_PHY` has `depends on REGULATOR`
  and `target/linux/generic/config-6.12` ships `# CONFIG_REGULATOR is not set`,
  so the symbol can never be built here. AR803x PHYs only appear on
  ARM/embedded boards.
- **Server/cloud adapters the official feed does not package are not shipped.**
  `enic` (Cisco VIC), `ionic` (AMD Pensando), `idpf` (Intel IPU),
  `libwx`/`ngbe`/`txgbe` (Wangxun), `nfp` (Netronome), `gve` (Google GVE) and
  `mana` (Azure ACCELNET) each needed a hand-written `kmod-*` package in a local
  `package/kernel/extra-nics/`. Selecting them makes kernel Kconfig prompts
  visible that none of the shipped config files answers, and
  `include/kernel-build.mk` exports `FAIL_ON_UNCONFIGURED=1` for the
  `$(LINUX_DIR)/.modules` target, so `scripts/kconfig/conf --syncconfig` exits 1
  at the first such prompt (the `... (NEW)` line in the log). A `default y` in
  the driver's own Kconfig does not help: `conf` looks for a value in `.config`
  (`SYMBOL_DEF_USER`), not for a default. Chasing those symbols one at a time
  kept breaking the build, so the whole local kmod tree was removed — history
  has it (`7b9ea03`, `6cc40a3`) if it is ever wanted back.
- Every remaining driver comes from the official feed, so the kernel config step
  needs no hand-written symbol at all.

## Virtual machines and cloud guests

No kernel config file has to be patched: OpenWrt writes the `KCONFIG` entry of
every selected `kmod-*` package into the kernel `.config` as `=m` by itself
(`scripts/package-metadata.pl` → `$(LINUX_DIR)/.config.override`, see
`include/kernel-defaults.mk`).

| Hypervisor / cloud | NIC | State |
| --- | --- | --- |
| KVM, QEMU, Proxmox, OpenStack, OCI, Alibaba, Tencent, Huawei Cloud | `virtio-net` | built in (`CONFIG_VIRTIO_NET=y`, `CONFIG_VIRTIO_PCI=y`) |
| Hyper-V, Azure Gen2 VMs | `hv_netvsc` | built in (`CONFIG_HYPERV_NET=y`, `CONFIG_PCI_HYPERV=y`, `CONFIG_HYPERVISOR_GUEST=y`) |
| Xen (older AWS EC2, some VPS) | `xen-netfront` | built in (`CONFIG_XEN_NETDEV_FRONTEND=y`) |
| Azure ACCELNET / newer Azure sizes | `mana` | **not shipped** (no official `kmod-mana`, see the NIC notes) |
| AWS Nitro (c5/m5/r5/t3 ...) | `ena` | `kmod-amazon-ena` |
| Google Compute Engine | `gve` (gVNIC) | **not shipped** (no official `kmod-gve`, see the NIC notes) |
| VMware ESXi / vSphere | `vmxnet3` | `kmod-vmxnet3` (plus `e1000e`) |
| Intel IPU / Mount Evans instances | `idpf` | **not shipped** (no official `kmod-idpf`, see the NIC notes) |

Also installed for guest use: `kmod-tun`, `kmod-veth`, `kmod-macvlan`,
`kmod-ipvlan`, `kmod-ifb`, `kmod-dummy`. `net_failover` / `failover` are built
in as well.

The Hyper-V and Xen drivers are compiled into the kernel (not modules) because
`target/linux/x86/64/config-6.12` already sets them to `=y`, so a Gen2 Azure VM
or a Xen guest gets its NIC before any module is loaded. Every Azure size whose
NIC is `mana`, and every GCE machine type that only offers gVNIC, will boot
without a network — use a hypervisor generation or machine type that exposes
`hv_netvsc`, `virtio-net` or `e1000e` instead.

## WAN protocols and IPv6

Available in "Network → Interfaces → Add new interface" (the list is the
intersection of the proto handlers reported by
`ubus call network get_proto_handlers` and the protocol UI modules that are
installed, so nothing whose back end is missing is offered):

| Entry | proto | Back end |
| --- | --- | --- |
| Static address | `static` | netifd (built in) |
| DHCP client | `dhcp` | netifd + busybox `udhcpc` |
| Unmanaged | `none` | LuCI |
| PPP | `ppp` | `ppp` |
| PPPoE | `pppoe` | `ppp` + `ppp-mod-pppoe` |
| DHCPv6 client | `dhcpv6` | `odhcp6c` (address + prefix delegation) |
| Relay bridge | `relay` | `relayd` + `luci-proto-relay` |

`diy-part2.sh` additionally removes the LuCI modules for **PPTP** and **PPPoA**
(`HIDE_UNUSABLE_PROTOS`), because `ppp.sh` registers those handlers although no
usable plug-in exists in 24.10/25.12 — without this they would show up in the
dialog and then fail.

Bonding is a **device**, not an interface protocol: with `kmod-bonding`
installed, LuCI offers "Bonding/Aggregation device" in "Devices → Add device
configuration" (the entry only appears when `/sys/module/bonding` exists).
Create the bond device there and then use one of the protocols above on top of
it. `proto-bonding` (legacy `proto bonding` for UCI) is installed as well but
has no upstream LuCI page.

IPv6 coverage: the kernel ships IPv6 built in, `odhcp6c` is the DHCPv6 client,
`odhcpd-ipv6only` provides RA (SLAAC) plus the DHCPv6 server for the LAN, and
`luci-proto-ipv6` provides the UI. Because OpenWrt's `/etc/init.d/sysctl` forces
`accept_ra=0` on all interfaces, `files/etc/sysctl.d/20-ipv6-accept-ra.conf` sets
`accept_ra=2` so that WAN SLAAC works out of the box; comment those lines out if
you want strict RA filtering.

## iptables / ip6tables support

`firewall4` (nftables) stays the system firewall, but the complete **legacy**
xtables stack is built in as well, because most plug-ins still insert rules
through the classic tools:

- Userspace: `iptables-zz-legacy`, `ip6tables-zz-legacy`, `arptables-legacy`,
  `ebtables-legacy` (+ `ebtables-legacy-utils`), `ipset`. The nft variants are
  *not* installed, so `/usr/sbin/{ip,ip6,ar,eb}tables` all resolve to the legacy
  back end and `iptables -V` reports `(legacy)`.
- Tables: filter / mangle / nat / raw for both IPv4 and IPv6
  (`kmod-ipt-{core,nat,raw}`, `kmod-ip6tables`, `kmod-ipt-nat6`,
  `kmod-ipt-raw6`, `kmod-ip6tables-extra`), bridge and ARP tables
  (`kmod-ebtables`, `-ipv4`, `-ipv6`, `kmod-arptables`), ipset
  (`kmod-ipt-ipset` + `ipset`) and flow offload (`kmod-ipt-offload`).
- 21 IPv4 extension packages from iptables itself (extra, conntrack-extra,
  conntrack-label, filter, hashlimit, ipopt, iprange, ipsec, nat-extra, nflog,
  nfqueue, physdev, rpfilter, socket, tee, tproxy, trace, u32, checksum,
  cluster, led) plus `ip6tables-extra` / `ip6tables-mod-nat`.
- 22 extra extension packages from xtables-addons (account, asn, chaos,
  condition, delude, dhcpmac, dnetmap, fuzzy, geoip, iface, ipmark, ipp2p,
  ipv4options, length2, logmark, lscan, proto, psd, quota2, rtpengine, sysrq,
  tarpit).
- `CONFIG_IPTABLES_CONNLABEL=y` is required for
  `iptables-mod-conntrack-label`.

Only `iptables-mod-lua` is left out (it would pull a full Lua runtime); add it
if a plug-in really needs the Lua PacketScript match.

## Passwall

`diy-part1.sh` prepends two feeds from the **Openwrt-Passwall organisation** (the
project moved away from the `xiaorouji` account, the old URLs return 404):

```
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci     https://github.com/Openwrt-Passwall/openwrt-passwall.git;main
```

They are placed first so their packages win over the identically named ones in
the official feeds (`xray-core`, `sing-box`, `microsocks`, `smartdns`).

Only the **sing-box (1.14.4)** and **Hysteria 2 (2.13.0)** cores are built;
every other `INCLUDE_*` option is switched off (Xray, V2ray-Plugin,
Shadowsocks-Rust which would pull the Rust toolchain, ShadowsocksR, Simple-Obfs,
SmartDNS, Haproxy, NaiveProxy, Shadow-TLS).

Two extras are included on purpose:

- `geoview` — Passwall converts the geosite/geoip tags into sing-box `.srs`
  rule-sets with it; without the binary split routing is disabled.
- `v2ray-geodata` — `geoip.dat` and `geosite.dat` from Loyalsoldier are
  downloaded at build time and installed to `/usr/share/v2ray/`, so split
  routing works on first boot even when the router cannot reach GitHub to run
  Passwall's online rule update.

Transparent proxy runs in nftables mode (`firewall4`), which is selected
automatically, and the required `dnsmasq-full` / `ip-full` /
`kmod-nft-tproxy` / `kmod-nft-socket` packages were already part of the base
config. LuCI entry point: **Services → Passwall**.

## Languages

All six UN working languages are installed — **Arabic (`ar`), Chinese Simplified
(`zh_Hans` / `zh-cn`), Chinese Traditional (`zh_Hant` / `zh-tw`), English
(source language, needs no package), French (`fr`), Russian (`ru`), Spanish
(`es`)**.

`.diffconfig` sets `CONFIG_LUCI_LANG_{ar,es,fr,ru,zh_Hans,zh_Hant}`. In `luci.mk`
every translation package is declared as
`DEFAULT:=LUCI_LANG_<lang>||(ALL&&m)`, and kconfig only honours that default
when the parent component is selected as well, so exactly the components that
are built receive the six languages and no unused app is pulled in:

| Component | Languages |
| --- | --- |
| `luci-base` (includes the `luci-mod-system` / `-network` / `-status` strings — in 25.12 they live in `luci-base.po`) | ar, es, fr, ru, zh-cn, zh-tw |
| `luci-app-firewall` | ar, es, fr, ru, zh-cn, zh-tw |
| `luci-app-upnp` | ar, es, fr, ru, zh-cn, zh-tw |
| `luci-app-package-manager` | ar, es, fr, ru, zh-cn, zh-tw |
| `luci-app-passwall` | zh-cn only — upstream ships no other translation |

The language is selected in **System → System → Language and Style**; Arabic
switches the themes to right-to-left on its own. Adding another language later
is one `CONFIG_LUCI_LANG_<lang>` line (the known languages are listed in
`feeds/luci/luci.mk`) plus a rebuild.

**Passwall caveat:** the upstream `openwrt-passwall` feed only carries
`po/zh_Hans`, so its pages stay English for ar/es/fr/ru/zh-tw. Translating it
means committing a `.po` file into the Passwall feed — a feed change, not a
configuration change, so it is not done here.

## LuCI themes

Three official themes are installed, so the "Theme" selector appears under
System → System → Language and Style:

| Theme | `mediaurlbase` | Notes |
| --- | --- | --- |
| Material | `/luci-static/material` | Material Design, colourful, dark mode toggle — **default** |
| OpenWrt 2020 | `/luci-static/openwrt2020` | flat design with the OpenWrt cyan accent |
| Bootstrap | `/luci-static/bootstrap` | upstream default, dark mode via `prefers-color-scheme` |

Each theme package ships a `30_luci-theme-*` script that writes
`luci.main.mediaurlbase`, and `/etc/init.d/boot` sources `/etc/uci-defaults` in
file-name order. `files/etc/uci-defaults/50-luci-theme` therefore runs after all
of them and sets Material, so the default does not depend on which theme package
happens to sort last. Change it at runtime with:

```
uci set luci.main.mediaurlbase=/luci-static/openwrt2020   # or /luci-static/bootstrap
uci commit luci
```

`luci-theme-openwrt` (the 18.06-era classic) is not installed. A third-party
theme such as Argon is not included either — it would need its Git repository
cloned into `package/` from `diy-part1.sh` (for example
`jerrykuku/luci-theme-argon` + `luci-app-argon-config`).

## Artifacts and flashing

Every successful build publishes the firmware directory as an Actions artifact and
the same files as a GitHub Release:

| File | Use |
| --- | --- |
| `openwrt-x86-64-generic-squashfs-combined-efi.img.gz` | **UEFI**, squashfs + writable overlay (recommended) |
| `openwrt-x86-64-generic-squashfs-combined.img.gz` | Legacy BIOS, squashfs + writable overlay |
| `openwrt-x86-64-generic-ext4-combined-efi.img.gz` / `…-combined.img.gz` | same, ext4 rootfs |
| `openwrt-x86-64-generic-{squashfs,ext4}-rootfs.img.gz` | root filesystem on its own |
| `openwrt-x86-64-generic-rootfs.tar.gz`, `openwrt-x86-64-generic-targz-rootfs.tar.gz` | container / manual extraction |
| `…-kernel.bin` | kernel and initramfs bundle |
| `…-manifest`, `sha256sums`, `profiles.json`, `config.buildinfo`, `feeds.buildinfo`, `version.buildinfo` | package list, checksums, build metadata |

Flash it with `dd`, balenaEtcher or Rufus, or from an existing OpenWrt with
`sysupgrade -n /tmp/openwrt-x86-64-generic-squashfs-combined-efi.img.gz`. On
first boot the box answers at **`192.168.1.1`** with **no password** — set one
before exposing LuCI. Flashing later from LuCI itself works through
**System → Backup / Flash Firmware**, which is part of `luci-mod-system`; keep
"Keep settings" off when moving between squashfs and ext4 images.

## Updating and rebuilding

Two triggers, both on the built-in token:

- **`Build OpenWrt`** (`workflow_dispatch`, plus `repository_dispatch`) builds on
  demand. Pushing to `main` starts nothing.
- **`Update Checker`** runs monthly, on the 30th at 00:00 UTC (GitHub cron is
  UTC; February has no 30th, so that month is skipped), clones
  `openwrt/{openwrt,packages,luci,routing,telephony}` at `openwrt-25.12`, and
  compares the five HEAD hashes with the previous run through a cache marker.
  If anything moved it dispatches `openwrt_source_update`; if not, the run ends
  after the check.

`Update Checker` dispatches with `${{ github.token }}` (`contents: write`), which
works because GitHub's "events triggered by `GITHUB_TOKEN` do not create new
workflow runs" rule does **not** apply to `repository_dispatch` and
`workflow_dispatch`. No PAT, no secret, nothing to rotate — a fork is ready as
it is.

Housekeeping runs at the end of a build: old caches (dl archives, ccache
snapshots), runs older than a day and all but the ten newest releases are
deleted, with the built-in token as well.

**Changing `.diffconfig`** — the kernel Kconfig step fails on any *visible,
unanswered* prompt (`FAIL_ON_UNCONFIGURED=1`), and `default y` does not count as
an answer. The cheap checks first, in a local `openwrt-25.12` checkout:

```sh
cp /path/to/this/repository/.diffconfig .config
make defconfig          # a malformed .diffconfig fails here already
make prepare-tmpinfo    # only after touching package/ or adding a feed
```

The gate that actually bites is the kernel config stage. OpenWrt merges the
selected `kmod-*` `KCONFIG` entries into the kernel `.config`, then runs
`scripts/kconfig/conf` inside the unpacked kernel tree
(`build_dir/target-*/linux-*/linux-6.12.*`) with `FAIL_ON_UNCONFIGURED=1`, so
the first unanswered prompt ends the build. To audit that locally, start from
the freshly generated kernel `.config` and run:

```sh
ARCH=x86_64 SRCARCH=x86 srctree="$PWD" \
  scripts/kconfig/conf --listnewconfig Kconfig < /dev/null   # must print nothing
```

`--listnewconfig` lists every symbol that would be asked, instead of stopping at
the first one. Each `conf` run writes its answers back into `.config`, so copy a
fresh `.config` before every run — validating against the previous run's file
hides exactly the prompt that breaks CI.

## Repository layout

| File | Description |
| --- | --- |
| `.diffconfig` | Target and package configuration (copied to `openwrt/.config`) |
| `diy-part1.sh` | Hook before `feeds update`: adds the two Passwall feeds |
| `diy-part2.sh` | Hook after `feeds install`: serial console fix, removes unusable protocol UI modules |
| `files/` | Files copied into the image (`uci-defaults` theme default, IPv6 sysctl) |
| `.github/workflows/build-openwrt.yml` | Main build: source, feeds, compile, release upload, housekeeping |
| `.github/workflows/update-checker.yml` | Monthly upstream check, dispatch, release pruning |
| `.editorconfig` | Editor defaults (UTF-8, LF, final newline) |
| `LICENSE` | MIT, from the P3TERX template |

## FAQ

### Which image should I flash — EFI or BIOS, squashfs or ext4?

UEFI machines take `…squashfs-combined-efi.img.gz`, older BIOS boards
`…squashfs-combined.img.gz`. Squashfs keeps the root filesystem read-only and
puts your changes in an overlay, which is why a factory reset is possible and
why `sysupgrade` can keep settings; ext4 gives a plain writable root and larger
freedom, at the cost of that reset path. Most people want squashfs.

### Why `openwrt-25.12` and not the current stable 24.10?

Because of Go. 25.12 is the first branch whose toolchain is Go 1.26, and the
Passwall packages need it: on 24.10 (`go 1.23.12`) the build stops with
`go.mod requires go >= 1.25.5 (running go 1.23.12; GOTOOLCHAIN=local)` for
sing-box, hysteria and geoview. The trade-off is that 25.12 also switched the
package manager to `apk`, so opkg-only instructions no longer apply.

### Why are some server and cloud NIC drivers missing?

`enic`, `ionic`, `idpf`, `libwx`, `ngbe`, `txgbe`, `nfp`, `gve` and `mana` have
no `kmod-*` package in the official feed. Building them locally made kernel
Kconfig prompts visible that no shipped config answers, and OpenWrt runs
`conf --syncconfig` with `FAIL_ON_UNCONFIGURED=1`, so the build failed at the
first `... (NEW)` line. They were removed on purpose; use a machine type that
exposes `virtio-net`, `hv_netvsc`, `vmxnet3`, `e1000e` or `amazon-ena` instead.

### Why is the serial console disabled, and how do I get it back?

Official x86 images boot with `console=tty1 console=ttyS0,<baud>n8`, so
`/dev/console` is the serial port. On boards whose firmware exposes a COM port
or serial redirection (Intel AMT SOL, IPMI, a phantom SuperIO UART) every write
to that UART can stall, and the boot hangs for minutes. `diy-part2.sh` patches
`target/linux/x86/image/Makefile` and drops the serial console from both the
kernel command line and the GRUB terminal list. To get it back, set
`ENABLE_SERIAL_CONSOLE=1` at the top of `diy-part2.sh` and rebuild. Verify on the
running box:

```
cat /proc/cmdline     # expect only console=tty1
cat /proc/consoles
```

### Do I need a personal access token or any repository secret?

No. `Update Checker` dispatches the build with the built-in `GITHUB_TOKEN`
(`contents: write`), which is allowed to start a workflow because
`repository_dispatch` is one of the two events GitHub exempts from the
"`GITHUB_TOKEN` does not trigger workflows" rule. Release upload, release
pruning and cache cleanup all use the same token. A fresh fork works as it is.

### How do I update the firmware on a running box?

Either flash the newer image with "Keep settings" on, or let `Update Checker`
build it and download it from Releases. The build is reproducible from the same
`.diffconfig`, so an update changes the upstream sources and the Passwall
packages, not the local configuration.

### How do I change the default theme or language?

Theme: `uci set luci.main.mediaurlbase=…; uci commit luci`, or edit
`files/etc/uci-defaults/50-luci-theme` and rebuild to change the default.
Language: the LuCI selector under System → System → Language and Style; the six
languages are already installed.

### Why `apk` and not `opkg`?

25.12 replaced opkg with apk (`apk add`, `apk del`, `apk info`). LuCI's
"Software" page and Passwall were checked against it, but a third-party plug-in
whose script calls `opkg` directly will fail; change the script or skip the
plug-in.

### Is Attended Sysupgrade (`owut` / ASU) supported?

No. It would download images from a build server instead of using this
repository's configuration, so it is left out; the workflow and the releases are
the update path here.

### How do I add a package?

Add the `CONFIG_PACKAGE_<name>=y` line to `.diffconfig`, run the Kconfig checks
above, and trigger a build. A package from a new feed needs a `src-git` line in
`diy-part1.sh` (or in `feeds.conf.default`), plus `make prepare-tmpinfo` locally
if you want to validate before pushing.

### Does this run on any x86 CPU?

The target is `x86/64` with the generic device, i.e. 64-bit x86 with SSE2 — any
CPU from the last twenty years. It does not boot on 32-bit-only hardware or on
devices with a locked bootloader; this is PC firmware, not a router-vendor
image.

## License

**[MIT](LICENSE)**, inherited from the [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
template this repository started from — the copyright line stays as P3TERX wrote
it. OpenWrt itself is GPL-2.0 and every package keeps its own licence, so the
**firmware images in the releases are a GPL-2.0 aggregate**, not MIT:
[SOURCE.md](SOURCE.md) says where the corresponding source of a given image
lives, and every release attaches `SOURCES.txt` (the exact commits of OpenWrt
and each feed) and `config.buildinfo` (the full build configuration).

## Credits

- [P3TERX](https://github.com/P3TERX/Actions-OpenWrt) — the original Actions build template
- [OpenWrt](https://github.com/openwrt/openwrt) — the source, feeds and packages
- [Openwrt-Passwall](https://github.com/Openwrt-Passwall) — Passwall packages and LuCI app

---

*Keywords: OpenWrt x86, OpenWrt x86-64, OpenWrt firmware builder, GitHub Actions
OpenWrt, openwrt-25.12, kernel 6.12, apk package manager, x86 router, soft
router, mini-PC router, Passwall, sing-box, Hysteria 2, LuCI, luci-ssl, UPnP
IGD, KVM OpenWrt, Proxmox OpenWrt, Hyper-V OpenWrt, Xen OpenWrt, VMware OpenWrt,
AWS Nitro ena, Intel microcode, Realtek r8169, Intel igc, i40e, mlx5, iptables
legacy, nftables tproxy, UEFI OpenWrt, Legacy BIOS OpenWrt, squashfs combined,
ext4 combined, sysupgrade.*

