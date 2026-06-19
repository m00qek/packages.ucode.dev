include $(TOPDIR)/rules.mk

PKG_NAME:=ucode-docopt
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/m00qek/docopt.uc.git
PKG_SOURCE_VERSION:=a27433246a6ae728e1510c5ea7ebbd611f127b40
PKG_MIRROR_HASH:=skip

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
