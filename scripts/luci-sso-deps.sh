#!/bin/sh
# Check that the luci-sso packages this feed publishes can still be installed
# from OpenWrt's live feeds, and list a package's dependencies.
#
# OpenWrt names some libraries after their ABI: libwolfssl5.9.1.e624513f,
# libucode20230711, libmbedtls21. Every point release of a series (24.10.0,
# 24.10.1, ...) installs from one feed per branch, rebuilt from the branch,
# and when the branch updates such a library the feed serves it under the new
# name only. A luci-sso package built against the old name can then no longer
# be installed: opkg reports "cannot find dependency", apk "no such package".
#
# Usage:
#   luci-sso-deps.sh depends PACKAGE
#       Print the dependencies of one .ipk or .apk file, one name per line,
#       sorted, without version constraints. Used by luci-sso.yml to tell a
#       rebuild that changed nothing from one that must be published.
#
#   luci-sso-deps.sh check FEED_DIR
#       FEED_DIR is a checkout of the feed (gh-pages). For each OpenWrt
#       series and architecture it publishes, take the luci-sso packages its
#       index lists and compare each dependency on an ABI-named library with
#       the libraries in OpenWrt's live base feed for that series and
#       architecture. Prints one line per such dependency:
#
#         ok       <series> <arch> <package> <dependency>
#         mismatch <series> <arch> <package> <dependency> <live library>
#         waiting  <series> <arch> <package> <dependency> <live library>
#
#       mismatch: the live feed serves another, newer or equal, version of the
#       library; a rebuild against the branch fixes it. waiting: the package
#       depends on a newer version than the live feed serves yet, i.e. it was
#       built from the branch before OpenWrt's buildbots published the new
#       library; a rebuild changes nothing, the feed catches up by itself.
#       Exits 1 if there is a mismatch, 0 otherwise, 2 on errors.
#
# Environment:
#   APK        apk-tools 3 binary, for .apk files and apk indexes
#              (default: apk, or the one in an openwrt/sdk image)
#   OPENWRT    where OpenWrt's branch feeds live
#              (default: https://downloads.openwrt.org/releases)
#   LIVE_DIR   read the live indexes from LIVE_DIR/<series>/<arch>/{Packages,
#              packages.adb} instead of downloading them
#
# POSIX sh and awk, plus curl or wget, tar, gzip and sort -V: it runs in the
# openwrt/sdk images and on the runner.

set -eu
export LC_ALL=C

OPENWRT=${OPENWRT:-https://downloads.openwrt.org/releases}
if [ -z "${APK:-}" ]; then
	if [ -x /builder/staging_dir/host/bin/apk ]; then
		APK=/builder/staging_dir/host/bin/apk
	else
		APK=apk
	fi
fi

die() {
	echo "luci-sso-deps.sh: $*" >&2
	exit 2
}

# adb_stanzas FILE: an apk package, packages.adb or APKINDEX.tar.gz, as the
# opkg control stanzas the rest of this script reads. `apk adbdump` prints a
# package's fields under info:, an index's as a list under packages:, and
# lists, e.g. depends, as "key: # N items" followed by "- item" lines.
adb_stanzas() {
	"$APK" adbdump "$1" 2>/dev/null | awk '
	function flush(   k) {
		if (name == "") return
		printf "Package: %s\nVersion: %s\nArchitecture: %s\n", name, version, arch
		if (deps != "")  printf "Depends: %s\n", deps
		if (provs != "") printf "Provides: %s\n", provs
		if (abi != "")   printf "ABIVersion: %s\n", abi
		printf "\n"
		name = version = arch = deps = provs = abi = ""
	}
	# A new package: "info:" in a package file, "- name:" in an index.
	/^info:$/ { flush(); depth = 2; list = ""; next }
	/^paths:/ { flush(); depth = -1; list = ""; next }
	/^  - name: / { flush(); depth = 4; list = ""; name = substr($0, 11); next }
	depth < 0 { next }
	{
		match($0, /^ */); ind = RLENGTH
		line = substr($0, ind + 1)
	}
	ind == depth && line ~ /^[a-z-]+:/ {
		key = line; sub(/:.*/, "", key)
		val = line; sub(/^[a-z-]+: */, "", val)
		list = (val ~ /^# [0-9]+ items$/) ? key : ""
		if (key == "name")    name = val
		if (key == "version") version = val
		if (key == "arch")    arch = val
		next
	}
	ind == depth + 2 && line ~ /^- / && list != "" {
		item = substr(line, 3)
		if (list == "depends")  deps  = deps  (deps  == "" ? "" : ", ") item
		if (list == "provides") provs = provs (provs == "" ? "" : ", ") item
		if (list == "tags" && item ~ /^openwrt:abiversion=/) abi = substr(item, 20)
		next
	}
	END { flush() }'
}

# stanzas FILE: the control stanzas of a package file or an index, any format.
stanzas() {
	case "$1" in
		*.ipk)
			# OpenWrt's ipk is a gzipped tar of debian-binary, data.tar.gz
			# and control.tar.gz.
			tar -xzOf "$1" ./control.tar.gz | tar -xzOf - ./control
			printf '\n' ;;
		*.apk|*.adb|*APKINDEX.tar.gz)
			adb_stanzas "$1" ;;
		*)
			cat "$1"; printf '\n' ;;
	esac
}

