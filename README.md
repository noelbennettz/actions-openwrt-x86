# Actions-OpenWrt (official source, x86)

A GitHub Actions firmware build repository based on the [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) template.

## Current state

- Source: **official OpenWrt** `https://github.com/openwrt/openwrt` (branch `openwrt-25.12`, kernel 6.12).
  The branch is not arbitrary: 25.12 is the first branch whose Go toolchain is 1.26, and the current
  passwall packages need it (sing-box >= 1.25.5, hysteria >= 1.26, geoview >= 1.25); 24.10 ships
  Go 1.23 and fails with `go.mod requires go >= 1.25.5 (running go 1.23.12; GOTOOLCHAIN=local)`.
- Feeds: the official `feeds.conf.default` (packages / luci / routing / telephony), no third-party feeds
- Config: `.diffconfig` (x86/64 generic), no custom patches and no private packages
- Package manager: **apk** (25.12 switched away from opkg); the LuCI "Software" page and
  passwall were checked for this, but note that any opkg-specific command in a plug-in will
  no longer apply
- CPU microcode: `intel-microcode` + `amd64-microcode`. The x86 kernel already has `CONFIG_MICROCODE` and
  `MICROCODE_LATE_LOADING` built in, so the blobs are loaded automatically at boot from
  `/lib/firmware/{intel-ucode,amd-ucode}`
- NICs: 80 network device drivers plus 20 PHY drivers (= the 100 entries below),
  including server adapters (Cisco VIC, AMD Pensando, Wangxun, Netronome) and the cloud NICs
  (`gve` for GCE, `mana` for Azure, `ena` for AWS, `vmxnet3` for VMware)
- VMs: KVM/QEMU (`virtio-net`), Hyper-V/Azure (`hv_netvsc`, `pci-hyperv`) and Xen
  (`xen-netfront`) are built into the x86/64 kernel; nothing to configure
- Languages: Arabic, Chinese (Simplified + Traditional), English, French, Russian and Spanish
  - all six UN working languages (see "Translations")
- LuCI: the official `luci` collection (status / system / network / firewall / package manager)
  plus HTTPS (`luci-ssl`, self-signed certificate) and UPnP IGD (`luci-app-upnp` + `miniupnpd-nftables`)
- Themes: `luci-theme-bootstrap` (upstream default), `luci-theme-openwrt-2020` (default look,
  see below) and `luci-theme-material`, so the theme drop-down is available in
  System → System → Language and Style
- Firmware flashing from the web UI: built into `luci-mod-system` ("Backup / Flash Firmware"),
  no extra package needed - it uploads an image to `/tmp/firmware.bin`, validates it with
  `sysupgrade --test`, shows the SHA256 and offers "Force upgrade". Attended Sysupgrade
  (ASU / `owut`) is deliberately not included.

## Network driver list (100 `CONFIG_PACKAGE_kmod-*` entries in `.diffconfig`)

79 Ethernet controller drivers plus 21 Ethernet PHY drivers. Counted per driver package, not
per chip - `r8169` alone covers RTL8111/8168/8125, `igc` covers I225/I226, `tg3` covers the
whole NetXtreme range.

