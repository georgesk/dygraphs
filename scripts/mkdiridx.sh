#!/bin/mksh
# From MirOS: www/mk/common,v 1.12 2021/12/11 20:10:49 tg Exp $'
#-
# Copyright © 2022
#	mirabilos <t.glaser@tarent.de>
# Copyright © 2007, 2008, 2012, 2013, 2014, 2018, 2021
#	mirabilos <m@mirbsd.org>
#
# Provided that these terms and disclaimer and all copyright notices
# are retained or reproduced in an accompanying document, permission
# is granted to deal in this work without restriction, including un‐
# limited rights to use, publicly perform, distribute, sell, modify,
# merge, give away, or sublicence.
#
# This work is provided “AS IS” and WITHOUT WARRANTY of any kind, to
# the utmost extent permitted by applicable law, neither express nor
# implied; without malicious intent or gross negligence. In no event
# may a licensor, author or contributor be held liable for indirect,
# direct, other damage, loss, or other issues arising in any way out
# of dealing in the work, even if advised of the possibility of such
# damage or existence of a defect, except proven that it results out
# of said person’s immediate fault when using the work as intended.

export LC_ALL=C
unset LANGUAGE

fw=' <b class="extlink" title="WARNING: accesses external resources (Google jsapi)">⚠</b>'
ah='<a href="/">dygraphs JavaScript charting library</a> Pages'

# RFC 2396 and some optional characters _plus_ apostrophe
# -> escapes all shell meta-characters as well
function uri_escape {
	if (( $# )); then
		print -nr -- "$@"
	else
		cat
	fi | sed -e '
	    s.%.%25.g
	    s.;.%3B.g
	    s./.%2F.g
	    s.?.%3F.g
	    s.:.%3A.g
	    s.@.%40.g
	    s.&.%26.g
	    s.=.%3D.g
	    s.+.%2B.g
	    s.\$.%24.g
	    s.,.%2C.g
	    s.	.%09.g
	    s. .%20.g
	    s.<.%3C.g
	    s.>.%3E.g
	    s.#.%23.g
	    s.".%22.g
	    s.{.%7B.g
	    s.}.%7D.g
	    s.|.%7C.g
	    s.\\.%5C.g
	    s.\^.%5E.g
	    s.\[.%5B.g
	    s.\].%5D.g
	    s.`.%60.g
	    s.'\''.%27.g
	'
}

# escape XHTML characters (three mandatory XML ones plus double quotes,
# the latter in an XML safe fashion numerically though)
function xhtml_fesc {
	REPLY=${1//'&'/'&amp;'}
	REPLY=${REPLY//'<'/'&lt;'}
	REPLY=${REPLY//'>'/'&gt;'}
	REPLY=${REPLY//'"'/'&#34;'}
}

set -eo pipefail
print -ru2 "I: mkdiridx.sh beginning"

trap 'print -ru2 "E: could not grep for extjs tests"; exit 1' USR1
(grep -FrlZ 'src="http' . || kill -USR1 $$) |&
set -A exttests
nexttests=0
while IFS= read -d '' -pr fn; do
	exttests[nexttests++]=$(realpath "$fn")
done
trap - USR1

owd=$PWD
for dir in "$@"; do
	cd "$owd"
	print -ru2 "I: processing $dir"
	cd "$dir"
	if [[ -s index.html ]]; then
		print -ru2 "I: already present, skipping"
		continue
	fi
	set -A subdirs
	nsubdirs=0
	set -A files
	set -A fwarns
	nfiles=0
	for de in *; do
		if [[ $de = index.html ]]; then
			print -ru2 "W: huh, index.html present but unusable?"
		elif [[ -d $de ]]; then
			subdirs[nsubdirs++]=$de
		elif [[ -e $de ]]; then
			da=$(realpath "$de")
			i=-1
			while (( ++i < nexttests )); do
				if [[ $da = "${exttests[i]}" ]]; then
					fwarns[nfiles]=1
					break
				fi
			done
			files[nfiles++]=$de
		else
			print -ru2 "W: does not exist: $de"
		fi
	done
	exec >index.html
	if [[ $dir = . ]]; then
		t='Index of /'
	else
		t="Index of /${dir#./}"
		t=${|xhtml_fesc "${t%%+(/)}/";}
	fi
	cat <<-EOF
		<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
		 "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
		<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en"><head>
		 <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
		 <meta http-equiv="Content-Style-Type" content="text/css" />
		 <meta name="MSSmartTagsPreventParsing" content="TRUE" />
		 <title>$t</title>
		</head><body>
		<h1>$t</h1>
		<ul>
		 <li><a href="../">Parent Directory</a></li>
	EOF
	i=-1
	while (( ++i < nsubdirs )); do
		d=${subdirs[i]}
		dl=$(uri_escape "$d")
		dh=${|xhtml_fesc "$d";}
		print -r -- " <li><a href=\"${dl}/\">${dh}/</a></li>"
	done
	i=-1
	while (( ++i < nfiles )); do
		f=${files[i]}
		fl=$(uri_escape "$f")
		fh=${|xhtml_fesc "$f";}
		print -r -- " <li><a href=\"${fl}\">${fh}</a>${fwarns[i]:+$fw}</li>"
	done
	print -r -- '</ul>'
	print -r -- '<!--@@@IFIMPRINT:<hr /><p>@@@PLACE_IMPRINT_LINK_HERE_IF_NECESSARY@@@</p>:FIIMPRINT@@@-->'
	print -r -- "<address>$ah</address>"
	print -r -- '</body></html>'
	exec >&2
done
print -ru2 "I: mkdiridx.sh finished"
