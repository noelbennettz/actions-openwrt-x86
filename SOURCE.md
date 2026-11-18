# Source of a published firmware image

The repository itself — the workflows, `.diffconfig`, `diy-part1.sh`,
`diy-part2.sh` and the `files/` overlay — is MIT (see [LICENSE](LICENSE)) and is
the complete build recipe. The **firmware inside each release is GPL-2.0 and
friends**: the OpenWrt build system, the kernel and the packages keep their
upstream licences. Nothing in it is closed, and every release states where its
source is:

1. `SOURCES.txt`, attached to every release, pins the exact commit of OpenWrt and
   of each feed the image was built from.
2. `config.buildinfo`, also attached, is the full `.config` the image was built
   with — every package and every version-suffixed symbol in it.
3. The build configuration is `.diffconfig` at the commit the release tag points
   to (`git checkout <tag>` in this repository).

To read or rebuild the source of any GPL-2.0 component:

```
git clone https://github.com/openwrt/openwrt -b openwrt-25.12
cd openwrt
git checkout "$(awk '$1=="openwrt"{print $3}' SOURCES.txt)"
./scripts/feeds update -a
./scripts/feeds install -a
```

The feeds are the official `packages`, `luci`, `routing` and `telephony` feeds
from `feeds.conf.default`, plus the two Passwall feeds that `diy-part1.sh`
prepends (`Openwrt-Passwall/openwrt-passwall-packages` and
`Openwrt-Passwall/openwrt-passwall`, branch `main`).

The only changes this recipe makes to upstream sources are the two edits in
`diy-part2.sh` (strip the serial console from the x86 GRUB config, hide the
`pppoa`/`pptp` LuCI protocol entries). They live in this repository as scripts,
not as an opaque patch queue, so the diff against upstream is readable in full.
