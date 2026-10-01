# packages.ucode.dev

Custom OpenWrt feed with developer tools for [ucode](https://github.com/jow-/ucode),
[luci-sso](https://github.com/m00qek/luci-sso), [wgpathd](https://github.com/m00qek/wgpathd)
and [owrtfetch](https://github.com/m00qek/owrtfetch).

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
| [owrtfetch](https://github.com/m00qek/owrtfetch) | A neofetch-like summary for OpenWrt routers, written in ucode. | — | `noarch` | 0.1.0-r1 |

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
apk add owrtfetch
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
checkout, set `luci-sso/feed-release` back to `1`, and commit both together:

```sh
make feed-makefile VERSION=<version> OUT=<this repo>/luci-sso/Makefile
echo 1 > <this repo>/luci-sso/feed-release
```

The `luci-sso` workflow regenerates the Makefile from the tag its `PKG_VERSION`
names and fails, before building or publishing anything, if the committed file
differs. It also fails if `luci-sso/feed-release` is lower than the Makefile's
`PKG_RELEASE`; use that number instead of `1` if the Makefile's is higher.

### The feed release

The `-rN` in `0.10.0-r2` is the package release. The feed builds luci-sso with
the one in `luci-sso/feed-release`, passed to the SDK as `PKG_RELEASE`, so the
generated Makefile stays as generated. It is how the feed rebuilds a luci-sso
version that OpenWrt has broken:

OpenWrt names some libraries after their ABI, e.g. `libwolfssl5.9.1.e624513f`.
Every OpenWrt 24.10.x router installs from one OpenWrt feed for the whole
`openwrt-24.10` branch, and 25.12.x routers from one for `openwrt-25.12`. When
the branch updates such a library, that feed serves it under the new name
only, and a `luci-sso-crypto-wolfssl` built against the old name can no longer
be installed. So:

- The `luci-sso` workflow builds against OpenWrt's branches, `openwrt-24.10` and
  `openwrt-25.12`, not the release tag the SDK image pins, so the packages
  depend on the libraries routers are offered.
- Raising `luci-sso/feed-release` rebuilds the current luci-sso version. Of
  that rebuild, the workflow publishes only the packages whose dependencies
  differ from the newest published release of that version: a renamed
  `libwolfssl` republishes `luci-sso-crypto-wolfssl` alone, and only for the
  series and architectures it was renamed in. Routers with it installed see an
  upgrade; routers with another backend see nothing. So the releases of the
  luci-sso packages may differ, e.g. `luci-sso` 0.10.0-r1 with
  `luci-sso-crypto-wolfssl` 0.10.0-r2.

`luci-sso/feed-release` is raised by the `luci-sso dependencies` workflow,
described next, or by hand.

### The daily dependency check

The `luci-sso dependencies` workflow (`.github/workflows/luci-sso-deps.yml`)
runs every day, and on demand from the Actions tab. For each OpenWrt series
and architecture the feed publishes, it takes the luci-sso packages the feed's
index lists and compares each dependency on an ABI-named library, such as
`libwolfssl5.9.1.e624513f`, `libucode20230711` or `libmbedtls21`, with OpenWrt's
live base feed for that branch
(`https://downloads.openwrt.org/releases/packages-<series>/<arch>/base/`):

- **In sync**: nothing to do.
- **Mismatch**: the live feed serves another version of the library. The
  workflow raises `luci-sso/feed-release` by one, commits that to `main` with
  a `Rebuild-For: <series> <arch> <package> <live library>` line per mismatch,
  and starts the `luci-sso` workflow, which rebuilds and publishes the
  packages whose dependencies changed.
- **Waiting**: a package depends on a newer library than the live feed serves
  yet: it was built from the branch before OpenWrt's buildbots published that
  library. A rebuild cannot help; the workflow warns and waits.

It never raises the release twice for the same mismatch. If a mismatch that the
last change of `luci-sso/feed-release` named in a `Rebuild-For:` line is still
there, the rebuild did not fix it, or failed, and the workflow fails, listing
the `luci-sso` runs of that commit, instead of raising the release again. Find
out why, then commit a fix or a raise of your own; a commit to
`luci-sso/feed-release` without `Rebuild-For:` lines re-arms it. When raising
it by hand to fix a reported mismatch, copy those lines into the commit
message, so the check stops there too if the rebuild does not fix it. The
workflow skips a day while a `luci-sso` run is in progress.

To run the check by hand against a checkout of `gh-pages`:

```sh
docker run --rm -v <gh-pages checkout>:/feed:ro \
  -v "$PWD/scripts/luci-sso-deps.sh":/luci-sso-deps.sh:ro \
  openwrt/sdk:x86-64-25.12.3 sh /luci-sso-deps.sh check /feed
```

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

## owrtfetch

owrtfetch is published for OpenWrt 25.12 only, the release it supports. See its
[README](https://github.com/m00qek/owrtfetch#readme) for what it shows and how.

### Updating `owrtfetch/Makefile`

`owrtfetch/Makefile` is generated from owrtfetch's own package Makefile, the
same way as wgpathd's; do not edit it here. After tagging an owrtfetch release,
regenerate it from the owrtfetch checkout and commit the result:

```sh
make feed-makefile VERSION=<version> OUT=<this repo>/owrtfetch/Makefile
```

The `owrtfetch` workflow regenerates it from the tag its `PKG_VERSION` names and
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
