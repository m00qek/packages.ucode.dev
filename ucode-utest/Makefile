include $(TOPDIR)/rules.mk

PKG_NAME:=ucode-utest
PKG_VERSION:=1.2.0
PKG_RELEASE:=1

PKG_SOURCE_VERSION:=830ca8c7c0031ed14c16150a839e652e04785049
PKG_SOURCE:=$(PKG_SOURCE_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/m00qek/utest/archive/
PKG_HASH:=d5558cd419c8d46bdc958064cb97f963d1ea793866414c025906ec15033512ed
PKG_BUILD_DIR:=$(BUILD_DIR)/utest-$(PKG_SOURCE_VERSION)

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
