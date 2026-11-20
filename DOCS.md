# actions-openwrt-x86 — build and image documentation

> Applies to the current `main`. An older release keeps its documentation under
> `docs/versions/<tag>/`.

Everything about the image, the build and the repository that does not belong in
the short [README](README.md) lives here.

## Contents

- [What is in the image](#what-is-in-the-image)
- [Network drivers (92 packages)](#network-drivers-92-packages)
- [Virtual machines and cloud guests](#virtual-machines-and-cloud-guests)
- [WAN protocols and IPv6](#wan-protocols-and-ipv6)
- [iptables / ip6tables support](#iptables--ip6tables-support)
- [Passwall, sing-box and Hysteria 2](#passwall-sing-box-and-hysteria-2)
- [Languages](#languages)
- [LuCI themes](#luci-themes)
- [Artefacts and flashing](#artefacts-and-flashing)
- [Updating and rebuilding](#updating-and-rebuilding)
- [Repository layout](#repository-layout)
- [FAQ](#faq)
- [Credits](#credits)

## What is in the image

| Component | Choice |
| --- | --- |
| Source | official `openwrt/openwrt`, branch `openwrt-25.12`, kernel 6.12 |
| Target | `x86/64` device `generic`, 16 MB kernel partition, 1024 MB rootfs |
| Package manager | **apk**: 25.12 ships `package/system/apk`; LuCI's "Software" page and Passwall work with it, a plug-in script that calls `opkg` does not |
| Config | `.diffconfig` only — no patch files and no private packages. The only edits to upstream sources are in `diy-part2.sh`: three `sed` expressions on `target/linux/x86/image/Makefile` for the serial console, and the deletion of `pptp.js` and `pppoa.js` from `feeds/luci/protocols/luci-proto-ppp/htdocs/luci-static/resources/protocol/` |
| Feeds | official `feeds.conf.default` (packages / luci / routing / telephony / video) with the two Passwall feeds prepended by `diy-part1.sh` |
| LuCI | the official `luci` collection (status / system / network / firewall / package manager), HTTPS via `luci-ssl` (self-signed), UPnP IGD via `luci-app-upnp` + `miniupnpd-nftables` |
| Themes | `luci-theme-material` (default), `luci-theme-openwrt-2020`, `luci-theme-bootstrap` |
| Languages | ar, en, es, fr, ru, zh-cn, zh-tw |
| Microcode | `intel-microcode` + `amd64-microcode`, loaded from `/lib/firmware/{intel-ucode,amd-ucode}` at boot |
| Firewall | `firewall4` (nftables) plus the full legacy xtables stack for plug-ins |
| Extras | serial console disabled, `accept_ra=2` for WAN SLAAC, Material as the default theme regardless of package order |

The branch is `openwrt-25.12` and not 24.10 because of Go. The `go.mod` of the Go
programs in the Passwall feed declares `go 1.25.5` (sing-box 1.14.4) and `go
1.25.0` (geoview), and `lang/golang/golang-values.mk` on `openwrt-25.12` sets
`GO_DEFAULT_VERSION:=1.26`. The 24.10 feed ships Go 1.23.12, where the build stops
with `go.mod requires go >= 1.25.5 (running go 1.23.12; GOTOOLCHAIN=local)`.

The image boots on the VGA console only: `diy-part2.sh` strips the serial console
from `target/linux/x86/image/Makefile`, so a phantom UART (Intel AMT SOL, IPMI,
SuperIO) cannot stall the boot. `ENABLE_SERIAL_CONSOLE=1` at the top of
`diy-part2.sh` restores the upstream behaviour.

LuCI can flash an image by itself: the "Backup / Flash Firmware" page of
`luci-mod-system` uploads it to `/tmp/firmware.bin`, validates it with
`/sbin/sysupgrade --test`, prints the SHA256 and offers "Force upgrade"
(`modules/luci-mod-system/htdocs/luci-static/resources/view/system/flash.js`).
Attended Sysupgrade (`owut` / ASU) is not included.

Microcode: `target/linux/x86/64/config-6.12` ships
`CONFIG_MICROCODE_LATE_LOADING=y`, so `intel-microcode` and `amd64-microcode` are
loaded from `/lib/firmware/{intel-ucode,amd-ucode}` at boot without a kernel
config change.

## Network drivers (92 packages)

89 wired driver packages (69 Ethernet controllers plus 20 Ethernet PHYs) and the
three virtual NICs `vmxnet3`, `amazon-ena` and `amd-xgbe` in the same table: 92
`kmod-*` driver packages in `.diffconfig`, counted per driver package, not per
chip.

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

Every name in the table appears in `.diffconfig` as
`CONFIG_PACKAGE_kmod-<name>=y`, with the USB row spelled `kmod-usb-net-<name>`.
The package definitions come from the OpenWrt tree, not from a feed:
`package/kernel/linux/modules/netdevices.mk` and `.../usb.mk`, plus
`target/linux/x86/modules.mk` for `kmod-dwmac-intel` and `kmod-amd-xgbe`.

Notes:

- `virtio-net`, `hv_netvsc` and `xen-netfront` are built into the x86/64 kernel
  (`target/linux/x86/64/config-6.12`: `CONFIG_VIRTIO_NET=y`, `CONFIG_HYPERV_NET=y`,
  `CONFIG_XEN_NETDEV_FRONTEND=y`), so no package is needed for them. `veth` is a
  module and comes from `kmod-veth`.
- The official tree has no `r8125` / `r8168`; 2.5G Realtek NICs are handled by
  `r8169`.
- `kmod-niu` is not in the list: `niu` is SPARC-only and cannot be built for x86,
  the package would be empty.
- `kmod-phy-at803x` is not in the list either: `AT803X_PHY` has `depends on
  REGULATOR` and `target/linux/generic/config-6.12` ships `# CONFIG_REGULATOR is
  not set` (and `# CONFIG_AT803X_PHY is not set`), so the symbol can never be
  built here. AR803x PHYs only appear on ARM/embedded boards.
- **Server/cloud adapters the official feed does not package are not shipped.**
  `enic` (Cisco VIC), `ionic` (AMD Pensando), `idpf` (Intel IPU),
  `libwx`/`ngbe`/`txgbe` (Wangxun), `nfp` (Netronome), `gve` (Google GVE) and
  `mana` (Azure ACCELNET) have no `kmod-*` package. Adding them through a local
  `package/kernel/extra-nics/` tree does not work here: their drivers make kernel
  Kconfig prompts visible that none of the shipped config files answers, and
  `include/kernel-build.mk` exports `FAIL_ON_UNCONFIGURED=1` for the
  `$(LINUX_DIR)/.modules` target, so `scripts/kconfig/conf --syncconfig` exits 1
  at the first such prompt (the `... (NEW)` line in the log). A `default y` in
  the driver's own Kconfig does not help: `conf` looks for a value in `.config`
  (`SYMBOL_DEF_USER`), not for a default.
- Every driver in the list ships with the OpenWrt tree, so the kernel config step
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
| Azure ACCELNET / newer Azure sizes | `mana` | **not shipped** (no `kmod-mana`, see the NIC notes) |
| AWS Nitro (c5/m5/r5/t3 ...) | `ena` | `kmod-amazon-ena` |
| Google Compute Engine | `gve` (gVNIC) | **not shipped** (no `kmod-gve`, see the NIC notes) |
| VMware ESXi / vSphere | `vmxnet3` | `kmod-vmxnet3` (plus `e1000e`) |
| Intel IPU / Mount Evans instances | `idpf` | **not shipped** (no `kmod-idpf`, see the NIC notes) |

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

`diy-part2.sh` also removes the LuCI modules for **PPTP** and **PPPoA**
(`HIDE_UNUSABLE_PROTOS=1` deletes `pptp.js` and `pppoa.js` from the
`luci-proto-ppp` htdocs directory): `/lib/netifd/proto/ppp.sh` from the `ppp`
package registers both handlers, but the plug-ins behind them —
`ppp-mod-pptp` and `ppp-mod-pppoa` in
`package/network/services/ppp/Makefile` — are not selected, so both entries would
appear in the dialog and then fail.

`ppp` and `ppp-mod-pppoe` themselves are not named in `.diffconfig`: they arrive
through the `router` default package set (`DEVICE_TYPE?=router` in
`include/target.mk`, which also brings `dnsmasq`, `firewall4`, `nftables`,
`odhcp6c` and `odhcpd-ipv6only`; `dnsmasq-full` replaces `dnsmasq`).

Bonding is a **device**, not an interface protocol: with `kmod-bonding`
installed, LuCI offers "Bonding/Aggregation device" in "Devices → Add device
configuration" (the entry only appears when `/sys/module/bonding` exists).
Create the bond device there and then use one of the protocols above on top of
it. `proto-bonding` (legacy `proto bonding` for UCI) is installed as well but
has no upstream LuCI page.

IPv6 coverage: the kernel ships IPv6 built in, `odhcp6c` is the DHCPv6 client,
`odhcpd-ipv6only` provides RA (SLAAC) plus the DHCPv6 server for the LAN, and
`luci-proto-ipv6` provides the UI. Because OpenWrt's `/etc/init.d/sysctl` sets
`net.ipv6.conf.default.accept_ra` and every existing interface to `0`,
`files/etc/sysctl.d/20-ipv6-accept-ra.conf` sets
`net.ipv6.conf.all.accept_ra=2` and `net.ipv6.conf.default.accept_ra=2` so that
WAN SLAAC works out of the box; comment those lines out if you want strict RA
filtering.

Dual stack is complete out of the box: IPv4 (DHCPv4 and DNS) is served by
`dnsmasq-full`, IPv6 by `odhcpd-ipv6only`, and dnsmasq's init script detects the
running odhcpd and stays DHCPv4-only, so there are never two DHCPv6 servers on
the LAN. `firewall4` covers both families (the stock rules allow the DHCPv6
client reply and the essential ICMPv6 types) and no NAT66 rule is installed, so
globally addressed IPv6 stays end-to-end routable. The default `wan` is `dhcp`,
for which `bin/config_generate` creates `wan6` (`proto dhcpv6`) automatically;
with no `reqprefix` set, odhcp6c sends IA_PD without a length hint and accepts
whatever the ISP delegates.

### Downstream prefix delegation (LAN → child routers)

`odhcpd-ipv6only` is also a DHCPv6-PD server (`dhcpv6_pd` defaults to 1), so a
downstream router that asks with IA_PD receives a sub-prefix of the prefix
assigned to the LAN interface, and odhcpd installs the route back to that
router's link-local address — no extra route or firewall rule is needed. It
works when all of the following hold:

- the ISP delegates more than a single `/64` (`/60`, `/56`, …);
- `network.lan.ip6assign` is shorter than 64 — `bin/config_generate` sets `60`
  for a static LAN, which leaves room for delegation;
- `dhcp.lan.ra` and `dhcp.lan.dhcpv6` are `server` (`odhcpd.defaults` sets both at
  first boot when `network.lan.proto` is `static`) and `dhcp.lan.dhcpv6_pd` is `1`
  (`iface->dhcpv6_pd = true` in odhcpd's `src/config.c`).

`dhcpv6_pd_min_len` (default 62, `PD_MIN_LEN_DEFAULT` in odhcpd's
`src/config.c`) caps how large a block one requesting router may take: with the
default `/60` LAN a child router gets at most a `/62` (the `/60` pool yields about
three of them). Lower the value together with a shorter `ip6assign` when
downstream routers need larger blocks:

```
uci set network.lan.ip6assign='56'
uci set dhcp.lan.dhcpv6_pd_min_len='60'
uci commit; /etc/init.d/network reload; /etc/init.d/odhcpd restart
```

With only a `/64` from the ISP there is nothing left to delegate; use the relay
mode (`relayd` is installed) or ask the ISP for a larger prefix. To check a
running box, use `ifstatus wan6 | jsonfilter -e '@["ipv6-prefix"][*]'`,
`ubus call dhcp ipv6ra` and `ubus call dhcp ipv6leases`; on the child router,
`ifstatus wan6` shows the delegated prefix and its routes.

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

`iptables-mod-lua` is not installed: it pulls a full Lua runtime. Add
`CONFIG_PACKAGE_iptables-mod-lua=y` when a plug-in needs the Lua PacketScript
match.

## Passwall, sing-box and Hysteria 2

`diy-part1.sh` prepends two feeds from the **Openwrt-Passwall organisation** (the
old `xiaorouji` URLs return 404):

```
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci     https://github.com/Openwrt-Passwall/openwrt-passwall.git;main
```

They are placed first so their packages win over the identically named ones in
the official feeds (`xray-core`, `sing-box`, `microsocks`, `smartdns`).

Only the **sing-box** and **Hysteria 2** cores are built; every other
`INCLUDE_*` option is switched off (Xray, Xray-Plugin, V2ray-Plugin,
Shadowsocks-Rust which would pull the Rust toolchain, ShadowsocksR, Simple-Obfs,
SmartDNS, Haproxy, NaiveProxy, Shadow-TLS). The versions are whatever the feed's
`main` branch carries at build time; each release records them in
`feeds.buildinfo` and `SOURCES.txt`.

Two extras are included on purpose:

- `geoview` — Passwall converts the geosite/geoip tags into sing-box `.srs`
  rule-sets with it; without the binary split routing is disabled.
- `v2ray-geodata` — `geoip.dat` and `geosite.dat` from Loyalsoldier are
  downloaded at build time and installed to `/usr/share/v2ray/`, so split
  routing works on first boot even when the router cannot reach GitHub to run
  Passwall's online rule update.

Transparent proxy runs in nftables mode (`firewall4`), which is selected
automatically, and the required `dnsmasq-full` / `ip-full` /
`kmod-nft-tproxy` / `kmod-nft-socket` packages are part of the base config.
LuCI entry point: **Services → Passwall**.

## Languages

Seven languages are available: **Arabic (`ar`), English (source language, needs
no package), French (`fr`), Russian (`ru`), Spanish (`es`) and Simplified
Chinese (`zh_Hans` / `zh-cn`)** — the six official languages of the United
Nations — plus **Traditional Chinese (`zh_Hant` / `zh-tw`)**.

`.diffconfig` sets `CONFIG_LUCI_LANG_{ar,es,fr,ru,zh_Hans,zh_Hant}`. In `luci.mk`
every translation package is declared as
`DEFAULT:=LUCI_LANG_<lang>||(ALL&&m)`, and kconfig only honours that default
when the parent component is selected as well, so exactly the components that
are built receive the six translation packages and no unused app is pulled in:

| Component | Languages |
| --- | --- |
| `luci-base` (covers the `luci-mod-system` / `-network` / `-status` strings: those packages have no `po/` directory of their own, their strings are in `luci-base`) | ar, es, fr, ru, zh-cn, zh-tw |
| `luci-app-firewall` | ar, es, fr, ru, zh-cn, zh-tw |
| `luci-app-upnp` | ar, es, fr, ru, zh-cn, zh-tw |
| `luci-app-package-manager` | ar, es, fr, ru, zh-cn, zh-tw |
| `luci-app-passwall` | zh-cn only — upstream ships no other translation |

The language is selected in **System → System → Language and Style**; Arabic
switches the themes to right-to-left on its own. Adding another language later
is one `CONFIG_LUCI_LANG_<lang>` line (the known languages are listed in
`feeds/luci/luci.mk`) plus a rebuild.

**Passwall caveat:** `luci-app-passwall/po/` in the upstream feed holds only
`zh-cn` (with `zh_Hans` as a symlink to it), so its pages stay English for
ar/es/fr/ru/zh-tw. Translating it means committing a `.po` file into the Passwall
feed — a feed change, not a configuration change, so it is not done here.

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

## Artefacts and flashing

A successful build publishes the firmware directory as an Actions artefact named
`OpenWrt_firmware_generic_<YYYYMMDDHHMM>` and the same files as a GitHub Release
tagged `OpenWrt_openwrt-25.12_<YYYYMMDDHHMM>`. Both names are built in
`build-openwrt.yml` from `DEVICE_NAME` (the profile part of
`CONFIG_TARGET_x86_64_DEVICE_generic`) and `FILE_DATE` (`date +%Y%m%d%H%M` with
`TZ: Asia/Shanghai`, so the stamp is Shanghai local time). The release assets are
the exact contents of `openwrt/bin/targets/x86/64/` (the `packages/` subdirectory
is removed) plus `SOURCES.txt`; the release notes carry the
`git log --since=24.hour` of `openwrt` and of the feeds `packages`, `luci`,
`routing` and `telephony`, followed by a `## Source` section pointing at the
branch and the `.diffconfig` commit.

| File | Use |
| --- | --- |
| `openwrt-x86-64-generic-squashfs-combined-efi.img.gz` | **UEFI**, squashfs + writable overlay (recommended) |
| `openwrt-x86-64-generic-squashfs-combined.img.gz` | Legacy BIOS, squashfs + writable overlay |
| `openwrt-x86-64-generic-ext4-combined-efi.img.gz` / `openwrt-x86-64-generic-ext4-combined.img.gz` | same, ext4 rootfs |
| `openwrt-x86-64-generic-{squashfs,ext4}-rootfs.img.gz` | root filesystem on its own |
| `openwrt-x86-64-generic-rootfs.tar.gz`, `openwrt-x86-64-generic-targz-rootfs.tar.gz` | container / manual extraction (`CONFIG_TARGET_ROOTFS_TARGZ`) |
| `openwrt-x86-64-generic-kernel.bin` | kernel and initramfs bundle |
| `openwrt-x86-64-generic.manifest`, `sha256sums`, `profiles.json`, `config.buildinfo`, `feeds.buildinfo`, `version.buildinfo` | package list, checksums, build metadata |
| `SOURCES.txt` | exact commit of OpenWrt and of every feed (see [SOURCE.md](SOURCE.md)) |

Flash it with `dd`, balenaEtcher or Rufus, or from an existing OpenWrt with
`sysupgrade -n /tmp/openwrt-x86-64-generic-squashfs-combined-efi.img.gz`. On
first boot the box answers at **`192.168.1.1`** with **no password** — set one
before exposing LuCI (HTTPS works on the self-signed certificate from
`luci-ssl`). Flashing later from LuCI itself works through
**System → Backup / Flash Firmware**, which is part of `luci-mod-system`; keep
"Keep settings" off when moving between squashfs and ext4 images.

Squashfs keeps the root filesystem read-only and puts your changes in an overlay,
which is why a factory reset is possible and why `sysupgrade` can keep settings;
ext4 gives a plain writable root and more freedom, at the cost of that reset path.

What the first boot should look like: LuCI answers on `http://192.168.1.1` with no
password prompt, **System → System** shows the OpenWrt release and kernel 6.12,
**Network → Interfaces** lists a `wan` and a `lan`, and the package manager
(`apk` on 25.12) lists the packages from the image. A box that never answers on
`192.168.1.1` is usually booting from the wrong disk or has the wrong console
setting for the firmware you flashed.

Going back: there is no rollback partition. Flash another image the same way —
a stock `openwrt-x86-64-generic-…img.gz` from `downloads.openwrt.org`, or an
earlier release of this repository. `sysupgrade -n <image>` from LuCI or SSH
replaces the root filesystem and keeps no settings; writing the image to the
disk with `dd` replaces the partition table as well. Keep the previous image
file until the new one has booted.

## Boot smoke test (QEMU)

`.github/workflows/smoke-qemu.yml` boots the image the build just uploaded and
checks that it actually comes up — a separate workflow, so a hypervisor problem
can never block a release.

- It runs after every successful `Build OpenWrt`, and on demand with a run id
  (**Actions → QEMU boot smoke test → Run workflow**).
- It downloads the `OpenWrt_firmware*` artifact of that run (the same bytes the
  release carries), unpacks it and boots
  `openwrt-x86-64-generic-squashfs-combined.img.gz` with
  `qemu-system-x86_64 -machine q35 -m 512M -display none`.
- The guest's LAN subnet is handed to QEMU's user networking
  (`net=192.168.1.0/24,host=192.168.1.2`), so the host reaches the guest's
  `192.168.1.1:80` through slirp with a `hostfwd` on port 8080. The test passes
  when `/` answers with 200/302/307/308 **and** `/cgi-bin/luci/` serves a page
  that mentions LuCI.
- Serial output is captured to `qemu-serial.log` and uploaded as the
  `qemu-serial-log` artifact. **It is usually empty**, and that is expected:
  `diy-part2.sh` strips `console=ttyS0` from the kernel command line on purpose,
  so the image has no serial console to talk to. The HTTP probe is the real
  check; the log is there for the case where someone built with
  `ENABLE_SERIAL_CONSOLE=1`.
- No KVM on hosted runners, so the boot runs under TCG with a 15-minute budget.
  `scripts/qemu-smoke.sh` also runs locally (`scripts/qemu-smoke.sh <dir>`) and
  exits 0 with a warning when `qemu-system-x86_64` is not installed.

What it does **not** check: the guest's own package list (`apk info -v`) and
listening sockets, because there is no serial console and no password to log
in with. `PACKAGES.txt` in the release covers the package list from the target
manifest instead.

## Updating and rebuilding

Two triggers, both on the built-in token:

- **`Build OpenWrt`** (`.github/workflows/build-openwrt.yml`, `workflow_dispatch`
  plus `repository_dispatch`) builds on demand; a manual run also accepts an `ssh`
  input (`required: false`, `default: 'false'`; `true` opens a tmate session via
  `P3TERX/ssh2actions@v1.0.0`). Pushing to `main` starts nothing.
- **`Update Checker`** (`.github/workflows/update-checker.yml`) runs on
  `workflow_dispatch` and monthly, on the 30th at 00:00 UTC (GitHub cron is UTC;
  February has no 30th, so that month is skipped). It clones
  `openwrt/{openwrt,packages,luci,routing,telephony}` at `openwrt-25.12` and
  compares the five HEAD hashes with the previous run through the `HEAD-…` cache
  key. If anything moved it dispatches `openwrt_source_update`; if not, the run
  ends after the check.

`Update Checker` dispatches with `${{ github.token }}` (`contents: write`), which
works because GitHub's "events triggered by `GITHUB_TOKEN` do not create new
workflow runs" rule does **not** apply to `repository_dispatch` and
`workflow_dispatch`. No PAT, no secret, nothing to rotate — a fork is ready as
it is. The build job runs on `ubuntu-24.04` and reuses two caches: `openwrt/dl`
(key `openwrt-dl-<hash of .diffconfig>`) and the ccache/staging tree kept by
`klever1988/cachewrtbuild`.

Housekeeping runs at the end of a build: all `cache-openwrt*` (ccache) caches, the
`openwrt-dl-*` caches of older configurations, runs older than one day (at least
five kept) and all but the ten newest releases are deleted, with the built-in
token as well. `Update Checker` prunes more aggressively: five newest releases are
kept, the rest goes once it is older than 60 days or has fewer than two
downloads.

### Reproducing a published release

Every run resolves the source revisions *before* it clones anything and then
checks out exactly those commits, so a rerun cannot drift to a newer branch head:

1. `Resolve the source revision` pins the commit of `openwrt/openwrt` (the head
   of `openwrt-25.12`, or the `source_commit` input when one is given) and
   `Clone source code` checks it out detached and verifies `HEAD`.
2. `Update feeds` clones the seven feeds; `Pin feeds to the requested revisions`
   checks each one out at the `feed_commit` SHA when that input is set.
3. `Record source revisions` writes `SOURCES.txt` — `name ref commit url` per
   repository, plus the `build-config` line of this repository — and fails the
   build if any recorded commit differs from the checked-out tree.
4. `REPRODUCE.txt` carries the same revisions as the two workflow inputs and is
   attached to the release next to `SOURCES.txt`.

To rebuild an existing release, take the `openwrt` line of its `SOURCES.txt`
for `source_commit`, and its feed lines as `name=sha` pairs for `feed_commit`:

```
source_commit=2ad8f1c…            (from the 'openwrt' line, third column)
feed_commit=packages=5f3a… luci=9c1… routing=… telephony=… video=… \
            passwall_packages=… passwall_luci=…
```

The same values are in `REPRODUCE.txt`, ready to paste. The image is still not
bit-identical to the original — ccache hits, the `dl/` mirror state and the
timestamps inside the archive can differ — but it is built from the same source.

### Building locally instead of on Actions

```sh
git clone https://github.com/openwrt/openwrt -b openwrt-25.12 openwrt
cd openwrt
cp /path/to/this/repository/.diffconfig .config   # the .diffconfig of this repo
make defconfig && make download -j"$(nproc)" && make -j"$(nproc)"
```

The `files/` overlay and the two `diy-part*.sh` hooks have to be applied in the
same order as the workflow does if the result is to match the CI image: `diy-part1.sh`
before `./scripts/feeds update -a`, `diy-part2.sh` after `./scripts/feeds install -a`.
On Ubuntu the kernel Kconfig step needs `gawk` (`mawk` has no `asort`), so
`sudo apt install gawk flex bison` before the first `make`; the workflow installs
the same packages.

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
| `files/` | Files copied into the image (`etc/uci-defaults/50-luci-theme` theme default, `etc/sysctl.d/20-ipv6-accept-ra.conf` IPv6 sysctl) |
| `.github/workflows/validate.yml` | Pull-request validation: lint, config check, `make defconfig` dry run (no compile) |
| `.github/workflows/build-openwrt.yml` | Main build: source, feeds, compile, release upload, housekeeping |
| `.github/workflows/update-checker.yml` | Monthly upstream check, dispatch, release pruning |
| `.github/dependabot.yml` | Weekly PRs that move the pinned action SHAs to the next release |
| `scripts/validate-diffconfig.sh` | Static check of `.diffconfig` (syntax, duplicates, kmod names vs upstream) |
| `scripts/check-defconfig.sh` | Verifies every requested symbol survived `make defconfig` |
| `scripts/prune-runs.sh` | Keeps the newest N runs of the running workflow |
| `scripts/qemu-smoke.sh` | Boots a built image in QEMU and probes LuCI from the host |
| `.editorconfig` | Editor defaults (UTF-8, LF, final newline) |
| `README.md` | Short overview: requirements, use, documentation index, licence |
| `DOCS.md` | This file |
| `SOURCE.md` | Where the source of a published image is |
| `LICENSE` | MIT, from the P3TERX template |

Every third-party action in `.github/workflows/` is pinned by full commit SHA
with its release tag in a trailing comment, so a run executes exactly the code
that was reviewed — a moved or re-pointed tag cannot change what runs.
`.github/dependabot.yml` opens a weekly PR that rewrites both the SHA and the
comment; `klever1988/cachewrtbuild` publishes no tags and is bumped by hand.

### What a pull request runs

`.github/workflows/validate.yml` runs on every pull request (and on `main`, and
weekly) and takes minutes, not hours:

| Job | Checks |
| --- | --- |
| `lint` | `actionlint` on the workflows (it runs `shellcheck` on every `run:` block), `shellcheck` on `scripts/*.sh` and the hooks, every YAML parses, every action is pinned to a 40-character SHA, `git diff --check` plus a conflict-marker scan |
| `config` | `.diffconfig` syntax and duplicate symbols, the target/device selection, the Passwall feed lines in `diy-part1.sh`, and every `kmod-*` package against the `KernelPackage/…` definitions of the pinned `openwrt-25.12` tree |
| `config-dry` | clone OpenWrt, add the feeds, `feeds update -a`, `feeds install -a`, `diy-part2.sh`, `make defconfig`, then `scripts/check-defconfig.sh` — every symbol `.diffconfig` asks for has to survive |

Nothing in that workflow compiles a package, publishes an artefact or touches a
release; it runs with `contents: read`. The firmware build stays manual
(**Actions → Build OpenWrt**) and is additionally dispatched by the update
checker when upstream moves.

## FAQ

### Which image should I flash — EFI or BIOS, squashfs or ext4?

UEFI machines take `openwrt-x86-64-generic-squashfs-combined-efi.img.gz`, older
BIOS boards `openwrt-x86-64-generic-squashfs-combined.img.gz`. Squashfs keeps the
root filesystem read-only and puts your changes in an overlay, which is why a
factory reset is possible and why `sysupgrade` can keep settings; ext4 gives a
plain writable root, at the cost of that reset path. Most people want squashfs.

### Why `openwrt-25.12` and not the current stable 24.10?

Because of Go. `lang/golang/golang-values.mk` on `openwrt-25.12` sets
`GO_DEFAULT_VERSION:=1.26`, and the Go programs in the Passwall feed declare
`go 1.25.5` (sing-box 1.14.4) and `go 1.25.0` (geoview) in their `go.mod`. On
24.10, whose feed ships Go 1.23.12, the build stops with
`go.mod requires go >= 1.25.5 (running go 1.23.12; GOTOOLCHAIN=local)`. The
trade-off is that 25.12 also switched the package manager to `apk`, so opkg-only
instructions do not apply.

### Why are some server and cloud NIC drivers missing?

`enic`, `ionic`, `idpf`, `libwx`, `ngbe`, `txgbe`, `nfp`, `gve` and `mana` have
no `kmod-*` package, and adding one in a local `package/kernel/extra-nics/` tree
does not work either: their drivers expose kernel Kconfig prompts that no shipped
config file answers, and OpenWrt runs `conf --syncconfig` with
`FAIL_ON_UNCONFIGURED=1`, so the build stops at the first `... (NEW)` line. Use a
machine type that exposes `virtio-net`, `hv_netvsc`, `vmxnet3`, `e1000e` or
`amazon-ena` instead.

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
Language: the LuCI selector under System → System → Language and Style; the seven
languages are already installed.

### Why `apk` and not `opkg`?

25.12 replaced opkg with apk (`apk add`, `apk del`, `apk info`). LuCI's
"Software" page and Passwall work with it; a third-party plug-in whose script
calls `opkg` directly fails, so change the script or skip the plug-in.

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

## Credits

- [P3TERX](https://github.com/P3TERX/Actions-OpenWrt) — the original Actions build template
- [OpenWrt](https://github.com/openwrt/openwrt) — the source, feeds and packages
- [Openwrt-Passwall](https://github.com/Openwrt-Passwall) — Passwall packages and LuCI app
