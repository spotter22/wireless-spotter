#!/bin/bash


_database_merger_find()
{
	local list ucid index f x y i n; list="${@}"
	[ -n "${spotter_root}" ] && { readonly spotter_root="${spotter_root}" 2>/dev/null; } || { readonly spotter_root=~/wspot-root 2>/dev/null; }; mkdir -p "${spotter_root}/tmp" || return ${?}
	source "${spotter_root}/modules/spotter.sh" || return ${?}; _spotter_get_config

		echo "searching database inside: ${list}"
	while read -r f; do
			ucid=($(tar -Oxf "${f}" "./.id" 2>/dev/null | sed "s|/| |"))
			([[ "${ucid[0]}" =~ (.*-.*) ]] && [[ ${ucid[1]} -eq ${ucid[1]} ]] 2>/dev/null) && { b=$(basename "${f}"); echo "browsing: ${b}"; } || continue
			i=0; n=0
		for x in $(tar --exclude="./*/*/*" -tf "${f}" | grep -o "./.*-.*/[0-9][^/]*"); do
			i=$((i+1)); ucid="${x/\.\//}"; ucid="${ucid/\// }"; ucid=(${ucid})
			[ "${xcid}" = "${xucid[0]}" ] && n=$((n+1)) || { echo "invalid-cid: ${b}"; continue; }
			index=$(tar -tf "${f}" "${x}" | grep -F ".list" | wc -l)
			echo "found ${index} entries inside uid: $(basename ${x})"
			[ ${index} -ge 1 ] && { _database_merger_apply "${f}" "${x}" || return ${?}; }
		done
		([ ${n} -ne 0 ] && [ ${i} -eq ${n} ] && [ "${b:0:12}" = "513037856628" ]) && rm -f "${f}"
	done< <(find ${list} \( -type f -name "513037856628*.xz" -or -name "wspot-db-*.zip" \) 2>/dev/null)
}


_database_merger_apply()
{
	local db sub result new user list x i e; db="${1}"; sub="${2}"; i=(0 0); e=(0 0)
	[ -e "${spotter_root}/tmp/merge" ] && rm -r "${spotter_root}/tmp/merge"; mkdir -p "${spotter_root}/tmp/merge"
	tar -C "${spotter_root}/tmp/merge" --transform='s/.*\///' -xvf "${db}" "${sub}" | sed "s|./.*-.*/||g" | grep -Ev "\.id|.info" >"${spotter_root}/tmp/merge/list"

	while read -r x; do
			new="${spotter_root}/tmp/merge/${x}"
			user="${spotter_root}/database/${cid}/${uid}/${x}"
			([ -d "${new}" ] || [ -d "${user}" ]) && continue
		if ([ -s "${new}" ] && [ -s "${user}" ]); then
			result=($(stat -c%s "${new}" "${user}"))
			[ ${result[0]} -ne "${result[1]}" ] && i[1]=$((i[1]+1)) || { e[0]=$((e[0]+1)); continue; }
			cat "${new}" "${user}" | sort -u >"${user}" || return 1
		elif ([ -s "${new}" ] && [ ! -s "${user}" ]); then
			i[0]=$((i[0]+1))
			list+="${new} "
		fi
	done< <(cat "${spotter_root}/tmp/merge/list")

	if [ ${i[0]} -ge 1 ]; then
		echo "${list}" | xargs cp --target-directory="${db_root}" || return 1
	fi
	echo -e "stats: ${i[0]} added, ${i[1]} merged, ${e[0]} matched."
}


_database_merger_correctname(){
	local b x d
	while read -r x; do
			b=$(basename "${x}")
			d=$(dirname "${x}")
		if [ "${b:0:12}" != "513037856628" ]; then
			echo "corrected: 513037856628${b}"
			mv "${x}" "${d}/513037856628${b}"
		fi
	done< <(find "${@}" -type f -name "*.xz")
}


