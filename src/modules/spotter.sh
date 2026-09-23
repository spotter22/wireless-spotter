#!/bin/bash

#export debug=1
{ _print_verbose(){ [ "${debug}" = "1" ] && echo -e "${@}"; }; } 2>/dev/null
_spotter_get_config(){
	local IFS result err
	[ -n "${spotter_init}" ] && return 0
	[ -n "${spotter_root}" ] && { readonly spotter_root="${spotter_root}" 2>/dev/null; } || { readonly spotter_root=~/wspot-root 2>/dev/null; }; db_root="${spotter_root}/database"; mkdir -p "${db_root}" || return ${?}
	[ -s "${db_root}/.id" ] && { result=($(cat "${db_root}/.id" | sed "s|/| |")); readonly cid="${result[0]}"; readonly uid="${result[1]}"; readonly db_root="${db_root}/$(cat "${db_root}/.id")"; readonly spotter_init="1"; mkdir -p "${db_root}" && return 0 || return 1; }

	# setup stage
	command -v getprop >/dev/null || { echo "_spotter_get_config: error cannot locate getprop in path"; return 1; }
	[ -n "${RANDOM}" ] || { echo "_spotter_get_config: error your shell does not support \$RANDOM expansion"; return 2; }
	[ -d "${db_root}" ] || { mkdir -p  "${db_root}" && echo "_spotter_get_config: created new root dir: ${db_root}" || { err=${?}; echo "_spotter_get_config: error creating root dir failed: dir=${db_root} err=${err}"; return ${err}; }; }
	[ -w "${db_root}" ] || { echo "_spotter_get_config: error cannot write into: ${db_root}"; return 3; }

	# cid stage
	result=$(getprop "persist.sys.timezone")
	[ -n "${result}" ] && { cid="${result/\//-}"; cid="${cid,,}"; } || { echo "_spotter_get_config: error parsing cid failed (err: probably \"persist.sys.timezone\" is not set)."; return 4; }
	mkdir -p "${db_root}/${cid}" || { echo "_spotter_get_config: error cannot create cid dir: dir=${db_root} cid=${cid} err=${?}"; return ${?}; }

	# uid stage
	uid="${RANDOM}${RANDOM}${RANDOM}$(date +%s)"
	echo "${cid}/${uid}" >"${db_root}/.id"
	readonly db_root="${db_root}/${cid}/${uid}"; readonly spotter_init="1"
	mkdir -p "${db_root}"
	return 0
}


_spotter_get_gid_state()
{
	local list x
	_spotter_get_config || return ${?}
	for x in ${@:2}; do
		[ -s "${db_root}/${1}.${x}" ] && list+=" ${db_root}/${1}.${x}"
	done

	[ -n "${list}" ] && { cat ${list} | sort -R; } || return 1
}

_spotter_return_gid_status(){
	_spotter_get_config || return ${?}
	[ -s "${db_root}/${1//:/}.gid" ] && return 0 || return 1
}


_spotter_put_gid_state()
{
	local gid state list
	[[ "${3}" =~ ([a-fA-F0-9]{2}:[a-fA-F0-9]{2}:[a-fA-F0-9]{2}:[a-fA-F0-9]{2}:[a-fA-F0-9]{2}:[a-fA-F0-9]{2}) ]] || return 1
	_spotter_get_config || return ${?}
	[ -s "${db_root}/${1}.${2}" ] && { grep -Fqm1 "${3}" "${db_root}/${1}.${2}" && return 1 || { echo "${3}" >>"${db_root}/${1}.${2}"; return 0; }; } || echo "${3}" >>"${db_root}/${1}.${2}"
}


_spotter_get_bssid_info()
{
	_spotter_get_config || return ${?}
	[ -n "${2}" ] || return 1
	[ -s "${db_root}/${1//:/}.info" ] && { grep -Fqm1 "${2}" "${db_root}/${1//:/}.info" && source "${db_root}/${1//:/}.info" || return 2; } || return 1
}


