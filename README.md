# packages.ucode.dev

Custom OpenWrt feed with developer tools for [ucode](https://github.com/jow-/ucode),
and [luci-sso](https://github.com/m00qek/luci-sso).

## Packages

| Package | Description | OpenWrt 24.10 (opkg) | OpenWrt 25.12 (apk) | Version (current) |
|---------|-------------|----------------------|---------------------|-------------------|
| [ucode-docopt](https://github.com/m00qek/docopt.uc) | A complete, specification-compliant implementation of docopt for the ucode programming language. | `all` | `x86_64` only (see below) | 1.0.2-r1 |
| [ucode-utest](https://github.com/m00qek/utest) | A modern, non-invasive testing framework for the ucode ecosystem. Provides a describe/it DSL, built-in mock proxies for uci, ubus, fs, uloop, and uclient, and both sequential and parallel test runners. | `all` | `x86_64` only (see below) | 1.5.1-r1 |
| [luci-sso](https://github.com/m00qek/luci-sso) | A lightweight OIDC/OAuth2 Single Sign-On provider for LuCI with minimal dependencies. | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | 0.10.0-r1 |
| luci-sso-crypto-mbedtls | MbedTLS backend for luci-sso | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | 0.10.0-r1 |
| luci-sso-crypto-openssl | OpenSSL backend for luci-sso | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | 0.10.0-r1 |
| luci-sso-crypto-wolfssl | WolfSSL backend for luci-sso | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | `x86_64`, `aarch64_generic`, `aarch64_cortex-a53` | 0.10.0-r1 |

`all` means any architecture. To see your router's architecture, run
`opkg print-architecture` on OpenWrt 24.10 or `apk --print-arch` on OpenWrt 25.12.

On OpenWrt 25.12, `ucode-docopt` and `ucode-utest` are architecture-independent
(`noarch`), but only the `x86_64` index lists them. `apk add` finds them on an
`x86_64` router only; on `aarch64_generic` or `aarch64_cortex-a53` it does not.

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
apk add ucode-docopt ucode-utest                 # x86_64 only, see above
apk add luci-sso luci-sso-crypto-mbedtls
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
built once, with the `x86-64` SDK. luci-sso contains a C extension, so it and its
crypto backends are built separately for `x86_64`, `aarch64_generic` and
`aarch64_cortex-a53`.

| Path | Contents |
|------|----------|
| `24.10/` | `ucode-docopt` and `ucode-utest` packages, and the root index that lists every package for every architecture |
| `24.10/<arch>/` | luci-sso packages for that architecture, with an index of their own |
| `25.12/<arch>/` | the index apk reads for that architecture, with its packages; `x86_64/` also holds `ucode-docopt` and `ucode-utest` |
| `25.12/noarch/` | copies of the `ucode-docopt` and `ucode-utest` packages; no index lists them |

Like OpenWrt's own feeds, each index lists only the newest version of each
package, so `opkg install` and `apk add` always get the latest release. Older
package files stay published next to it: to roll back, download the version you need
from the feed directory and install that file directly, e.g.

```sh
opkg install https://m00qek.github.io/packages.ucode.dev/24.10/ucode-utest_1.5.0-r1_all.ipk
```
