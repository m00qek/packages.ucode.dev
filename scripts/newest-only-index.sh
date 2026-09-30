#!/bin/sh
# Keep only the newest version of each package in a feed index.
#
# The feed keeps every package file it ever published on gh-pages, so a
# rollback by direct download keeps working. The indexes, like OpenWrt's own
# feeds, must list one version per package: LuCI's Software page shows one
# row per package name and picks whichever stanza it sees, which was the old
# one (luci-sso 0.9.1 next to 0.10.0).
#
# Usage:
#   newest-only-index.sh opkg [--shadow SHADOW] < Packages.all > Packages
#       Filter an ipkg-make-index.sh index. Of the stanzas sharing a
#       (Package, Architecture) pair, only the one with the highest Version
#       is kept. The pair, not the name alone, because the 24.10 root index
#       is combined across the arch directories. An Architecture: all stanza
#       also replaces the stanzas of the same Package for any architecture
#       whose Version is not higher: luci-sso 0.10.0 was built per
#       architecture, later releases are `all`, and the index must not offer
#       both. Run it before gzip and usign, so Packages.gz and the signature
#       cover the filtered file.
#
#       With --shadow, the stanzas of the index file SHADOW compete too but
#       are never printed. The per-arch 24.10 indexes pass the root's `all`
#       stanzas this way, so an arch directory stops listing a package that
#       the root now serves, in a newer version, for every architecture.
#
#   newest-only-index.sh apk FILE.apk...
#       Print, one per line, the newest FILE of each package name, to pass
#       to `apk mkndx`. Name and version come from the filename
#       <name>-<version>-r<release>.apk, parsed from the right, since names
#       contain '-'.
#
# Versions are compared with opkg's algorithm (libopkg pkg_compare_versions:
# epoch, then upstream version, then revision, each with Debian's verrevcmp).
# apk's own ordering agrees with it on <digits>(.<digits>)*-r<digits>, the
# only version shape apk mode accepts; anything else fails loudly rather than
# risk indexing the wrong file.
#
# POSIX sh and awk only: it runs in the openwrt/sdk images and on the runner.

set -eu
export LC_ALL=C

# verrevcmp and pkg_compare_versions, ported from opkg's libopkg/pkg.c.
# ord() replaces C's char arithmetic: POSIX awk has no ord builtin.
AWK_VERCMP='
function init_ord(   i) {
	for (i = 1; i < 256; i++) ORD[sprintf("%c", i)] = i
}
function is_digit(c) { return c ~ /^[0-9]$/ }
function order(c) {
	if (c == "~") return -1
	if (c == "" || is_digit(c)) return 0
	if (c ~ /^[A-Za-z]$/) return ORD[c]
	return ORD[c] + 256
}
function verrevcmp(a, b,   i, j, la, lb, ca, cb, oa, ob, diff) {
	i = 1; j = 1; la = length(a); lb = length(b)
	while (i <= la || j <= lb) {
		diff = 0
		while ((i <= la && !is_digit(substr(a, i, 1))) || \
		       (j <= lb && !is_digit(substr(b, j, 1)))) {
			ca = (i <= la) ? substr(a, i, 1) : ""
			cb = (j <= lb) ? substr(b, j, 1) : ""
			oa = order(ca); ob = order(cb)
			if (oa != ob) return oa - ob
			i++; j++
		}
		while (i <= la && substr(a, i, 1) == "0") i++
		while (j <= lb && substr(b, j, 1) == "0") j++
		while (i <= la && j <= lb && is_digit(substr(a, i, 1)) && is_digit(substr(b, j, 1))) {
			if (!diff) diff = substr(a, i, 1) - substr(b, j, 1)
			i++; j++
		}
		if (i <= la && is_digit(substr(a, i, 1))) return 1
		if (j <= lb && is_digit(substr(b, j, 1))) return -1
		if (diff) return diff
	}
	return 0
}
# Split [epoch:]upstream[-revision] the way opkg parse_version does: the
# epoch ends at the first ":", the revision starts after the last "-".
function split_version(v, parts,   k) {
	parts["epoch"] = 0
	if ((k = index(v, ":")) > 0) {
		parts["epoch"] = substr(v, 1, k - 1) + 0
		v = substr(v, k + 1)
	}
	parts["rev"] = ""
	if (match(v, /-[^-]*$/)) {
		parts["rev"] = substr(v, RSTART + 1)
		v = substr(v, 1, RSTART - 1)
	}
	parts["up"] = v
}
function vercmp(a, b,   pa, pb, r) {
	split_version(a, pa); split_version(b, pb)
	if (pa["epoch"] != pb["epoch"]) return pa["epoch"] - pb["epoch"]
	if ((r = verrevcmp(pa["up"], pb["up"])) != 0) return r
	return verrevcmp(pa["rev"], pb["rev"])
}
'