_spotter_put_bssid_info()
{
	local err
	_spotter_get_config || return ${?}
	[ -n "${13}" ] || return 1
	[ -s "${db_root}/${8}.points" ] && { grep -Fqm1 "${1}" "${db_root}/${8}.points" || echo "${1}" >>"${db_root}/${8}.points"; } || echo "${1}" >>"${db_root}/${8}.points"
	[ -s "${db_root}/${1//:/}.gid" ] && { grep -Fqm1 "${8}" "${db_root}/${1//:/}.gid" || echo "${8}" >>"${db_root}/${1//:/}.gid"; } || echo "${8}" >>"${db_root}/${1//:/}.gid"
	echo "\
		bssid=\"${1}\"
		ssid=\"${2}\"
		freq=\"${3}\"
		sec=\"${4}\"
		gwip=\"${5}\"
		gaddr=\"${6}\"
		route=\"${7}\"
		gid=\"${8}\"
		domain=\"${9}\"
		host=\"${10}\"
		port=\"${11}\"
		status=\"${12}\"
		stamp=\"${13}\"" >"${db_root}/${1//:/}.info" || { err=${?}; echo "_spotter_put_bssid_info: error could not put entry into: ${db_root}/${1//:/}.info"; return ${err}; }
	return 0
}


_spotter_get_bssid_list()
{
	local bssid gid result x ret i; i=0
	_spotter_get_config || return ${?}
	for x in ${@}; do
		[[ "${ret}" =~ "${x//:/}" ]] && continue
		[ -s "${db_root}/${x//:/}.list" ] && { ret+="${db_root}/${x//:/}.list "; i=$((i+1)); }
		[ -s "${db_root}/${1}.points" ] && { result+="${db_root}/${1}.points "; }
	done
	for x in $(echo "${result}" | xargs cat); do
		[[ "${ret}" =~ "${x//:/}" ]] && continue
		[ -s "${db_root}/${x//:/}.list" ] && { ret+="${db_root}/${x//:/}.list "; i=$((i+1)); }
	done
	echo "${ret}" | xargs cat | sort | uniq | sort -R
}


_spotter_put_bssid_list()
{
	local bssid list x ret err i; i=0
	bssid="${1//:/}"; list="${@:2}"
	[ -n "${bssid}" ] || return 1
	[ -n "${list}" ] || return 1
	_spotter_get_config || return ${?}
	[ -s "${db_root}/${bssid}.list" ] && result=$(cat "${db_root}/${bssid}.list")

	for x in ${list}; do
		if ([[ ! "${result}" =~ "${x}" ]] || exit 1) && \
			([[ ! "${ret}" =~ "${x}" ]] || exit 2) && \
			([[ "${x}" =~ ([a-fA-F0-9]{2}:[a-fA-F0-9]{2}:[a-fA-F0-9]{2}:[a-fA-F0-9]{2}:[a-fA-F0-9]{2}:[a-fA-F0-9]{2}) ]] || exit 3); then
			ret+="${x}\n"; i=$((i+1))
		else
			_print_verbose "_spotter_put_bssid_list: warning ignoring address: ${x} err=${?}"
			continue
		fi
	done
	[ ${i} -ge 1 ] && { echo -e "${ret}" >>"${db_root}/${bssid}.list" || { err=${?}; echo "_spotter_put_bssid_list: error could not put entry into: ${db_root}/${bssid}.list"; return ${err}; }; }
	return 0
}


_spotter_get_bssid_rate()
{
	_spotter_get_config || return ${?}
	[ -s "${db_root}/${1//:/}.rate" ] && { cat "${db_root}/${1//:/}.rate"; return 0; } || return 1
}


_spotter_put_bssid_rate()
{
	_spotter_get_config || return ${?}
	echo "${2} $(date +%s)" >>"${db_root}/${1//:/}.rate"
}