| Vendor | Drivers | Count |
| --- | --- | --- |
| Intel | `e100` `e1000` `e1000e` `igb` `igbvf` `igc` `ixgbe` `ixgbevf` `i40e` `iavf` `ice` `idpf` `dwmac-intel` | 13 |
| Realtek | `r8169` (RTL8111/8168/8125) `8139too` `8139cp` | 3 |
| Atheros/Qualcomm Attansic | `atl1` `atl1c` `atl1e` `atl2` `alx` | 5 |
| Aquantia / Marvell AQtion | `atlantic` (AQC107/108/111/112) | 1 |
| Broadcom | `tg3` `bnx2` `bnx2x` `bnxt-en` `b44` | 5 |
| NVIDIA nForce | `forcedeth` | 1 |
| Marvell / SysKonnect | `skge` `sky2` | 2 |
| Mellanox ConnectX | `mlx4-core` `mlx5-core` | 2 |
| Server / 10G+ | `qlcnic` `be2net` `sfc` `sfc-falcon` `sfc-siena` `hinic` `lan743x` `et131x` `mhi-net` | 9 |
| Cisco / AMD Pensando / Wangxun / Netronome | `enic` `ionic` `ngbe` `txgbe` `nfp` (+ helper `libwx`) | 5 |
| Legacy / soft-router | `natsemi` `ne2k-pci` `pcnet32` `tulip` `3c59x` `via-rhine` `via-velocity` `sis190` `sis900` `r6040` | 10 |
| USB Ethernet | `usb-net` `asix` `asix-ax88179` `aqc111` `cdc-ether` `cdc-eem` `cdc-ncm` `cdc-subset` `dm9601-ether` `kaweth` `lan78xx` `mcs7830` `pegasus` `rndis` `rtl8150` `rtl8152` `smsc75xx` `smsc95xx` `sr9700` | 19 |
| Virtual / cloud | `vmxnet3` `amazon-ena` `gve` `mana` `amd-xgbe` | 5 |
| PHY | `phy-realtek` `phy-marvell` `phy-marvell-10g` `phy-broadcom` `phy-aquantia` `phy-micrel` `phy-motorcomm` `phy-microchip` `phy-smsc` `phy-vitesse` `phy-amd` `phy-aeonsemi-as21xxx` `phy-airoha-en8811h` `phy-ax88796b` `phy-bcm7xxx` `phy-bcm84881` `phy-intel-xway` `phy-maxlinear` `phy-qca83xx` `phy-rtl8261n` | 20 |

Notes:

- `virtio-net`, `hv_netvsc`, `xen-netfront` and `veth` are built into the x86/64 kernel, no
  package is needed for them (see the VM section below).
- The official tree has no `r8125` / `r8168`, 2.5G Realtek NICs are handled by `r8169`.
- `kmod-niu` was dropped: `niu` is SPARC-only and cannot be built for x86, the package would
  have ended up empty.
- `kmod-phy-at803x` was dropped as well: `AT803X_PHY` has `depends on REGULATOR` and
  `target/linux/generic/config-6.12` ships `# CONFIG_REGULATOR is not set`, so the symbol can
  never be built here. The AR803x PHYs only appear on ARM/embedded boards.
- Nine of the packages above (`enic`, `ionic`, `idpf`, `ngbe`, `txgbe`, `libwx`,
  `nfp`, `gve`, `mana`) are **not** in the official feed. Their `kmod-*` definitions live in
  `kernel-modules/Makefile`, and `diy-part1.sh` copies them to
  `openwrt/package/kernel/extra-nics/` before `make defconfig`, otherwise those symbols
  would be unknown and silently dropped.
- That local package file also flips two vendor switches back on. `generic/config-6.12`
  ships `# CONFIG_NET_VENDOR_WANGXUN is not set` and
  `# CONFIG_NET_VENDOR_MICROSOFT is not set`; without `CONFIG_NET_VENDOR_WANGXUN=y` /
  `CONFIG_NET_VENDOR_MICROSOFT=y` kconfig silently drops `LIBWX`/`NGBE`/`TXGBE`/
  `MICROSOFT_MANA` and the packages would be built empty (no error, just a warning).
- `IDPF_SINGLEQ` and `NFP_DEBUG` are bools with no default in the kernel Kconfig, so they
  must be given an explicit value in `kernel-modules/Makefile`; otherwise the
  non-interactive `make syncconfig` aborts with `... (NEW)`.
- `kmod-i2c-designware-platform` is pulled in by `txgbe` (it drives the SFP cage) and is not
  counted among the 100.

## KVM guests and cloud VMs

No kernel config file has to be patched: OpenWrt writes the `KCONFIG` entry of every selected
`kmod-*` package into the kernel `.config` as `=m` by itself
(`scripts/package-metadata.pl` -> `$(LINUX_DIR)/.config.override`, see
`include/kernel-defaults.mk`).

