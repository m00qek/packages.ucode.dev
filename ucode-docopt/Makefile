include $(TOPDIR)/rules.mk

PKG_NAME:=ucode-docopt
PKG_VERSION:=1.0.2
PKG_RELEASE:=1

PKG_SOURCE:=v$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/m00qek/docopt.uc/archive/refs/tags/
PKG_HASH:=715644f4d7f73c7aa3fcb8e42f666fc350c4f0afc95cc1c25f2e8e41cf48fd88
PKG_BUILD_DIR:=$(BUILD_DIR)/docopt.uc-$(PKG_VERSION)

PKG_MAINTAINER:=m00qek <m00qek@gmail.com>
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/ucode-docopt
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=docopt for ucode
  DEPENDS:=+ucode
  PKGARCH:=all
endef

define Package/ucode-docopt/description
  A complete, specification-compliant implementation of docopt for the ucode programming language.
endef

define Build/Compile
endef

define Package/ucode-docopt/install
	$(INSTALL_DIR) $(1)/usr/share/ucode/docopt
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/docopt.uc $(1)/usr/share/ucode/docopt.uc
	$(CP) $(PKG_BUILD_DIR)/src/docopt/*.uc $(1)/usr/share/ucode/docopt/
endef

$(eval $(call BuildPackage,ucode-docopt))
