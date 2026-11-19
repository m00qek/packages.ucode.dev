#!/bin/sh
# File built packages into the feed and regenerate its indexes.
#
# Every workflow that publishes to gh-pages runs this, so the feed layout,
# the signing and the index rules exist once. The layout of a feed checkout:
#
#   <release>/                  opkg (24.10): packages with arch `all`, and the
#                               feed root index, combined over the arch dirs
#   <release>/<arch>/           opkg: packages for <arch>, and their index
#   <release>/noarch/           apk (25.12): noarch packages; every arch index
#                               lists them, apk downloads them from here
#   <release>/<arch>/           apk: packages for <arch>, and APKINDEX.tar.gz
#
# A release is opkg or apk by the packages it holds: .ipk or .apk.
#
# Usage:
#   publish.sh file [--deps-gate] [--ref ARCH] STAGING FEED
#       File the packages under STAGING/<release>/<build>/ into the feed
#       checkout FEED. <build> is the package architecture a build job built
#       for, e.g. x86_64 or mips_4kec, or `noarch` for a build of packages
#       that are all architecture-independent. Each apk is signed first.
#
#       A file already in the feed is never replaced, so published versions
#       stay downloadable as they were.
#
#       A build for an architecture also produces the architecture-independent
#       packages of the same source (luci-sso next to its crypto backends).
#       Two builds of one version are not byte-identical, so those are taken
#       from the build for --ref (default x86_64) only, and every other build
#       of the release must have produced the same file names.
#
#       --deps-gate: a package of the same name, version and arch as one
#       already published, but a higher release, is filed only if its
#       dependencies differ from the newest published one. luci-sso uses
#       this: its feed-release rebuilds follow OpenWrt renaming a library,
#       and only the packages that depend on it should reach routers.
#
#   publish.sh index [--manifest FEED_JSON] [--pubkeys DIR] FEED
#       Regenerate and sign every index in FEED, so whichever workflow
#       publishes last, no index loses another's packages. Each index lists
#       only the newest version of a package (newest-only-index.sh).
#
#       With --manifest, an apk release also gets an index for each arch in
#       its "index-arches" in FEED_JSON (feed.json), whether or not any
#       package is built for it: apk reads <release>/<arch>/APKINDEX.tar.gz
#       only, so the noarch packages reach a router only through an index
#       for its arch. With --pubkeys, DIR/opkg.pub and DIR/apk.pub are copied
#       in as <release>/feed.pub and <release>/feed.pub.pem.
#
# Environment:
#   APK_FEED_SIGNING_KEY    apk private key (PEM); unset: apks stay unsigned
#   OPKG_FEED_SIGNING_KEY   usign private key; unset: Packages stays unsigned
#   OPKG_IMAGE              SDK image with opkg's index tools
#                           (default: openwrt/sdk:x86-64-24.10.6)
#   APK_IMAGE               SDK image with apk-tools 3
#                           (default: openwrt/sdk:x86-64-25.12.3)
#
# POSIX sh on the runner, plus docker, and jq for --manifest: the feed tools
# come from the SDK images.

set -eu
export LC_ALL=C

HERE=$(cd "$(dirname "$0")" && pwd)
OPKG_IMAGE=${OPKG_IMAGE:-openwrt/sdk:x86-64-24.10.6}
APK_IMAGE=${APK_IMAGE:-openwrt/sdk:x86-64-25.12.3}
HOSTBIN=/builder/staging_dir/host/bin