| Hypervisor / cloud | NIC | State |
| --- | --- | --- |
| KVM, QEMU, Proxmox, OpenStack, OCI, Alibaba, Tencent, Huawei Cloud | `virtio-net` | built in (`CONFIG_VIRTIO_NET=y`, `CONFIG_VIRTIO_PCI=y`) |
| Hyper-V, Azure Gen2 VMs | `hv_netvsc` | built in (`CONFIG_HYPERV_NET=y`, `CONFIG_PCI_HYPERV=y`, `CONFIG_HYPERVISOR_GUEST=y`) |
| Xen (older AWS EC2, some VPS) | `xen-netfront` | built in (`CONFIG_XEN_NETDEV_FRONTEND=y`) |
| Azure ACCELNET / newer Azure sizes | `mana` | `kmod-mana` |
| AWS Nitro (c5/m5/r5/t3 ...) | `ena` | `kmod-amazon-ena` |
| Google Compute Engine | `gve` (gVNIC) | `kmod-gve` |
| VMware ESXi / vSphere | `vmxnet3` | `kmod-vmxnet3` (plus `e1000e`) |
| Intel IPU / Mount Evans instances | `idpf` | `kmod-idpf` |

Also installed for guest use: `kmod-tun`, `kmod-veth`, `kmod-macvlan`, `kmod-ipvlan`,
`kmod-ifb`, `kmod-dummy`. `net_failover` / `failover` are built in as well.

The Hyper-V and Xen drivers are compiled into the kernel (not modules) because
`target/linux/x86/64/config-6.12` already sets them to `=y`, so a Gen2 Azure VM or a Xen
guest gets its NIC before any module is loaded.

## Translations

All six UN working languages are installed - **Arabic (`ar`), Chinese Simplified
(`zh_Hans` / `zh-cn`), Chinese Traditional (`zh_Hant` / `zh-tw`), English (source language,
needs no package), French (`fr`), Russian (`ru`), Spanish (`es`)**.

`.diffconfig` sets `CONFIG_LUCI_LANG_{ar,es,fr,ru,zh_Hans,zh_Hant}`. In `luci.mk` every
translation package is declared as `DEFAULT:=LUCI_LANG_<lang>||(ALL&&m)`, and kconfig only
honours that default when the parent component is selected as well, so exactly the
components that are built receive the six languages and no unused app is pulled in:

| Component | Languages |
| --- | --- |
| `luci-base` (includes the `luci-mod-system` / `-network` / `-status` strings - in 25.12 they live in `luci-base.po`) | ar, es, fr, ru, zh-cn, zh-tw |
| `luci-app-firewall` | ar, es, fr, ru, zh-cn, zh-tw |
| `luci-app-upnp` | ar, es, fr, ru, zh-cn, zh-tw |
| `luci-app-package-manager` | ar, es, fr, ru, zh-cn, zh-tw |
| `luci-app-passwall` | zh-cn only - upstream ships no other translation |

The language is selected in **System → System → Language and Style**; Arabic switches the
themes to right-to-left on its own. Adding another language later is one
`CONFIG_LUCI_LANG_<lang>` line (the known languages are listed in `feeds/luci/luci.mk`) plus
a rebuild.

**Passwall caveat:** the upstream `openwrt-passwall` feed only carries `po/zh_Hans`, so its
pages stay English for ar/es/fr/ru/zh-tw. Translating it means committing a `.po` file into
the passwall feed - a feed change, not a configuration change, so it is not done here.

## Artifacts

- `openwrt-x86-64-generic-squashfs-combined.img.gz` (Legacy BIOS)
- `openwrt-x86-64-generic-squashfs-combined-efi.img.gz` (UEFI)
- Builds are uploaded as Actions artifacts and published as GitHub Releases

## Files