cmd_depends() {
	[ "$#" -eq 1 ] && [ -f "$1" ] || die "depends: expected one package file"
	stanzas "$1" | awk '
	/^Depends: / {
		n = split(substr($0, 10), d, ",")
		for (i = 1; i <= n; i++) {
			dep = d[i]
			gsub(/^ +| +$/, "", dep)
			sub(/[ (<>=~].*$/, "", dep)
			if (dep != "") print dep
		}
	}' | sort -u
}

fetch() {
	if command -v curl >/dev/null 2>&1; then
		curl -sSfL --retry 3 -o "$2" "$1"
	else
		wget -q -O "$2" "$1"
	fi
}

# live_index SERIES ARCH OUT: OpenWrt's base feed index for the branch.
live_index() {
	case "$1" in
		24.*) file=Packages ;;
		*)    file=packages.adb ;;
	esac
	if [ -n "${LIVE_DIR:-}" ]; then
		[ -f "$LIVE_DIR/$1/$2/$file" ] || die "no $LIVE_DIR/$1/$2/$file"
		cp "$LIVE_DIR/$1/$2/$file" "$3.$file"
	else
		fetch "$OPENWRT/packages-$1/$2/base/$file" "$3.$file" \
			|| die "cannot download $OPENWRT/packages-$1/$2/base/$file"
	fi
	stanzas "$3.$file" > "$3"
}

# feed_index FEED_DIR SERIES ARCH OUT: the stanzas of the luci-sso packages
# the feed's index offers that architecture. 24.10 routers read the combined
# root index, so its stanzas for ARCH and for `all` count; 25.12 routers read
# 25.12/<arch>/APKINDEX.tar.gz, which also lists the noarch packages.
feed_index() {
	case "$2" in
		24.*) [ -f "$1/$2/Packages" ] || die "no $1/$2/Packages"
		      stanzas "$1/$2/Packages" ;;
		*)    [ -f "$1/$2/$3/APKINDEX.tar.gz" ] || die "no $1/$2/$3/APKINDEX.tar.gz"
		      stanzas "$1/$2/$3/APKINDEX.tar.gz" ;;
	esac | awk -v arch="$3" '
	BEGIN { RS = ""; FS = "\n" }
	{
		pkg = ""; a = ""
		for (f = 1; f <= NF; f++) {
			if ($f ~ /^Package: /)      pkg = substr($f, 10)
			if ($f ~ /^Architecture: /) a   = substr($f, 15)
		}
		if (pkg ~ /^luci-sso/ && (a == arch || a == "all" || a == "noarch"))
			printf "%s\n\n", $0
	}' > "$4"
}