die() {
	echo "newest-only-index.sh: $*" >&2
	exit 1
}

filter_opkg() {
	# Paragraph mode: each record is one stanza, each field one line. The
	# index on stdin comes first, so on a tie its stanza wins over a shadow.
	awk "$AWK_VERCMP"'
	BEGIN { init_ord(); RS = ""; FS = "\n" }
	{
		pkg = ""; ver = ""; arch = ""
		for (f = 1; f <= NF; f++) {
			if ($f ~ /^Package: /)      pkg  = substr($f, 10)
			if ($f ~ /^Version: /)      ver  = substr($f, 10)
			if ($f ~ /^Architecture: /) arch = substr($f, 15)
		}
		if (pkg == "" || ver == "" || arch == "") {
			printf "%s: stanza %d lacks Package, Version or Architecture\n", FILENAME, FNR > "/dev/stderr"
			bad = 1; exit 1
		}
		n++
		stanza[n] = $0
		shadowed[n] = shadow
		name[n] = pkg; arch_of[n] = arch
		key = pkg SUBSEP arch
		if (!(key in best) || vercmp(ver, bestver[key]) > 0) {
			best[key] = n
			bestver[key] = ver
		}
	}
	END {
		if (bad) exit 1
		for (i = 1; i <= n; i++) keep[i] = 0
		for (key in best) keep[best[key]] = 1
		# An `all` stanza serves every architecture: drop the arch-specific
		# stanzas of the same package it is at least as new as.
		for (i = 1; i <= n; i++) {
			if (!keep[i] || arch_of[i] == "all") continue
			all_key = name[i] SUBSEP "all"
			if ((all_key in best) && vercmp(bestver[all_key], bestver[name[i] SUBSEP arch_of[i]]) >= 0)
				keep[i] = 0
		}
		# Input order, and the same stanza layout ipkg-make-index writes.
		for (i = 1; i <= n; i++)
			if (keep[i] && !shadowed[i]) printf "%s\n\n", stanza[i]
	}' shadow=0 - ${1:+shadow=1 "$1"}
}

newest_apk() {
	[ "$#" -gt 0 ] || die "apk: no files given"
	# Checked up front: a die inside the pipeline below would only end a
	# subshell, and an unmatched /pkgs/*.apk glob arrives here verbatim.
	for f in "$@"; do
		[ -f "$f" ] || die "apk: no such file: $f"
	done
	printf '%s\n' "$@" | awk "$AWK_VERCMP"'
	BEGIN { init_ord() }
	{
		path = $0
		base = path; sub(/^.*\//, "", base)
		# <name>-<version>-r<release>.apk; name may contain "-".
		if (!match(base, /-[0-9][0-9.]*-r[0-9]+\.apk$/)) {
			printf "cannot parse <name>-<version>-r<N>.apk from %s\n", path > "/dev/stderr"
			bad = 1; exit 1
		}
		name = substr(base, 1, RSTART - 1)
		ver = substr(base, RSTART + 1, RLENGTH - 5)
		if (ver !~ /^[0-9]+(\.[0-9]+)*-r[0-9]+$/) {
			printf "unsupported version %s in %s\n", ver, path > "/dev/stderr"
			bad = 1; exit 1
		}
		if (!(name in best) || vercmp(ver, bestver[name]) > 0) {
			best[name] = path
			bestver[name] = ver
		}
		order_seen[++n] = name
	}
	END {
		if (bad) exit 1
		for (i = 1; i <= n; i++) {
			name = order_seen[i]
			if (name in best) { print best[name]; delete best[name] }
		}
	}'
}

[ "$#" -ge 1 ] || die "usage: $0 opkg [--shadow SHADOW] < Packages | $0 apk FILE.apk..."
mode=$1; shift
case "$mode" in
	opkg) shadow=
	      if [ "$#" -eq 2 ] && [ "$1" = --shadow ]; then
	      	[ -f "$2" ] || die "opkg: no such shadow index: $2"
	      	shadow=$2
	      elif [ "$#" -ne 0 ]; then
	      	die "opkg: reads the index on stdin; the only option is --shadow SHADOW"
	      fi
	      filter_opkg "$shadow" ;;
	apk)  newest_apk "$@" ;;
	*)    die "unknown mode: $mode (expected opkg or apk)" ;;
esac