| File | Description |
| --- | --- |
| `.github/workflows/build-openwrt.yml` | Main build workflow |
| `.github/workflows/update-checker.yml` | Polls the official sources and triggers a build on changes |
| `.diffconfig` | Target / package configuration (copied to `openwrt/.config`) |
| `diy-part1.sh` | Hook before `feeds update`: adds the Passwall feeds, installs `kernel-modules/` into `package/kernel/extra-nics/` |
| `diy-part2.sh` | Hook after `feeds install`: serial console fix, removes unusable protocol UI modules |
| `kernel-modules/Makefile` | `kmod-*` definitions for NIC drivers the official feed does not package (`enic`, `ionic`, `idpf`, `libwx`, `ngbe`, `txgbe`, `nfp`, `gve`, `mana`) |
| `files/` | Files copied into the image (default theme, sysctl) |

## Note on the serial console (boot stall fix)

Official x86 images always boot with `console=tty1 console=ttyS0,<baud>n8`, i.e. `/dev/console`
is the **serial port**. On machines whose firmware exposes a COM port or serial console
redirection (Intel AMT SOL, IPMI, phantom SuperIO UART) every write to that UART can stall,
which makes the boot hang for several minutes.

`diy-part2.sh` therefore patches `target/linux/x86/image/Makefile` and removes the serial
console from the kernel command line and from the GRUB terminal list, so the image boots on
the VGA console only. To get the serial console back, set `ENABLE_SERIAL_CONSOLE=1` at the
top of `diy-part2.sh` and rebuild. After boot you can verify with:

```
cat /proc/cmdline     # expect only console=tty1
cat /proc/consoles
```

## WAN protocols and IPv6

Available in "Network → Interfaces → Add new interface" (the list is the intersection of
the proto handlers reported by `ubus call network get_proto_handlers` and the protocol UI
modules that are installed, so nothing whose back end is missing is offered):

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
(`HIDE_UNUSABLE_PROTOS`), because `ppp.sh` registers those handlers although no usable
plug-in exists in 24.10/25.12 - without this they would show up in the dialog and then fail.

Bonding is a **device**, not an interface protocol: with `kmod-bonding` installed, LuCI
offers "Bonding/Aggregation device" in "Devices → Add device configuration" (the entry
only appears when `/sys/module/bonding` exists). Create the bond device there and then use
one of the protocols above on top of it. `proto-bonding` (legacy `proto bonding` for UCI)
is installed as well but has no upstream LuCI page.

IPv6 coverage: the kernel ships IPv6 built in, `odhcp6c` is the DHCPv6 client,
`odhcpd-ipv6only` provides RA (SLAAC) plus the DHCPv6 server for the LAN, and
`luci-proto-ipv6` provides the UI. Because OpenWrt's `/etc/init.d/sysctl` forces
`accept_ra=0` on all interfaces, `files/etc/sysctl.d/20-ipv6-accept-ra.conf` sets
`accept_ra=2` so that WAN SLAAC works out of the box; comment those lines out if you want
strict RA filtering.

## iptables / ip6tables support (for third-party plug-ins)

`firewall4` (nftables) stays the system firewall, but the complete **legacy** xtables
stack is built in as well, because most plug-ins still insert rules through the classic
tools:

- Userspace: `iptables-zz-legacy`, `ip6tables-zz-legacy`, `arptables-legacy`,
  `ebtables-legacy` (+ `ebtables-legacy-utils`), `ipset`. The nft variants are *not*
  installed, so `/usr/sbin/{ip,ip6,ar,eb}tables` all resolve to the legacy back end and
  `iptables -V` reports `(legacy)`.
- Tables: filter / mangle / nat / raw for both IPv4 and IPv6 (`kmod-ipt-{core,nat,raw}`,
  `kmod-ip6tables`, `kmod-ipt-nat6`, `kmod-ipt-raw6`, `kmod-ip6tables-extra`), bridge and
  ARP tables (`kmod-ebtables`, `-ipv4`, `-ipv6`, `kmod-arptables`), ipset
  (`kmod-ipt-ipset` + `ipset`) and flow offload (`kmod-ipt-offload`).
