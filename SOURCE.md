# Source of a published firmware image

The repository itself — the workflows, `.diffconfig`, `diy-part1.sh`,
`diy-part2.sh` and the `files/` overlay — is MIT (see [LICENSE](LICENSE)) and is
the complete build recipe. The **firmware inside each release is GPL-2.0 and
friends**: the OpenWrt build system, the kernel and the packages keep their
upstream licences. Nothing in it is closed, and every release states where its
source is:

1. `SOURCES.txt`, attached to every release, pins the exact commit of OpenWrt and
   of each feed the image was built from. One line per repository —
   `name ref commit url` — so it names the branch, the 40-character commit and
   where to fetch it; the `build-config` line does the same for this repository.
2. `REPRODUCE.txt`, also attached, carries the same revisions in the form the
   `Build OpenWrt` workflow takes: `source_commit=` and `feed_commit=`.
3. `PACKAGES.txt` lists every installed package with its version, `NOTICES.txt`
   groups those packages by the licence they declare, and `sbom.spdx.json` is
   the SPDX SBOM of the release directory. `SHA256SUMS` covers all of it, and
   every file is bound to the workflow run that produced it by a GitHub artifact
   attestation (`gh attestation verify <file> -R <owner>/<repo>`).
4. `config.buildinfo` is the full `.config` the image was built
   with — every package and every version-suffixed symbol in it.
5. The build configuration is `.diffconfig` at the commit the release tag points
   to (`git checkout <tag>` in this repository).

To read or rebuild the source of any GPL-2.0 component:

```
git clone https://github.com/openwrt/openwrt -b openwrt-25.12
cd openwrt
git checkout "$(awk '$1=="openwrt"{print $3}' SOURCES.txt)"
./scripts/feeds update -a
./scripts/feeds install -a
```

The feeds are the official `packages`, `luci`, `routing`, `telephony` and
`video` feeds from `feeds.conf.default`, plus the two Passwall feeds that
`diy-part1.sh` prepends (`Openwrt-Passwall/openwrt-passwall-packages` and
`Openwrt-Passwall/openwrt-passwall`, branch `main`). Their commits are recorded
in `SOURCES.txt` like every other repository, so the Passwall part of a released
image is pinned too — the feeds are not rebuilt from whatever `main` points to
on the day someone reads the offer.

The only changes this recipe makes to upstream sources are the two edits in
`diy-part2.sh` (strip the serial console from the x86 GRUB config, hide the
`pppoa`/`pptp` LuCI protocol entries). They live in this repository as scripts,
not as an opaque patch queue, so the diff against upstream is readable in full.
