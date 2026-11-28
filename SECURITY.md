# Security policy

This repository builds an image; it does not write the software inside it. The
kernel, LuCI, netifd, the 92 driver packages, Passwall and its sing-box and
Hysteria 2 binaries all come from the official `openwrt/openwrt` branch
`openwrt-25.12` and the official feeds. A vulnerability in one of them belongs to
its own upstream: this repository pins the commits and builds them, it does not
patch them.

What is maintained here is the build: `.diffconfig`, the two edits
`diy-part2.sh` makes, the workflow that compiles and boot-tests the image, the
artefacts it publishes, and the documentation. A report belongs here when the
image differs from what this repository says it does.

## Reporting a vulnerability

Use GitHub's private reporting form: **Security → Report a vulnerability** on
<https://github.com/noelbennettz/actions-openwrt-x86>. It creates a private
advisory that only the maintainer can see, which is the place for technical
detail and for a proof of concept.

If that form is not available, open a normal issue whose title is exactly
`Security contact request` and whose body says nothing about the technical
details — a maintainer will open a private channel there.

Please do not open a public issue with a way into LuCI or into the network
without credentials, and do not test against routers you do not own.

There is no response-time guarantee: this is a one-person project maintained
alongside a full-time job. Reports are read and answered in the order they
arrive.

## Supported versions

Only the newest release is supported. Each release is tagged
`OpenWrt_openwrt-25.12_<YYYYMMDDHHMM>`, and its `SOURCES.txt` records the exact
`openwrt/openwrt` commit and feed commits it was built from, so a running router
can be traced back to source. An older release is a snapshot of upstream at that
date, not a branch: a fix here lands on `main` and in the next build.

## Scope

- In scope: the build configuration, the two `diy-part2.sh` edits, the workflow's
  permissions and artefacts, the checksums and the provenance attestation, and
  documentation that no longer matches the image.
- Out of scope: vulnerabilities in OpenWrt, the Linux kernel, Passwall, sing-box,
  Hysteria 2 or a driver package. Report those upstream; this repository picks
  them up when it rebuilds from a pinned or an updated source.
