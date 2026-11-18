#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# This script runs before './scripts/feeds update -a'.
# The official feeds.conf.default is used as-is, except for the Passwall feeds
# added below.
#
# Passwall moved from the 'xiaorouji' account to the 'Openwrt-Passwall'
# organisation (the old URLs return 404). Both feeds must be listed FIRST so that
# their package versions win over the identically named packages shipped by the
# official feeds (xray-core, sing-box, microsocks, smartdns): 'scripts/feeds
# install' skips a package that is already installed from an earlier feed.
if ! grep -q 'passwall_luci' feeds.conf.default; then
  {
    printf '%s\n' \
      'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main' \
      'src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main'
    cat feeds.conf.default
  } > feeds.conf.new
  mv feeds.conf.new feeds.conf.default
  echo "diy-part1: added Passwall feeds"
else
  echo "diy-part1: Passwall feeds already present"
fi

exit 0
