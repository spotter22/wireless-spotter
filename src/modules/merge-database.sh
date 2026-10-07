#!/bin/bash


_database_merger_find()
{
	local list ucid index f x y; list="${@}"
	[ -n "${spotter_root}" ] && { readonly spotter_root="${spotter_root}" 2>/dev/null; } || { readonly spotter_root=~/wspot-root 2>/dev/null; }; mkdir -p "${spotter_root}/tmp" || return ${?}
	source "${spotter_root}/modules/spotter.sh" || return ${?}; _spotter_get_config

		echo "searching database inside: ${list}"
	while read -r f; do
			ucid=($(tar -Oxf "${f}" "./.id" 2>/dev/null | sed "s|/| |"))
			([[ "${ucid[0]}" =~ (.*-.*) ]] && [[ ${ucid[1]} -eq ${ucid[1]} ]] 2>/dev/null) && echo "browsing: $(basename ${f})" || continue
		for x in $(tar --exclude="./*/*/*" -tf "${f}" | grep -o "./.*-.*/[0-9][^/]*"); do
			ucid="${x/\.\//}"; ucid="${ucid/\// }"; ucid=(${ucid})
			[ "${cid}" = "${ucid[0]}" ] || { echo "error invalid cid: ${cid}"; continue; }
			index=$(tar -tf "${f}" "${x}" | grep -F ".list" | wc -l)
			echo "${index} entries: $(basename ${x})"
			[ ${index} -ge 1 ] && { _database_merger_apply "${f}" "${x}" || return ${?}; }
		done
	done< <(find "${list}" \( -type f -name "513037856628*.xz" -or -name "wspot-db-*.zip" \) 2>/dev/null)
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


_database_merger_save()
{
	local option output file
	option="${1}"; output="${2:-/sdcard/Download}"
	mkdir -p "${spotter_root}/tmp/share"

		file="wspot-db-$(date +%s).zip"
		tar --xz -cf "${spotter_root}/tmp/share/${file}" -C "${spotter_root}/database" .
	if [ "${option}" = "--backup" ]; then
		echo "backing-up into: ${output}/${file}"
		cp "${spotter_root}/tmp/share/${file}" "${output}/${file}"
	elif [ "${option}" = "--share" ]; then
		echo "starting sharing dialog.."
		termux-open --send "${spotter_root}/tmp/share/${file}"
	fi
}