fail() {
	echo "::error::publish.sh: $*" >&2
	exit 1
}
usage() {
	sed -n '/^# Usage:/,/^# Environment:/p' "$0" | sed '$d; s/^# \{0,1\}//' >&2
	exit 2
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT INT TERM

# The keys go to a directory every container mounts read-only at /keys.
mkdir -p "$WORK/keys"
if [ -n "${APK_FEED_SIGNING_KEY:-}" ]; then
	printf '%s' "$APK_FEED_SIGNING_KEY" > "$WORK/keys/apk.key"
fi
if [ -n "${OPKG_FEED_SIGNING_KEY:-}" ]; then
	printf '%s' "$OPKG_FEED_SIGNING_KEY" > "$WORK/keys/opkg.key"
fi

# sdk IMAGE [docker run options...] -- COMMAND...: run COMMAND as the runner's
# user, with this directory at /scripts and the keys at /keys.
sdk() {
	image=$1
	shift
	opts=
	while [ "$1" != -- ]; do
		opts="$opts $1"
		shift
	done
	shift
	# shellcheck disable=SC2086  # $opts is a list of mount options without spaces
	docker run --rm --user "$(id -u):$(id -g)" \
		-v "$HERE":/scripts:ro -v "$WORK/keys":/keys:ro \
		$opts "$image" "$@"
}

# format DIR: opkg, apk, or nothing, by the packages under DIR.
format() {
	ipk=$(find "$1" -name '*.ipk' | head -n 1)
	apk=$(find "$1" -name '*.apk' | head -n 1)
	if [ -n "$ipk" ] && [ -n "$apk" ]; then
		fail "$1 holds both .ipk and .apk packages"
	fi
	if [ -n "$ipk" ]; then echo opkg; elif [ -n "$apk" ]; then echo apk; fi
}

# ---------------------------------------------------------------------- file

# deps_of PACKAGE: its dependencies, one per line. An apk's were read when it
# was signed, into PACKAGE.deps, and a published one's into deps/.
deps_of() {
	case "$1" in
		*.ipk) sh "$HERE/luci-sso-deps.sh" depends "$1" ;;
		"$WORK"/new/*) cat "$1.deps" ;;
		*) cat "$WORK/deps/$(basename "$(dirname "$(dirname "$1")")")/$(basename "$(dirname "$1")")/$(basename "$1").deps" ;;
	esac
}

# newest_same PACKAGE DIR: the published package in DIR with the same name,
# version and arch as PACKAGE, and the highest release.
#   <name>_<version>-r<N>_<arch>.ipk   <name>-<version>-r<N>.apk
newest_same() {
	base=$(basename "$1")
	case "$base" in
		*.ipk) glob=$(printf '%s' "$base" | sed -E 's/-r[0-9]+_/-r*_/') ;;
		*.apk) glob=$(printf '%s' "$base" | sed -E 's/-r[0-9]+\.apk$/-r*.apk/') ;;
	esac
	for f in "$2"/$glob; do
		[ -f "$f" ] || continue
		printf '%s %s\n' "$(basename "$f" | sed -E 's/.*-r([0-9]+)(_.*\.ipk|\.apk)$/\1/')" "$f"
	done | sort -n | tail -n 1 | cut -d' ' -f2-
}

# put PACKAGE DIR: file PACKAGE into DIR, see --deps-gate.
put() {
	base=$(basename "$1")
	if [ -e "$2/$base" ]; then
		echo "kept   $2/$base (already published)"
		return
	fi
	if [ "$DEPS_GATE" = 1 ]; then
		prev=$(newest_same "$1" "$2")
		if [ -n "$prev" ]; then
			new_deps=$(deps_of "$1")
			prev_deps=$(deps_of "$prev")
			[ -n "$new_deps" ] && [ -n "$prev_deps" ] ||
				fail "could not read the dependencies of $1 or $prev"
			if [ "$new_deps" = "$prev_deps" ]; then
				echo "same   $2/$base (dependencies of $(basename "$prev"), not filed)"
				return
			fi
		fi
	fi
	mkdir -p "$2"
	cp "$1" "$2/"
	echo "filed  $2/$base"
}

# arch_of PACKAGE: the architecture it is built for; all and noarch alike
# come out as `any`. Read from the package, not its file name: both names and
# architectures contain '_' (ucode-prometheus-exporter-dhcp_leases,
# aarch64_generic). An ipk is a gzipped tar holding control.tar.gz.
arch_of() {
	case "$1" in
		*.ipk) a=$(tar -xzOf "$1" ./control.tar.gz | tar -xzOf - ./control |
			sed -n 's/^Architecture: *//p') ;;
		*.apk) a=$(cat "$1.arch") ;;
	esac
	[ -n "$a" ] || fail "no architecture in $1"
	case "$a" in all | noarch) echo any ;; *) echo "$a" ;; esac
}

