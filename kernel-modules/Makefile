#
# Extra NIC drivers that the official OpenWrt feed (package/kernel/linux/
# modules/netdevices.mk) does not package, but that matter on x86: server
# adapters and the NICs handed out by cloud hypervisors.
#
# diy-part1.sh copies this directory to package/kernel/extra-nics before
# 'make defconfig', so the packages show up as kmod-enic, kmod-ionic,
# kmod-idpf, kmod-libwx, kmod-ngbe, kmod-txgbe, kmod-nfp, kmod-gve and
# kmod-mana.
#
# There is no need to touch the kernel config files: for every selected kmod
# package OpenWrt writes the driver symbol as =m into the kernel .config
# (scripts/package-metadata.pl -> $(LINUX_DIR)/.config.override, see
# include/kernel-defaults.mk). If a driver's Kconfig dependencies are not met
# the package is turned into an empty one and the build still succeeds, so the
# symbol names and object paths below are the only things that have to stay
# correct.
#
# Symbols and paths are taken from Linux 6.12 (the version openwrt-25.12
# builds):
#   drivers/net/ethernet/cisco/enic/Kconfig       -> CONFIG_ENIC
#   drivers/net/ethernet/pensando/Kconfig         -> CONFIG_IONIC
#   drivers/net/ethernet/wangxun/Kconfig          -> CONFIG_LIBWX/NGBE/TXGBE
#   drivers/net/ethernet/netronome/Kconfig        -> CONFIG_NFP
#   drivers/net/ethernet/google/Kconfig           -> CONFIG_GVE
#   drivers/net/ethernet/microsoft/Kconfig        -> CONFIG_MICROSOFT_MANA
#

include $(TOPDIR)/rules.mk

PKG_NAME:=extra-nics
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0-only

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/package.mk

# ---------------------------------------------------------------------------
# Cisco VIC Ethernet NIC (enic) - depends on PCI only
# ---------------------------------------------------------------------------
define KernelPackage/enic
  SUBMENU:=$(NETWORK_DEVICES_MENU)
  TITLE:=Cisco VIC Ethernet NIC support
  DEPENDS:=@PCI_SUPPORT
  KCONFIG:=CONFIG_ENIC
  FILES:=$(LINUX_DIR)/drivers/net/ethernet/cisco/enic/enic.ko
  AUTOLOAD:=$(call AutoLoad,35,enic)
endef

define KernelPackage/enic/description
 Kernel module for the Cisco Virtual Interface Card (VIC) Ethernet adapters.
endef

$(eval $(call KernelPackage,enic))

# ---------------------------------------------------------------------------
# AMD Pensando DSC (ionic)
# depends on 64BIT && PCI, selects NET_DEVLINK (bool -> y), DIMLIB (=y) and
# PAGE_POOL (=y in target/linux/x86/config-6.12)
# ---------------------------------------------------------------------------
define KernelPackage/ionic
  SUBMENU:=$(NETWORK_DEVICES_MENU)
  TITLE:=AMD Pensando Ethernet IONIC support
  DEPENDS:=@TARGET_x86_64 +kmod-ptp
  KCONFIG:=CONFIG_IONIC
  FILES:=$(LINUX_DIR)/drivers/net/ethernet/pensando/ionic/ionic.ko
  AUTOLOAD:=$(call AutoLoad,35,ionic)
endef

define KernelPackage/ionic/description
 Kernel module for the AMD Pensando (formerly Pensando Systems) DSC family
 of 25G/100G/200G Ethernet adapters.
endef

$(eval $(call KernelPackage,ionic))

# ---------------------------------------------------------------------------
# Intel Infrastructure Data Path Function (idpf) - IPU / Mount Evans
# depends on PCI_MSI, selects DIMLIB (=y) and LIBETH (packaged by the official
# feed as the hidden kmod-libeth)
# ---------------------------------------------------------------------------
define KernelPackage/idpf
  SUBMENU:=$(NETWORK_DEVICES_MENU)
  TITLE:=Intel Infrastructure Data Path Function support
  DEPENDS:=@PCI_SUPPORT +kmod-libeth
  KCONFIG:=CONFIG_IDPF
  FILES:=$(LINUX_DIR)/drivers/net/ethernet/intel/idpf/idpf.ko
  AUTOLOAD:=$(call AutoLoad,35,idpf)
endef

define KernelPackage/idpf/description
 Kernel module for Intel(R) Infrastructure Data Path Function devices
 (IPU / Mount Evans), used as the NIC of some cloud instances.
endef

$(eval $(call KernelPackage,idpf))

# ---------------------------------------------------------------------------
# Wangxun GbE/10GbE (ngbe / txgbe) + shared library (libwx)
# Both drivers select LIBWX, a module of its own, so it gets its own hidden
# package. txgbe additionally selects SFP, PCS_XPCS and MARVELL_10G_PHY and
# needs the DesignWare I2C platform driver (it bit-bangs the SFP cage).
# ---------------------------------------------------------------------------
define KernelPackage/libwx
  SUBMENU:=$(NETWORK_DEVICES_MENU)
  TITLE:=Wangxun Ethernet common library
  KCONFIG:=CONFIG_LIBWX
  HIDDEN:=1
  FILES:=$(LINUX_DIR)/drivers/net/ethernet/wangxun/libwx/libwx.ko
