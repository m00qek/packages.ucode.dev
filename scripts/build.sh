#!/bin/sh
# Build feed packages in an OpenWrt SDK container.
#
# Usage:
#   build.sh RELEASE IMAGE BUILD OUT PACKAGE...
#       Build the feed's PACKAGE directories with the SDK image IMAGE, e.g.
#       openwrt/sdk:mips_4kec-24.10.6, for RELEASE, e.g. 24.10, and copy
#       the package files each produced to OUT/<PACKAGE>/.
#
#       BUILD is `noarch` for packages that compile nothing (feed.json's
#       "build": "noarch"): their dependencies are not built (NO_DEPS), and
#       the package manager still records them. Any other BUILD is the
#       package architecture IMAGE builds for, e.g. mips_4kec, and the
#       packages' dependencies are built too, as C code links against them.
#
#       Every feed is switched from the release tag the image pins to the
#       release's branch, openwrt-RELEASE. Routers on any point release of
#       a series install from OpenWrt's one feed for the branch, and a
#       library named after its ABI, like libwolfssl5.9.1.e624513f, is
#       renamed there when the branch updates it: a package linked against
#       the tag's library could no longer be installed. luci-sso-deps.yml
#       checks the published packages against those feeds daily.
#
#       A package's release is its Makefile's PKG_RELEASE, or the number in
#       PACKAGE/feed-release if there is one. feed-release lets the feed
#       rebuild a version, e.g. against a renamed library, without editing a
#       Makefile generated upstream; only the build's copy is changed.
#
#       A build that produces none, or not all, of a package's packages,
#       as tmp/.packageinfo lists them, or a file of another release, fails.
#
# POSIX sh on the runner, plus docker.

set -eu
export LC_ALL=C

fail() {
	echo "::error::build.sh: $*" >&2
	exit 1
}

[ $# -ge 5 ] || { sed -n '/^# Usage:/,/^# POSIX/p' "$0" | sed '$d; s/^# \{0,1\}//' >&2; exit 2; }
release=$1 image=$2 build=$3 out=$4
shift 4

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
# The SDK runs as its own user (buildbot, uid 1000), which the runner's user
# need not be. The build makes what it writes removable before it ends; if it
# failed first, what remains is left behind rather than failing the cleanup,
# and the build's own exit status is kept.
trap 'rm -rf "$work" 2>/dev/null || true' EXIT INT TERM
mkdir -p "$work/pkg" "$work/bin" "$work/out" "$out"
out=$(cd "$out" && pwd)

mounts=
targets=
for p in "$@"; do
	src=$root/$p
	[ -f "$src/Makefile" ] || fail "$p: no $p/Makefile"
	pkg_release=$(sed -n 's/^PKG_RELEASE:=//p' "$src/Makefile")
	[ -n "$pkg_release" ] || fail "$p/Makefile has no PKG_RELEASE"
	cp -R "$src" "$work/pkg/$p"
	r=$pkg_release
	if [ -f "$src/feed-release" ]; then
		r=$(cat "$src/feed-release")
		case "$r" in
			'' | 0* | *[!0-9]*) fail "$p/feed-release: '$r' is not a release number: 1, 2, ..." ;;
		esac
		[ "$r" -ge "$pkg_release" ] ||
			fail "$p/feed-release: $r is lower than PKG_RELEASE:=$pkg_release in $p/Makefile, which it would hide"
		sed -i "s/^PKG_RELEASE:=.*/PKG_RELEASE:=$r/" "$work/pkg/$p/Makefile"
	fi
	echo "$p $r" >> "$work/releases"
	echo "$p: release r$r"
	mounts="$mounts -v $work/pkg/$p:/builder/package/$p:ro"
	targets="$targets package/$p/compile"
done

if [ "$build" = noarch ]; then
	flags=NO_DEPS=1
else
	flags='-j$(nproc)'
fi

chmod 777 "$work/bin" "$work/out"
# shellcheck disable=SC2086  # $mounts: -v options, paths without spaces
docker run --rm $mounts \
	-v "$work/bin":/builder/bin -v "$work/out":/out -v "$work/releases":/releases:ro \
	"$image" sh -c '
		set -e
		sed -i -E "/^src-git/s/[;^][^;^]*\$/;openwrt-'"$release"'/" feeds.conf.default
		cat feeds.conf.default
		./scripts/feeds update -a
		./scripts/feeds install -a
		make defconfig
		make '"$targets"' '"$flags"' CHECK_KEY=0 V=s

		# Each package directory produces the packages tmp/.packageinfo lists
		# under its Makefile: one file each, <name>_<version>_<arch>.ipk or
		# <name>-<version>.apk. A version starts with a digit, so a name is
		# never mistaken for a longer one that starts with it.
		while read -r p r; do
			mkdir -p "/out/$p"
			names=$(awk -v m="package/$p/Makefile" "
				/^Source-Makefile: /{ on = (\$2 == m); next }
				on && /^Package: /{ print \$2 }" tmp/.packageinfo)
			[ -n "$names" ] || { echo "$p: tmp/.packageinfo lists no package" >&2; exit 1; }
			for n in $names; do
				files=$(find /builder/bin -type f \( -name "${n}_[0-9]*.ipk" -o -name "${n}-[0-9]*.apk" \))
				count=$(printf "%s" "$files" | grep -c . || true)
				[ "$count" -eq 1 ] || { echo "$p: expected one file for $n, found $count: $files" >&2; exit 1; }
				cp "$files" "/out/$p/"
			done
		done < /releases
		chmod -R a+rwX /out /builder/bin
	'

# Every file must carry the release the build was asked for:
# <name>_<version>-r<N>_<arch>.ipk or <name>-<version>-r<N>.apk.
while read -r p r; do
	for f in "$work/out/$p"/*; do
		case "$(basename "$f")" in
			*-r"$r"_*.ipk | *-r"$r".apk) ;;
			*) fail "$p: $(basename "$f") is not release r$r" ;;
		esac
	done
	echo "$p:"
	ls -1 "$work/out/$p" | sed 's/^/  /'
done < "$work/releases"
cp -R "$work/out"/. "$out/"