cmd_check() {
	[ "$#" -eq 1 ] && [ -d "$1" ] || die "check: expected the feed directory"
	feed=$1
	tmp=$(mktemp -d)
	trap 'rm -rf "$tmp"' EXIT
	found=0
	status=0

	for series_dir in "$feed"/24.10 "$feed"/25.12; do
		[ -d "$series_dir" ] || continue
		series=$(basename "$series_dir")
		for arch_dir in "$series_dir"/*/; do
			arch=$(basename "$arch_dir")
			[ "$arch" != noarch ] || continue
			found=1
			live_index "$series" "$arch" "$tmp/live"
			feed_index "$feed" "$series" "$arch" "$tmp/feed"
			[ -s "$tmp/feed" ] || die "$series/$arch: the feed lists no luci-sso package"

			# One line per dependency on an ABI-named base library:
			#   <status> <package> <dependency> [<live library>]
			# The live feed's ABI-named libraries are the packages with an
			# ABIVersion; their name less that suffix is the library's stem
			# (libwolfssl5.9.1.e624513f -> libwolfssl). A dependency the live
			# feed serves, by name or Provides, is ok; one that starts with a
			# live stem followed by a digit names another ABI of that library.
			# Any other dependency (libc, luci-base, luci-sso-crypto) is not
			# in the base feed or carries no ABI, and is not this check's.
			awk -v series="$series" -v arch="$arch" '
			BEGIN { RS = ""; FS = "\n" }
			FILENAME == ARGV[1] {
				name = ""; abi = ""; provs = ""
				for (f = 1; f <= NF; f++) {
					if ($f ~ /^Package: /)    name  = substr($f, 10)
					if ($f ~ /^ABIVersion: /) abi   = substr($f, 13)
					if ($f ~ /^Provides: /)   provs = substr($f, 11)
				}
				served[name] = 1
				n = split(provs, p, ",")
				for (i = 1; i <= n; i++) {
					x = p[i]; gsub(/^ +| +$/, "", x); sub(/[ (<>=~].*$/, "", x)
					served[x] = 1
				}
				if (abi != "" && length(name) > length(abi) &&
				    substr(name, length(name) - length(abi) + 1) == abi) {
					stem = substr(name, 1, length(name) - length(abi))
					live[stem] = name
					live_abi[stem] = abi
				}
				next
			}
			{
				pkg = ""; deps = ""
				for (f = 1; f <= NF; f++) {
					if ($f ~ /^Package: /) pkg  = substr($f, 10)
					if ($f ~ /^Depends: /) deps = substr($f, 10)
				}
				n = split(deps, d, ",")
				for (i = 1; i <= n; i++) {
					dep = d[i]; gsub(/^ +| +$/, "", dep); sub(/[ (<>=~].*$/, "", dep)
					if (dep == "" || dep ~ /^!/) continue
					best = ""
					for (stem in live)
						if (index(dep, stem) == 1 && substr(dep, length(stem) + 1, 1) ~ /[0-9]/ &&
						    length(stem) > length(best))
							best = stem
					if (best == "") continue
					if (dep in served)
						print "ok", pkg, dep
					else
						print "differs", pkg, dep, live[best], substr(dep, length(best) + 1), live_abi[best]
				}
			}' "$tmp/live" "$tmp/feed" > "$tmp/result"

			while read -r state pkg dep live_name want have; do
				if [ "$state" = ok ]; then
					echo "ok       $series $arch $pkg $dep"
					continue
				fi
				# The package's library is newer than the live one when the
				# version numbers of its ABI sort after the live ABI's. An ABI
				# may end in a hash of the build options, 5.9.1.e624513f.
				want_v=$(printf '%s' "$want" | sed -E 's/\.[0-9a-f]{8}$//; s/^([0-9]+(\.[0-9]+)*).*/\1/')
				have_v=$(printf '%s' "$have" | sed -E 's/\.[0-9a-f]{8}$//; s/^([0-9]+(\.[0-9]+)*).*/\1/')
				if [ "$want_v" != "$have_v" ] &&
				   [ "$(printf '%s\n%s\n' "$want_v" "$have_v" | sort -V | tail -n 1)" = "$want_v" ]; then
					echo "waiting  $series $arch $pkg $dep $live_name"
				else
					echo "mismatch $series $arch $pkg $dep $live_name"
					status=1
				fi
			done < "$tmp/result"
		done
	done
	[ "$found" = 1 ] || die "check: $feed has no 24.10/<arch> or 25.12/<arch> directory"
	return "$status"
}

[ "$#" -ge 1 ] || die "usage: $0 depends PACKAGE | $0 check FEED_DIR"
cmd=$1; shift
case "$cmd" in
	depends) cmd_depends "$@" ;;
	check)   cmd_check "$@" ;;
	*)       die "unknown command: $cmd (expected depends or check)" ;;
esac
