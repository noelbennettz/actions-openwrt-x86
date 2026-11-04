#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# This script runs after the feeds are installed.
#
# ---------------------------------------------------------------------------
# Serial console on x86 (boot stall workaround)
# ---------------------------------------------------------------------------
# Upstream target/linux/x86/image/Makefile always emits
#   console=tty1 console=ttyS0,<baud>n8
# with the serial port LAST, which makes /dev/console the serial port, and it
# always adds "terminal_input serial" to the GRUB config.
#
# On boards whose firmware exposes a COM port / serial console redirection
# (Intel AMT SOL, IPMI, phantom SuperIO UART) every write to that UART can stall
# (the 8250 driver spins in wait_for_xmitr waiting for THRE). Because the boot
# scripts write to /dev/console, the boot then hangs for several minutes.
#
# Setting ENABLE_SERIAL_CONSOLE=0 (default) strips the serial console from the
# kernel command line and from the GRUB terminal list, so the image boots on the
# VGA console only. Set it to 1 to keep the upstream behaviour.
#
# NOTE: CONFIG_TARGET_SERIAL stays at its default ("ttyS0") on purpose, because
# target/linux/x86/base-files.mk aborts the build when it is empty.
ENABLE_SERIAL_CONSOLE=0

X86_IMAGE_MK=target/linux/x86/image/Makefile

if [ "$ENABLE_SERIAL_CONSOLE" = "0" ] && [ -f "$X86_IMAGE_MK" ]; then
  if grep -q 'diy-part2.sh: serial console disabled' "$X86_IMAGE_MK"; then
    echo "diy-part2: serial console already disabled, nothing to do"
  elif grep -q '^GRUB_TERMINALS += serial$' "$X86_IMAGE_MK"; then
    sed -i \
      -e 's|^GRUB_CONSOLE_CMDLINE += console=$(GRUB_SERIAL),.*|# diy-part2.sh: serial console disabled|' \
      -e 's|^GRUB_SERIAL_CONFIG := serial .*|GRUB_SERIAL_CONFIG :=|' \
      -e 's|^GRUB_TERMINALS += serial$|# diy-part2.sh: serial console disabled|' \
      "$X86_IMAGE_MK"
    if grep -q 'diy-part2.sh: serial console disabled' "$X86_IMAGE_MK"; then
      echo "diy-part2: serial console disabled (kernel cmdline will only use console=tty1)"
    else
      echo "diy-part2: ERROR - failed to patch $X86_IMAGE_MK" >&2
      exit 1
    fi
  else
    echo "diy-part2: ERROR - serial block not found in $X86_IMAGE_MK," >&2
    echo "diy-part2: upstream layout changed, please review the patch" >&2
    exit 1
  fi
else
  echo "diy-part2: serial console kept (upstream behaviour)"
fi

# ---------------------------------------------------------------------------
# Hide protocol entries that can never work with this package set
# ---------------------------------------------------------------------------
# LuCI builds the "Protocol" list in the Add-interface dialog from the handlers
# reported by 'ubus call network get_proto_handlers' (i.e. /lib/netifd/proto/*.sh
# on the device) intersected with the protocol UI modules that are installed, so
# everything whose back end package is missing is already hidden automatically
# (wireguard, 6in4, 6to4, 6rd, 464xlat, DS-Lite, MAP, L2TP, GRE, VXLAN, VTI, XFRM,
# IPIP, relay when relayd is absent, bonding ...).
#
# Exception: ppp.sh registers pppoa and pptp even though the matching plug-ins are
# not installed (24.10 has no PPTP client package at all and PPPoA needs
# ppp-mod-pppoa plus ATM support), so those two would be listed and then fail.
# Dropping their UI modules keeps the dialog limited to working protocols.
HIDE_UNUSABLE_PROTOS=1
PPPO_PROTO_DIR=feeds/luci/protocols/luci-proto-ppp/htdocs/luci-static/resources/protocol

if [ "$HIDE_UNUSABLE_PROTOS" = "1" ] && [ -d "$PPPO_PROTO_DIR" ]; then
  for p in pptp pppoa; do
    if [ -f "$PPPO_PROTO_DIR/$p.js" ]; then
      rm -f "$PPPO_PROTO_DIR/$p.js"
      echo "diy-part2: hidden unusable protocol '$p' (no working back end)"
    fi
  done
fi

# To change the default LAN IP, uncomment the line below:
#sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

exit 0
