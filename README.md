# packages.ucode.dev

Custom OpenWrt feed with developer tools for [ucode](https://github.com/jow-/ucode).

## Packages

| Package | Description |
|---------|-------------|
| [ucode-docopt](https://github.com/m00qek/docopt.uc) | Specification-compliant docopt implementation for ucode |
| [ucode-utest](https://github.com/m00qek/utest) | Unit testing framework for ucode |

## Installation

### OpenWrt 24.10.x (opkg)

Add the feed to `/etc/opkg/customfeeds.conf`:

```
src/gz ucode.dev https://github.com/m00qek/packages.ucode.dev/releases/latest/download
```

Then install packages:

```sh
opkg update
opkg install ucode-docopt
opkg install ucode-utest
```

### OpenWrt 25.12.x (apk)

```sh
apk add --repository https://github.com/m00qek/packages.ucode.dev/releases/latest/download \
  ucode-docopt ucode-utest
```

## Using as a build feed

Add to `feeds.conf` in your OpenWrt buildroot:

```
src-git ucode.dev https://github.com/m00qek/packages.ucode.dev.git
```

Then:

```sh
./scripts/feeds update ucode.dev
./scripts/feeds install ucode-docopt ucode-utest
```

## Releases

Packages are built for `x86-64` against OpenWrt 24.10.x and 25.12.x. Each release includes:

- `.ipk` packages + `Packages.gz` index (for opkg / 24.10.x)
- `.apk` packages + `APKINDEX.tar.gz` index (for apk / 25.12.x)

To update a package version in this feed, bump `PKG_VERSION` and `PKG_HASH` in the relevant `Makefile`, then push a tag.
