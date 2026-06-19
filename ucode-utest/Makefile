include $(TOPDIR)/rules.mk

PKG_NAME:=ucode-utest
PKG_VERSION:=1.2.1
PKG_RELEASE:=1

PKG_SOURCE:=v$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/m00qek/utest/archive/refs/tags/
PKG_HASH:=caa4e6ef581e47d3357ea9806d107422bdf4b23cdc83745a7a173e40cf70a67a
PKG_BUILD_DIR:=$(BUILD_DIR)/utest-$(PKG_VERSION)

PKG_MAINTAINER:=António Mora <oliveira.fh42@gmail.com>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/ucode-utest
  SECTION:=devel
  CATEGORY:=Development
  TITLE:=Unit testing framework for ucode
  URL:=https://github.com/m00qek/utest
  DEPENDS:=+ucode
  PKGARCH:=all
endef

define Package/ucode-utest/description
  A modern, non-invasive testing framework for the ucode ecosystem.
  Provides a describe/it DSL, built-in mock proxies for uci, ubus, fs,
  uloop, and uclient, and both sequential and parallel test runners.
endef

define Build/Compile
endef

define Package/ucode-utest/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/utest.sh $(1)/usr/bin/utest

	$(INSTALL_DIR) $(1)/usr/share/ucode
	$(CP) $(PKG_BUILD_DIR)/src/utest.uc $(1)/usr/share/ucode/
	$(CP) -r $(PKG_BUILD_DIR)/src/utest $(1)/usr/share/ucode/
endef

$(eval $(call BuildPackage,ucode-utest))
