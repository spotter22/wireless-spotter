#!/bin/bash

#   Intercepter-NG helper

_usage(){
echo -ne "Usage: ${main} [parameters]
l\tList targets
c\tRemove all targets
h\tAdd hosts automatically
t\tAdd targets automatically
b\tBackup iptables
r\tRestore iptables
"
exit 0
}

		main=$(basename "${0}" | sed s/\.sh//)
		[ -n "${spotter_root}" ] && { readonly spotter_root="${spotter_root}" 2>/dev/null; } || { readonly spotter_root=~/wspot-root 2>/dev/null; }; mkdir -p "${spotter_root}/tmp/cepter" || return ${?}
		cepter_root="${spotter_root}/tmp/cepter"
		cepter_data="/data/data/su.sniff.cepter/files"
	if [ "${1}" = "b" ]; then
		echo "${main}: Backing-up iptables.."
		su -c 'iptables-save >"'${cepter_root}'/iptables.cfg"'
		exit 0
	elif [ "${1}" = "r" ]; then
		echo "${main}: Restoring iptables.."
		su -c 'iptables -F; iptables-restore "'${cepter_root}'/iptables.cfg"'
		exit 0
	fi
	if [ ! -s "${cepter_data}/cepter" ]; then
		echo "$main: Error Intercepter-NG app is not installed."
		exit 1
	else
		owner=$(ls -l "${cepter_data}/cepter" | awk '{print $3}')
		mkdir -p "${spotter_root}"
	fi

	if [ "${1}" = "l" ]; then
		echo "${main}: Listing all entries.."
		cat "${cepter_data}/targets"
	elif [ "${1}" = "c" ]; then
		echo "${main}: Cleaning all entries.."
		echo -n>"${cepter_data}/targets"
	elif [ "${1}" = "h" ]; then
		if [ ! -s "${cepter_root}/host.log" ]; then
			echo "${main}: Error file missing: ${cepter_root}/host.log"
			exit 2
		else
			echo "${main}: Adding from: ${cepter_root}/host.log"
			gw=($(cat "${cepter_root}/host.log"))
			echo "${gw[0]}:${gw[1]}" >"${cepter_data}/hostlist"
			echo -e "${gw[0]} (-)\nUnix }: Unknown [${gw[1]^^}]" >"${cepter_data}/lasthosts.${gw[1]}"
			chown ${owner}:${owner} "${cepter_data}/hostlist"; chmod 660 "${cepter_data}/hostlist"
			chown ${owner}:${owner} "${cepter_data}/lasthosts.${gw[1]}"; chmod 660 "${cepter_data}/lasthosts.${gw[1]}"
		fi
	elif [ "${1}" = "t" ]; then
		if [ ! -s "${cepter_root}/targets.log" ]; then
			echo "${main}: Error file missing: ${cepter_root}/targets.log"
			exit 2
		else
			echo "${main}: Adding from: ${cepter_root}/targets.log"
			cat "${cepter_root}/targets.log" | sed "s/:/-/g; s/ /:/g" >"${cepter_data}/targets"
			chown ${owner}:${owner} "${cepter_data}/targets"; chmod 660 "${cepter_data}/targets"
		fi
	else
		echo "${main}: Incorrect parameter"
		_usage
	fi
	echo "${main}: Completed."
