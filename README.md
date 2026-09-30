# packages.ucode.dev

Custom OpenWrt feed with developer tools for [ucode](https://github.com/jow-/ucode),
[luci-sso](https://github.com/m00qek/luci-sso) and [wgpathd](https://github.com/m00qek/wgpathd).

## Packages

| Package | Description | OpenWrt 24.10 (opkg) | OpenWrt 25.12 (apk) | Version (current) |
|---------|-------------|----------------------|---------------------|-------------------|
| [ucode-docopt](https://github.com/m00qek/docopt.uc) | A complete, specification-compliant implementation of docopt for the ucode programming language. | `all` | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | 1.0.2-r1 |
| [ucode-utest](https://github.com/m00qek/utest) | A modern, non-invasive testing framework for the ucode ecosystem. Provides a describe/it DSL, built-in mock proxies for uci, ubus, fs, uloop, and uclient, and both sequential and parallel test runners. | `all` | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | 1.5.1-r1 |
| [luci-sso](https://github.com/m00qek/luci-sso) | A lightweight OIDC/OAuth2 Single Sign-On provider for LuCI with minimal dependencies. | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | 0.10.0-r1 |
| luci-sso-crypto-mbedtls | MbedTLS backend for luci-sso | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | 0.10.0-r1 |
| luci-sso-crypto-openssl | OpenSSL backend for luci-sso | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | 0.10.0-r1 |
| luci-sso-crypto-wolfssl | WolfSSL backend for luci-sso | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | 0.10.0-r1 |
| [wgpathd](https://github.com/m00qek/wgpathd) | Direct-or-relay path selection for WireGuard hub-and-spoke. | — | `noarch` | 0.1.0-r8 |
| luci-app-wgpathd | LuCI pages for wgpathd. | — | `noarch` | 0.1.0-r8 |

`all` means any architecture. To see your router's architecture, run
`opkg print-architecture` on OpenWrt 24.10 or `apk --print-arch` on OpenWrt 25.12.

## Installation

All packages are signed. Before installing, you need to add the feed's public key
so your package manager can verify the packages it downloads.

### OpenWrt 25.12.x (apk)

```sh
# Trust the feed's signing key
wget -O /etc/apk/keys/packages.ucode.dev.pem \
  https://m00qek.github.io/packages.ucode.dev/25.12/feed.pub.pem

# Add the feed
echo "https://m00qek.github.io/packages.ucode.dev/25.12" \
  >> /etc/apk/repositories.d/customfeeds.list

apk update
apk add ucode-docopt ucode-utest
apk add luci-sso luci-sso-crypto-mbedtls
apk add wgpathd luci-app-wgpathd
```

apk reads the index at `25.12/<arch>/APKINDEX.tar.gz`, where `<arch>` is what
`apk --print-arch` prints.

### OpenWrt 24.10.x (opkg)

```sh
# Trust the feed's signing key
wget -O /etc/opkg/keys/a2288d4745630a38 \
  https://m00qek.github.io/packages.ucode.dev/24.10/feed.pub

# Add the feed
echo "src/gz ucode.dev https://m00qek.github.io/packages.ucode.dev/24.10" \
  >> /etc/opkg/customfeeds.conf

opkg update
opkg install ucode-docopt ucode-utest
opkg install luci-sso luci-sso-crypto-mbedtls
```

opkg reads the index at the feed root, `24.10/Packages.gz`, which lists every
package for every architecture; opkg picks the ones that match your router.

## luci-sso

luci-sso needs one crypto backend: `luci-sso-crypto-mbedtls`,
`luci-sso-crypto-openssl` or `luci-sso-crypto-wolfssl`. For configuration,
upgrades and choosing a backend, see the
[luci-sso documentation](https://m00qek.github.io/luci-sso/latest/).

### Updating `luci-sso/Makefile`

`luci-sso/Makefile` is generated from luci-sso's own package Makefile; do not
edit it here. After tagging a luci-sso release, regenerate it from the luci-sso
checkout and commit the result:

```sh
make feed-makefile VERSION=<version> OUT=<this repo>/luci-sso/Makefile
```

The `luci-sso` workflow regenerates it from the tag its `PKG_VERSION` names and
fails, before building or publishing anything, if the committed file differs.

## wgpathd

wgpathd and luci-app-wgpathd are published for OpenWrt 25.12 only, the release
they are tested on. For setting them up, see the
[wgpathd documentation](https://m00qek.github.io/wgpathd/latest/).

### Updating `wgpathd/Makefile`

`wgpathd/Makefile` is generated from wgpathd's own package Makefile, the same
way as luci-sso's; do not edit it here. After tagging a wgpathd release,
regenerate it from the wgpathd checkout and commit the result:

```sh
make feed-makefile VERSION=<version> OUT=<this repo>/wgpathd/Makefile
```

The `wgpathd` workflow regenerates it from the tag its `PKG_VERSION` names and
fails, before building or publishing anything, if the committed file differs.

## Using as a build feed

Add to `feeds.conf` in your OpenWrt buildroot:

```
src-git ucode.dev https://github.com/m00qek/packages.ucode.dev.git
```

Then:

```sh
./scripts/feeds update ucode.dev
./scripts/feeds install ucode-docopt ucode-utest luci-sso
```

## Feed structure

Packages are built with the OpenWrt 24.10.x and 25.12.x SDKs and published to
GitHub Pages. `ucode-docopt` and `ucode-utest` are architecture-independent and are
built once, with the `x86-64` SDK; so are `wgpathd` and `luci-app-wgpathd`, with
the 25.12 SDK only. luci-sso contains a C extension, so it and its
crypto backends are built separately for `x86_64`, `aarch64_generic` and
`aarch64_cortex-a53`.

| Path | Contents |
|------|----------|
| `24.10/` | `ucode-docopt` and `ucode-utest` packages, and the root index that lists every package for every architecture |
| `24.10/<arch>/` | luci-sso packages for that architecture, with an index of their own |
| `25.12/<arch>/` | luci-sso packages for that architecture, and the index apk reads for it, which also lists the packages of `25.12/noarch/`; `x86_64/` also holds older copies of `ucode-docopt` and `ucode-utest` |
| `25.12/noarch/` | `ucode-docopt`, `ucode-utest`, `wgpathd` and `luci-app-wgpathd` packages; every `25.12/<arch>/` index lists them, and apk downloads them from here |

Like OpenWrt's own feeds, each index lists only the newest version of each
package, so `opkg install` and `apk add` always get the latest release. Older
package files stay published next to it: to roll back, download the version you need
from the feed directory and install that file directly, e.g.

```sh
opkg install https://m00qek.github.io/packages.ucode.dev/24.10/ucode-utest_1.5.0-r1_all.ipk
```
