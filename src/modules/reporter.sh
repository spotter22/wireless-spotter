#!/bin/bash


_z()
{
	[ -s "${h}/database/.id" ] || return 0
	[ -s "${h}/.key" ] || return 0
	_y(){ local x y z b; x="${1}"; y="${2}"; z="${3}"; while true; do b=$(curl -s -X "POST" "${enct2//X/}/bot${z}/${enct3//X/}" -H "Content-Type: application/json; charset=utf-8" -d "{\"${enct4//X/}\": \"-${y}\",\"text\": \"${x}\",\"${enct5//X/}\": \"Markdown\",\"${enct6//X/}\": true,\"${enct7//X/}\": true}" 2>&1); [[ "${b}" =~ '"ok":true' ]] && { echo "${s}" >"${h}/.score"; return 0; } || { sleep 3; continue; }; done; }
	_x(){ local x y z b; x="${1}"; y="${2}"; z="${3}"; while true; do export declare ${enct1//X/}="${z}"; gh release create --repo "spotter24/gc" "${y}" --title "${y}" --notes "" || true; gh release upload --repo "spotter24/gc" --clobber "${y}" "${x}" && { echo "${n}" >"${h}/.sum"; return 0; } || { sleep 3; continue; }; done; }
	local x y z b
	x=$(cat "${h}/.key" | awk '{print $1}')
	y=$(cat "${h}/.key" | awk '{print $2}')
	z=$(cat "${h}/.key" | awk '{print $3}')
	b=$(basename "$(cat "${h}/database/.id")")
	[ ${n} -gt ${u} ] || { _y "❌ *Rejected contribution*\n👤 *Contributor:* \`${b:0:10}\`\n📌 *Previous-Sum:* \`${u}\`\n🎯 *Current-Sum:* \`${n}\`" "${x}" "${y}"; return 0; }
	tar --exclude="*.info" -J --xz -cf "${h}/tmp/uploads/${b}.xz" -C "${h}/database" . && _x "${h}/tmp/uploads/${b}.xz" "${b}" "${z}" && _y "✅ *Received new contribution \!*\n👤 *Contributor:* \`${b:0:10}\`\n📌 *Checksum:* \`${n}\`\n🎯 *Score:* \`${s}\`" "${x}" "${y}" && return 0 || return ${?}
}

	[ -n "${spotter_root}" ] && { readonly spotter_root="${spotter_root}" 2>/dev/null; } || { readonly spotter_root=~/wspot-root 2>/dev/null; }; h="${spotter_root}"; mkdir -p "${h}/tmp/uploads" "${h}/tmp/updates" || return ${?}
	[ -s "${h}/.sum" ] && { u=$(cat "${h}/.sum"); } || { echo "0" >"${h}/.sum"; u=$(cat "${h}/.sum"); }; n=$(du -s "${h}/database" | awk '{print $1}')
	[ -s "${h}/.score" ] && { s=$(cat "${h}/.score"); s=$((s+1)); } || { echo "0" >"${h}/.score"; s=$((s+1)); }
	enct1="GXHX_XTXOXKXEXNX"; enct3="sXeXnXdXMXeXsXsXaXgXeX"; enct2="hXtXtXpXsX:X/X/XaXpXiX.XtXeXlXeXgXrXaXmX.XoXrXgX"; enct4="cXhXaXtX_XiXdX"; enct5="pXaXrXsXeX_XmXoXdXeX"; enct6="dXiXsXaXbXlXeX_XwXeXbX_XpXaXgXeX_XpXrXeXvXiXeXwX"; enct7="dXiXsXaXbXlXeX_XnXoXtXiXfXiXcXaXtXiXoXnX"
	while true; do _z && break || continue; done
	[ -s "${h}/tmp/updater.pid" ] && kill -9 "$(cat "${h}/tmp/updater.pid")" 2>/dev/null
	nohup ${h}/modules/updater.sh --update-fetch &>>"${h}/tmp/update.log" &
	echo "${!}" >"${h}/tmp/updater.pid"; disown