- 21 IPv4 extension packages from iptables itself (extra, conntrack-extra,
  conntrack-label, filter, hashlimit, ipopt, iprange, ipsec, nat-extra, nflog, nfqueue,
  physdev, rpfilter, socket, tee, tproxy, trace, u32, checksum, cluster, led) plus
  `ip6tables-extra` / `ip6tables-mod-nat`.
- 22 extra extension packages from xtables-addons (account, asn, chaos, condition, delude,
  dhcpmac, dnetmap, fuzzy, geoip, iface, ipmark, ipp2p, ipv4options, length2, logmark,
  lscan, proto, psd, quota2, rtpengine, sysrq, tarpit).
- `CONFIG_IPTABLES_CONNLABEL=y` is required for `iptables-mod-conntrack-label`.

Only `iptables-mod-lua` is left out (it would pull a full Lua runtime); add it if a plug-in
really needs the Lua PacketScript match.

## LuCI themes

Three official themes are installed, so the "Theme" selector appears under
System → System → Language and Style:

| Theme | `mediaurlbase` | Notes |
| --- | --- | --- |
| Material | `/luci-static/material` | Material Design, colourful, dark mode toggle - **default** |
| OpenWrt 2020 | `/luci-static/openwrt2020` | flat design with the OpenWrt cyan accent |
| Bootstrap | `/luci-static/bootstrap` | upstream default, dark mode via `prefers-color-scheme` |

Each theme package ships a `30_luci-theme-*` script that writes
`luci.main.mediaurlbase`, and `/etc/init.d/boot` sources `/etc/uci-defaults` in
file-name order. `files/etc/uci-defaults/50-luci-theme` therefore runs after all of them
and sets Material, so the default does not depend on which theme package happens to
sort last. Change it at runtime with:

```
uci set luci.main.mediaurlbase=/luci-static/openwrt2020   # or /luci-static/bootstrap
uci commit luci
```

`luci-theme-openwrt` (the 18.06-era classic) is not installed. A third-party theme such as
Argon is not included either - it would need its Git repository cloned into `package/`
from `diy-part1.sh` (e.g. `jerrykuku/luci-theme-argon` + `luci-app-argon-config`).

## Passwall

`diy-part1.sh` prepends two feeds from the **Openwrt-Passwall organisation** (the
project moved away from the `xiaorouji` account, the old URLs return 404):

```
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci     https://github.com/Openwrt-Passwall/openwrt-passwall.git;main
```

They are placed first so their packages win over the identically named ones in the
official feeds (`xray-core`, `sing-box`, `microsocks`, `smartdns`).

Only the **sing-box (1.14.4)** and **Hysteria 2 (2.13.0)** cores are built; every other
`INCLUDE_*` option is switched off (Xray, V2ray-Plugin, Shadowsocks-Rust which would pull
the Rust toolchain, ShadowsocksR, Simple-Obfs, SmartDNS, Haproxy, NaiveProxy, Shadow-TLS).

Two extras are included on purpose:

- `geoview` - passwall converts the geosite/geoip tags into sing-box `.srs` rule-sets with
  it; without the binary split routing is disabled.
- `v2ray-geodata` - `geoip.dat` and `geosite.dat` from Loyalsoldier are downloaded at
  build time and installed to `/usr/share/v2ray/`, so split routing works on first boot even
  when the router cannot reach GitHub to run passwall's online rule update.

Transparent proxy runs in nftables mode (`firewall4`), which is selected automatically, and
the required `dnsmasq-full` / `ip-full` / `kmod-nft-tproxy` / `kmod-nft-socket` packages
were already part of the base config.

LuCI entry point: **Services → Passwall**.

## Usage

1. Fork this repository.
2. Run `Build OpenWrt` manually from the Actions tab, or wait for `Update Checker` to detect source changes.
3. Download the firmware from the Release page after the build finishes.

Default login address is `192.168.1.1` with no password.

## Credits

- [P3TERX](https://github.com/P3TERX/Actions-OpenWrt)
- [OpenWrt](https://github.com/openwrt/openwrt)
