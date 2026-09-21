#!/bin/bash


_database_merger_find()
{
	local list ucid index f x y; list="${@}"
	[ -n "${spotter_root}" ] && { readonly spotter_root="${spotter_root}" 2>/dev/null; } || { readonly spotter_root=~/wspot-root 2>/dev/null; }; mkdir -p "${spotter_root}/tmp" || return ${?}
	source "${spotter_root}/modules/spotter.sh" || return ${?}; _spotter_get_config

		echo "searching database inside: ${list}"
	while read -r f; do
			ucid=($(tar -Oxf "${f}" "./.id" 2>/dev/null | sed "s|/| |"))
			[ -n "${ucid}" ] && index=$(tar -tf "${f}" "./${ucid[0]}/${ucid[1]}" | grep -F ".list" | wc -l) || index=0
		if [ ${index} -ge 1 ]; then
			echo "${index} entries inside: $(basename ${f})"
			[ "${cid}" = "${ucid[0]}" ] || { echo "error invalid cid: ${cid}"; continue; }
			_database_merger_apply "${f}" || return ${?}
		fi
	done< <(find "${list}" -type f \( -name "*.xz" -or -name "wspot-db-*.zip" \) 2>/dev/null)
}


_database_merger_apply()
{
	local db result new user list x i e; db="${1}"; i=(0 0); e=(0 0)
	[ -e "${spotter_root}/tmp/merge" ] && rm -r "${spotter_root}/tmp/merge"; mkdir -p "${spotter_root}/tmp/merge"
	tar -xvf "${db}" -C "${spotter_root}/tmp/merge" | sed "s|^./${ucid[0]}/${ucid[1]}/||g" | grep -Ev "\.id|.info" >"${spotter_root}/tmp/merge/list"

	while read -r x; do
			new="${spotter_root}/tmp/merge/${ucid[0]}/${ucid[1]}/${x}"
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
	echo -e "records added: ${i[0]}\nrecords merged: ${i[1]}\nrecords matched: ${e[0]}"
}


_database_merger_save()
{
	local option output file
	option="${1}"; output="${2:-/sdcard/Download}"
	mkdir -p "${spotter_root}/tmp/share"

		file="wspot-db-$(date +%s).zip"
		tar -J --xz -cf "${spotter_root}/tmp/share/${file}" -C "${spotter_root}/database" .
	if [ "${option}" = "--backup" ]; then
		echo "backing-up into: ${output}/${file}"
		cp "${spotter_root}/tmp/share/${file}" "${output}/${file}"
	elif [ "${option}" = "--share" ]; then
		echo "starting sharing dialog.."
		termux-open --send "${spotter_root}/tmp/share/${file}"
	fi
}
