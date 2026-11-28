# actions-openwrt-x86 — builds an OpenWrt x86/64 image from official source on GitHub Actions

> This tree documents the current `main`. Each release pins the sources it was
> built from in `SOURCES.txt`, whose `build-config` line names the commit of this
> repository — the `DOCS.md` at that commit is the documentation that release
> was built with.

[![OpenWrt](https://img.shields.io/badge/OpenWrt-25.12-00B5E2)](https://github.com/openwrt/openwrt/tree/openwrt-25.12)
[![Target](https://img.shields.io/badge/target-x86%2F64%20generic-lightgrey)](DOCS.md#what-is-in-the-image)
[![Kernel](https://img.shields.io/badge/kernel-6.12-lightgrey)](.diffconfig)
[![NIC drivers](https://img.shields.io/badge/NIC%20drivers-92-blueviolet)](DOCS.md#network-drivers-92-packages)
[![Licence](https://img.shields.io/badge/licence-MIT-blue)](LICENSE)

The image comes from the official `openwrt/openwrt` branch `openwrt-25.12`
(kernel 6.12) and the official feeds plus two Passwall feeds. Everything else is
set in `.diffconfig`: Passwall with sing-box and Hysteria 2, seven languages (the
six official UN languages plus Traditional Chinese), three LuCI themes and 92
network driver packages (69 wired, 3 virtual, 20 PHY), on top of the stock
`x86/64` generic target. No package is forked — every one comes from an official
feed or from the Passwall feed. A successful run publishes the images as an
Actions artefact and as a GitHub Release. The only changes to upstream sources are
the two edits `diy-part2.sh` makes: a `sed` that drops the serial console, and the
removal of two LuCI protocol modules whose back end does not exist.

## Requirements

To use the images: any 64-bit x86 machine or hypervisor (KVM, Hyper-V, Xen,
VMware, Proxmox, AWS Nitro) with UEFI or Legacy BIOS boot, plus a way to write
the image to disk (`dd`, balenaEtcher, Rufus) — nothing to install on the box
that runs the firmware.

To fork and rebuild: a GitHub account with Actions enabled on the fork, and no
local toolchain — the build runs on `ubuntu-24.04` with the built-in
`GITHUB_TOKEN`, so no secret or personal access token is needed. A local build
instead needs a Linux host with the OpenWrt build dependencies (`gawk`, `flex`,
`bison`, `build-essential`).

## Use

Trigger **Actions → Build OpenWrt → Run workflow**, leave `source_commit` and
`feed_commit` empty, and wait about an hour. The very first build takes longer;
later runs reuse the package downloads and the compiler cache of the previous one.
The result appears as the artefact `OpenWrt_firmware_generic_<YYYYMMDDHHMM>` in
the run and as a release tagged `OpenWrt_openwrt-25.12_<YYYYMMDDHHMM>` under
**Releases**. To rebuild a release from exactly the same sources, paste the two
values of its `REPRODUCE.txt` into those inputs (`source_commit`, and the
`name=sha` pairs as `feed_commit`) — see
[DOCS.md#reproducing-a-published-release](DOCS.md#reproducing-a-published-release).

For flashing, pick one file and write it to the target disk:

- UEFI: `openwrt-x86-64-generic-squashfs-combined-efi.img.gz`
- Legacy BIOS: `openwrt-x86-64-generic-squashfs-combined.img.gz`
- same two layouts with an ext4 rootfs: `openwrt-x86-64-generic-ext4-combined-efi.img.gz`
  and `openwrt-x86-64-generic-ext4-combined.img.gz`

squashfs keeps the root filesystem read-only with a writable overlay, so a
factory reset and "keep settings" on `sysupgrade` stay available; ext4 gives a
plain writable root without that reset path. On first boot the box answers at
`192.168.1.1` with no password — set one before exposing LuCI.

## Documentation

| File | Contents |
| --- | --- |
| [DOCS.md](DOCS.md) | Image contents, all 92 network drivers, VM and cloud guests, WAN protocols and IPv6, iptables, Passwall, languages, themes, artefacts, rebuilding, repository layout, FAQ |
| [SOURCE.md](SOURCE.md) | Where the source of a published image is (GPL-2.0 offer, `SOURCES.txt`) |
| [SECURITY.md](SECURITY.md) | What is maintained here and what belongs upstream, the supported version, and how to report a vulnerability. |
| [.diffconfig](.diffconfig) | The complete build configuration |
| [`.github/workflows/build-openwrt.yml`](.github/workflows/build-openwrt.yml) | The build: checkout, feeds, compile, upload, housekeeping |
| [`.github/workflows/validate.yml`](.github/workflows/validate.yml) | Pull-request checks: lint, `.diffconfig` validation, `make defconfig` dry run (no compile) |
| [`.github/workflows/update-checker.yml`](.github/workflows/update-checker.yml) | Twice-monthly upstream check that dispatches a build |
| [`.github/workflows/smoke-qemu.yml`](.github/workflows/smoke-qemu.yml) | Boots a published image in QEMU and checks that LuCI answers |

## Licence

The build recipe in this repository — `.diffconfig`, `diy-part1.sh`,
`diy-part2.sh`, `files/` and the workflows — is [MIT](LICENSE), inherited from
the P3TERX template. The firmware images are an aggregate of OpenWrt (GPL-2.0)
and of packages that keep their own upstream licences, so a published image is
not MIT; [SOURCE.md](SOURCE.md) states where the corresponding source of a given
image is.