# any_of BUILD_DIR: the names of the architecture-independent packages in it.
any_of() {
	for p in "$1"/*.ipk "$1"/*.apk; do
		[ -f "$p" ] || continue
		if [ "$(arch_of "$p")" = any ]; then basename "$p"; fi
	done
}

# sign_apks RELEASE FEED: sign the release's staged apks and record each
# one's arch and dependencies next to it, and, for --deps-gate, those of the
# published ones under deps/. Reading an apk takes apk-tools, from the SDK.
sign_apks() {
	mkdir -p "$2/$1" "$WORK/deps/$1"
	chmod -R 777 "$WORK/new/$1"
	sdk "$APK_IMAGE" \
		-v "$WORK/new/$1":/new -v "$(cd "$2/$1" && pwd)":/feed:ro -v "$WORK/deps/$1":/deps \
		-e DEPS_GATE="$DEPS_GATE" -- sh -c '
			set -e
			for pkg in /new/*/*.apk; do
				if [ -f /keys/apk.key ]; then
					'"$HOSTBIN"'/apk adbsign --allow-untrusted --reset-signatures \
						--sign-key /keys/apk.key "$pkg"
				fi
				arch=$('"$HOSTBIN"'/apk adbdump "$pkg" 2>/dev/null | awk "/^ *arch:/{print \$2}")
				[ -n "$arch" ] || { echo "no arch in $pkg" >&2; exit 1; }
				echo "$arch" > "$pkg.arch"
				if [ "$DEPS_GATE" = 1 ]; then
					sh /scripts/luci-sso-deps.sh depends "$pkg" > "$pkg.deps"
				fi
			done
			[ "$DEPS_GATE" = 1 ] || exit 0
			for pkg in /feed/*/*.apk; do
				[ -f "$pkg" ] || continue
				dir=/deps/$(basename "$(dirname "$pkg")")
				mkdir -p "$dir"
				sh /scripts/luci-sso-deps.sh depends "$pkg" > "$dir/$(basename "$pkg").deps"
			done
		'
}

cmd_file() {
	DEPS_GATE=0
	REF=x86_64
	while [ $# -gt 0 ]; do
		case "$1" in
			--deps-gate) DEPS_GATE=1 ;;
			--ref) REF=$2; shift ;;
			-*) usage ;;
			*) break ;;
		esac
		shift
	done
	[ $# -eq 2 ] || usage
	[ -d "$1" ] || fail "no staging directory $1"
	[ -d "$2" ] || fail "no feed directory $2"
	feed=$2

	mkdir -p "$WORK/new"
	cp -R "$1"/. "$WORK/new/"

	for rdir in "$WORK"/new/*/; do
		[ -d "$rdir" ] || continue
		rel=$(basename "$rdir")
		fmt=$(format "$rdir")
		[ -n "$fmt" ] || fail "$rel: nothing staged"
		[ "$fmt" = apk ] && sign_apks "$rel" "$feed"

		# The reference build: --ref, or the noarch build alone.
		builds=$(cd "$rdir" && ls -d -- */ | sed 's,/$,,')
		arch_builds=$(printf '%s\n' "$builds" | grep -vx noarch || true)
		if [ -n "$arch_builds" ] && [ -n "$(for b in $arch_builds; do any_of "$rdir$b"; done)" ]; then
			[ -d "$rdir$REF" ] ||
				fail "$rel: no $REF build; the architecture-independent packages are taken from it"
			for b in $arch_builds; do
				[ "$(any_of "$rdir$b")" = "$(any_of "$rdir$REF")" ] ||
					fail "$rel: the $b build has other architecture-independent packages than the $REF build"
			done
		fi
		if [ -d "${rdir}noarch" ] && [ -n "$arch_builds" ]; then
			for p in $(any_of "${rdir}noarch"); do
				[ ! -e "$rdir$REF/$p" ] || fail "$rel: $p comes from both the noarch and the $REF build"
			done
		fi

		for b in $builds; do
			for pkg in "$rdir$b"/*.ipk "$rdir$b"/*.apk; do
				[ -f "$pkg" ] || continue
				a=$(arch_of "$pkg")
				if [ "$a" = any ]; then
					[ "$b" = noarch ] || [ "$b" = "$REF" ] || continue
					if [ "$fmt" = opkg ]; then put "$pkg" "$feed/$rel"; else put "$pkg" "$feed/$rel/noarch"; fi
				elif [ "$b" = noarch ]; then
					fail "$rel: $(basename "$pkg"), from the noarch build, is for $a"
				elif [ "$a" = "$b" ]; then
					put "$pkg" "$feed/$rel/$a"
				else
					fail "$rel: $(basename "$pkg"), from the $b build, is for $a"
				fi
			done
		done
	done
}

# --------------------------------------------------------------------- index

# opkg_index DIR [SHADOW]: DIR/Packages{,.gz,.sig}, recursing into DIR's
# subdirectories. With SHADOW, its `all` stanzas compete but are not listed.
opkg_index() {
	dir=$(cd "$1" && pwd)
	if [ -n "${2:-}" ]; then
		shadow="-v $(cd "$(dirname "$2")" && pwd)/$(basename "$2"):/shadow:ro"
		filter="--shadow /shadow"
	else
		shadow=
		filter=
	fi
	chmod -R 777 "$dir" || true
	sdk "$OPKG_IMAGE" -v "$dir":/pkgs $shadow -e MKHASH="$HOSTBIN/mkhash" -- sh -c "
		set -e
		cd /pkgs
		/builder/scripts/ipkg-make-index.sh . > /tmp/Packages.all
		sh /scripts/newest-only-index.sh opkg $filter < /tmp/Packages.all > Packages
		gzip -9c Packages > Packages.gz
		if [ -f /keys/opkg.key ]; then
			$HOSTBIN/usign -S -m Packages -s /keys/opkg.key -x Packages.sig
		fi
	"
}

# The feed URL a 24.10 router adds is the release root: opkg does not append
# the architecture to a src/gz URL. The root index combines the arch
# directories. Each arch index lists its own directory only, with the root
# as a shadow, so it drops a package the root serves, newer, as `all`.
opkg_release() {
	opkg_index "$1"
	for dir in "$1"/*/; do
		[ -d "$dir" ] || continue
		opkg_index "$dir" "$1/Packages"
	done
}

