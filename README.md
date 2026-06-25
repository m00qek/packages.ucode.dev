# packages.ucode.dev

Custom OpenWrt feed with developer tools for [ucode](https://github.com/jow-/ucode).

## Packages

| Package | Description |
|---------|-------------|
| [ucode-docopt](https://github.com/m00qek/docopt.uc) | Specification-compliant docopt implementation for ucode |
| [ucode-utest](https://github.com/m00qek/utest) | Unit testing framework for ucode |

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
```

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

## Feed structure

Packages are built for `x86-64` against OpenWrt 24.10.x and 25.12.x and published to
GitHub Pages. All versions accumulate — installing an older version is possible by
pinning the version in `opkg install` or `apk add`.