_database_merger_gc(){
	local err arr t i n x
	source "${spotter_root}/modules/spotter.sh" || return ${?}; _spotter_get_config
	mkdir -p "${spotter_root}/tmp/gc/"; remote="spotter24/gc"; listfile="${spotter_root}/tmp/gc/list"
	export GH_TOKEN="$(awk '{print $3}' "${spotter_root}/.key")"; wspot_merger_remove="${wspot_merger_remove:-echo}"
	[ -s "${listfile}" ] || { echo "fetching list.."; gh release list --repo "${remote}" >"${listfile}" || { err=${?}; echo -n>"${listfile}"; return ${err}; }; }
	[ -s "${spotter_root}/tmp/gc/index" ] && source "${spotter_root}/tmp/gc/index"

	if [ "${1}" = "download" ]; then
			i=0; n=0
		while read -r x; do
				i=$((i+1)); arr=(${x}); arr[0]="x${arr[0]}"
			if [ "${arr[1]}" = "${!arr[0]}" ]; then
				n=$((n+1)); echo "skipping: ${arr[0]} stamp: ${arr[1]}"
			else
				[ -n "${!arr[0]}" ] && { echo "updating: ${!arr[0]} stamp: ${arr[1]}"; } || { echo "downloading: ${arr[0]} stamp: ${arr[1]}"; }
				t=0; until [ ${t} -ge 3 ]; do gh release download --repo "${remote}" --clobber -D "${spotter_root}/tmp/gc" "${arr[0]:1}" 2>"${spotter_root}/tmp/gc/result" && { n=$((n+1)); break; } || { grep -Fq "no assets to download" "${spotter_root}/tmp/gc/result" && n=$((n+1)) && break; t=$((t+1)); }; done
				[ ${t} -le 2 ] && { echo "${arr[0]}=\"${arr[1]}\"" >>"${spotter_root}/tmp/gc/index"; continue; } || break
			fi
		done< <(cat "${listfile}" | sed "s/Latest//" | awk '{print $2" "$3}')
		[ ${i} -eq ${n} ] && { echo "finished, fetch list is completed."; echo -n>"${spotter_root}/tmp/gc/list"; return 0; } || { echo "error, fetch list is uncompleted."; return 1; }
	elif [ "${1}" = "remove" ]; then
		while read -r x; do
			${wspot_merger_remove} --repo "${remote}" --cleanup-tag -y "${x}"
		done< <(cat "${listfile}" | sed "s/Latest//" | awk '{print $2}')
		echo -n>"${spotter_root}/tmp/gc/list"
	fi
}


_database_merger_gc2(){
	local ret err arr i n e x t; i=0; n=0
	source "${spotter_root}/modules/spotter.sh" || return ${?}; _spotter_get_config
	mkdir -p "${spotter_root}/tmp/gc2/"; remote="spotter24/gc2"; listfile="${spotter_root}/tmp/gc2/list"
	export GH_TOKEN="$(awk '{print $3}' "${spotter_root}/.key")"; wspot_merger_remove="${wspot_merger_remove:-echo}"
	[ -s "${spotter_root}/tmp/gc2/index" ] && { source "${spotter_root}/tmp/gc2/index" || return ${?}; }
	[ -s "${listfile}" ] || { echo "fetching list.."; gh release view --repo "${remote}" "${cid}" --json "assets" | jq -r 'foreach .[].[] as $x (0; . + 1; "\($x.name) \($x.updatedAt)")' >"${listfile}" || { err=${?}; echo -n>"${listfile}"; return ${err}; }; }
	if [ "${1}" = "download" ]; then
		while read -r x; do
				i=$((i+1)); arr=(${x}); e="x${arr[0]/.xz/}"; t=0
			if [ "${arr[1]}" = "${!e}" ]; then
				n=$((n+1)); echo "skipping: ${arr[0]} stamp: ${arr[1]}"
			else
				until [ ${t} -ge 3 ]; do echo "downloading: ${arr[0]}"; ret=$(gh release download --repo "${remote}" "${cid}" -p "${arr[0]}" --clobber -D "${spotter_root}/tmp/gc2" 2>&1) && { err=${?}; break; } || { err=${?}; [[ "${ret}" =~ "no assets to download" ]] && break || t=$((t+1)); }; done
				[ ${err} -eq 0 ] && { n=$((n+1)); [ -s "${spotter_root}/tmp/gc2/index" ] && sed -i "/x${arr[0]/.xz/}/d" "${spotter_root}/tmp/gc2/index"; echo "x${arr[0]/.xz/}=\"${arr[1]}\"" >>"${spotter_root}/tmp/gc2/index"; }
			fi
		done< <(cat "${listfile}")
	elif [ "${1}" = "remove" ]; then
		while read -r x; do
			i=$((i+1)); arr=(${x}); t=0; until [ ${t} -ge 3 ]; do ${wspot_merger_remove} -y --repo "${remote}" "${cid}" "${arr[0]}" && { n=$((n+1)); break; } || t=$((t+1)); done
		done< <(cat "${listfile}")
	fi
	if [ ${i} -ne 0 ] && [ ${i} -eq ${n} ]; then
		echo "finished with no errors."
		echo -n>"${listfile}"
		return 0
	else
		echo "error list is uncomplete"
		return 1
	fi
}


_database_merger_save()
{
	local option output file
	option="${1}"; output="${2:-/sdcard/Download}"
	mkdir -p "${spotter_root}/tmp/share"

		file="wspot-db-$(date +%s).zip"
		tar --xz -cf "${spotter_root}/tmp/share/${file}" -C "${spotter_root}/database" .
	if [ "${option}" = "--backup" ]; then
		cp "${spotter_root}/tmp/share/${file}" "${output}/${file}" && echo "backed-up into: ${output}/${file}" || { echo "backed-up into: ${spotter_root}/tmp/share/${file}"; }
	elif [ "${option}" = "--share" ]; then
		echo "sharing file: ${spotter_root}/tmp/share/${file}"
		echo "starting sharing dialog.."
		termux-open --send "${spotter_root}/tmp/share/${file}"
	fi
}