# apk only installs what the router's own <arch>/APKINDEX.tar.gz lists, so
# each arch index lists the newest of its own directory and of noarch/. An
# arch with no packages of its own, made for the manifest's index-arches,
# lists only noarch/: without it, apk on that arch could install nothing
# from the feed. All of a release's indexes are built in one container.
apk_release() {
	mkdir -p "$1/noarch"
	for dir in "$1"/*/; do
		[ -d "$dir" ] || continue
		case "$dir" in */noarch/) continue ;; esac
		chmod -R 777 "$dir" || true
	done
	sdk "$APK_IMAGE" -v "$(cd "$1" && pwd)":/release -- sh -c "
		set -e
		for dir in /release/*/; do
			[ \"\$dir\" != /release/noarch/ ] || continue
			files=
			for f in /release/noarch/*.apk \"\$dir\"*.apk; do
				if [ -f \"\$f\" ]; then files=\"\$files \$f\"; fi
			done
			[ -n \"\$files\" ] || { echo \"\$dir: no packages to index\" >&2; exit 1; }
			newest=\$(sh /scripts/newest-only-index.sh apk \$files)
			$HOSTBIN/apk mkndx --allow-untrusted -o \"\${dir}APKINDEX.tar.gz\" \$newest
			if [ -f /keys/apk.key ]; then
				$HOSTBIN/apk adbsign --allow-untrusted --reset-signatures \
					--sign-key /keys/apk.key \"\${dir}APKINDEX.tar.gz\"
			fi
		done
	"
}

cmd_index() {
	pubkeys=
	manifest=
	while [ $# -gt 0 ]; do
		case "$1" in
			--pubkeys) pubkeys=$2; shift ;;
			--manifest) manifest=$2; shift ;;
			-*) usage ;;
			*) break ;;
		esac
		shift
	done
	[ $# -eq 1 ] || usage
	[ -d "$1" ] || fail "no feed directory $1"

	for rdir in "$1"/*/; do
		[ -d "$rdir" ] || continue
		rdir=${rdir%/}
		case "$(format "$rdir")" in
			opkg)
				opkg_release "$rdir"
				if [ -n "$pubkeys" ]; then cp "$pubkeys/opkg.pub" "$rdir/feed.pub"; fi
				;;
			apk)
				if [ -n "$manifest" ]; then
					arches=$(jq -r --arg r "$(basename "$rdir")" \
						'.releases[$r]["index-arches"] // [] | .[]' "$manifest") ||
						fail "could not read the index-arches of $(basename "$rdir") from $manifest"
					for a in $arches; do mkdir -p "$rdir/$a"; done
				fi
				apk_release "$rdir"
				if [ -n "$pubkeys" ]; then cp "$pubkeys/apk.pub" "$rdir/feed.pub.pem"; fi
				;;
		esac
	done
}

[ $# -ge 1 ] || usage
cmd=$1
shift
case "$cmd" in
	file) cmd_file "$@" ;;
	index) cmd_index "$@" ;;
	*) usage ;;
esac