endef

define KernelPackage/libwx/description
 Shared library used by the Wangxun ngbe and txgbe Ethernet drivers.
endef

$(eval $(call KernelPackage,libwx))

define KernelPackage/ngbe
  SUBMENU:=$(NETWORK_DEVICES_MENU)
  TITLE:=Wangxun GbE PCI Express adapters support
  DEPENDS:=@PCI_SUPPORT +kmod-libwx +kmod-phylink
  KCONFIG:=CONFIG_NGBE
  FILES:=$(LINUX_DIR)/drivers/net/ethernet/wangxun/ngbe/ngbe.ko
  AUTOLOAD:=$(call AutoLoad,35,ngbe)
endef

define KernelPackage/ngbe/description
 Kernel module for the Wangxun(R) GbE/2.5GbE PCI Express adapters
 (WX1820, N500/N510 series).
endef

$(eval $(call KernelPackage,ngbe))

define KernelPackage/txgbe
  SUBMENU:=$(NETWORK_DEVICES_MENU)
  TITLE:=Wangxun 10GbE PCI Express adapters support
  DEPENDS:=@PCI_SUPPORT +kmod-libwx +kmod-phylink +kmod-sfp +kmod-pcs-xpcs \
	+kmod-phy-marvell-10g +kmod-i2c-designware-platform
  KCONFIG:=CONFIG_TXGBE
  FILES:=$(LINUX_DIR)/drivers/net/ethernet/wangxun/txgbe/txgbe.ko
  AUTOLOAD:=$(call AutoLoad,35,txgbe)
endef

define KernelPackage/txgbe/description
 Kernel module for the Wangxun(R) 10GbE PCI Express adapters
 (TX201, WX1860 series).
endef

$(eval $(call KernelPackage,txgbe))

# ---------------------------------------------------------------------------
# Netronome NFP4000/NFP6000 SmartNIC (nfp)
# depends on PCI_MSI, VXLAN (or VXLAN=n) and TLS_DEVICE (or TLS_DEVICE=n), all
# satisfied by the default x86 config; selects NET_DEVLINK (bool -> y), CRC32
# (=y in target/linux/generic/config-6.12) and DIMLIB (=y)
# ---------------------------------------------------------------------------
define KernelPackage/nfp
  SUBMENU:=$(NETWORK_DEVICES_MENU)
  TITLE:=Netronome NFP4000/NFP6000 NIC support
  DEPENDS:=@PCI_SUPPORT
  KCONFIG:=CONFIG_NFP
  FILES:=$(LINUX_DIR)/drivers/net/ethernet/netronome/nfp/nfp.ko
  AUTOLOAD:=$(call AutoLoad,35,nfp)
endef

define KernelPackage/nfp/description
 Kernel module for Netronome NFP4000/NFP6000 based SmartNICs.
endef

$(eval $(call KernelPackage,nfp))

# ---------------------------------------------------------------------------
# Google Virtual NIC (gve) - Google Compute Engine
# depends on PCI_MSI && (X86 || CPU_LITTLE_ENDIAN)
# ---------------------------------------------------------------------------
define KernelPackage/gve
  SUBMENU:=$(NETWORK_DEVICES_MENU)
  TITLE:=Google Virtual NIC (gVNIC) support
  DEPENDS:=@PCI_SUPPORT
  KCONFIG:=CONFIG_GVE
  FILES:=$(LINUX_DIR)/drivers/net/ethernet/google/gve/gve.ko
  AUTOLOAD:=$(call AutoLoad,35,gve)
endef

define KernelPackage/gve/description
 Kernel module for the Google Virtual NIC (gVNIC) used by Google Compute
 Engine instances.
endef

$(eval $(call KernelPackage,gve))

# ---------------------------------------------------------------------------
# Microsoft Azure Network Adapter (mana)
# depends on PCI_MSI && X86_64 && PCI_HYPERV (all =y on x86/64), selects
# AUXILIARY_BUS (bool) and PAGE_POOL (=y)
# ---------------------------------------------------------------------------
define KernelPackage/mana
  SUBMENU:=$(NETWORK_DEVICES_MENU)
  TITLE:=Microsoft Azure Network Adapter (MANA) support
  DEPENDS:=@TARGET_x86_64
  KCONFIG:=CONFIG_MICROSOFT_MANA
  FILES:=$(LINUX_DIR)/drivers/net/ethernet/microsoft/mana/mana.ko
  AUTOLOAD:=$(call AutoLoad,35,mana)
endef

define KernelPackage/mana/description
 Kernel module for the Microsoft Azure Network Adapter (MANA), the
 accelerator NIC of newer Azure VM sizes.
endef

$(eval $(call KernelPackage,mana))

