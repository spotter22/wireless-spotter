#!/bin/bash

#export debug=1
#export mdebug=1
_spotter_main_usage(){
	cat <<EOF
Usage: wireless-spotter <option> <value>
Main options:
-i <string>
  Set interface for all operations.

-w <intger>
  Search and record available Wi-Fi networks
   with their releated network information.
   Options:
    1 = search and record for one session.
    2 = search and record infinite session.

-m <intger>
  Mointor ARP traffic or IPv6-Neighbor in network.
   Options:
    1 = mointor captive-portal logins
    2 = mointor arp traffic
    3 = ipv6-neighbor-discovery 

-s <intger>
  Scan with unsolicited-ARP or IPv6-Neighbor.
   Options:
    1 = arp-scan with default route
    2 = arp-scan with portal route
    3 = ipv6-neighbor-discovery

-x <intger>
  Run selected exploit
   Options:
    1 = bruteforce clients

-d <string>
  Backup, restore or share your database.
   Options:
    measure = measure database
    backup = backup database
    restore = restore database
    share = share database

-a <string>
  Advance options, target, reset or keep Wi-Fi.
   Options:
    set-addr = Set assigned MAC address
     and reconnect-wifi. Must add equals symbol
     right after set-addr option. The assignable
     value must be <string> and matches either
     <random> or <AB:CD:EF:12:34:56>.

    auto-macsposed = Helps to prevent power saver
     from killing MACSposed by disabling it.
     If any error occurred during checks MACSposed
     will be enabled again. This option requires
     device to be connected into any Wi-Fi network
     for performing tests otherwise it's will fail.

    select-wifi = List available Wi-Fi networks and
     connect into seleted one.

    reconnect-wifi = Reconnect into current Wi-Fi.

    target-open-wifi = Scan for available Wi-Fi
     networks until a open Wi-Fi with free internet
     access is found.

    target-wifi = Scan for available Wi-Fi networks
     until target Wi-Fi is found. Must add equals
     symbol after target-wifi option. The assignable
     value must be <string> and matches either
     <Network name> or <BSSID>.

    reset-wifi = Reset Wi-Fi interface by removing
     saved networks with open security and removing
     the cookies of captive-portal apps.

    keep-selected-wifi = Keeps connection of selected
     Wi-Fi network. helps in preventing sudden
     disconnect when you are away from your device.

Maintain options:
-v, Show version information.
-u, Update to latest version

EOF
}


_sprint_message(){
	echo -e "${@}"
}

_speak_message(){
	espeak -s110 "${@//[$'📶📡🚀']/}"
}

_notify_message(){
	if [ "${1}" = "failed" ]; then
		play-audio "${spotter_root}/sfx/notification_error.m4a" &
	elif [[ "${1}" =~ (completed|checkmate|dominate|empty) ]]; then
		play-audio "${spotter_root}/sfx/notification_done.m4a" &

		if [ "${1}" = "checkmate" ]; then
			{ sleep 1; play-audio "${spotter_root}/sfx/notification_condition2.m4a"; } &
		elif [ "${1}" = "dominate" ]; then
			{ sleep 1; play-audio "${spotter_root}/sfx/notification_condition1.m4a"; } &
		elif [ "${1}" = "empty" ]; then
			{ sleep 1; play-audio "${spotter_root}/sfx/notification_condition0.m4a"; } &
		fi
	fi
}

_spotter_main_config(){
	local version commit mode option src err x p
	[ -n "${spotter_root}" ] && { readonly spotter_root="${spotter_root}"; } || { readonly spotter_root=~/wspot-root; }; mkdir -p "${spotter_root}/tmp" || return ${?}
	[ "${mdebug}" = "1" ] && src="./src" || src="${spotter_root}"
	[ -n "${iface}" ] || iface="wlan0"
	version="debug"
	commit="debug"

	while getopts i:w:m:s:x:d:a:huv p; do
		case "${p}" in
			i) iface="${OPTARG}";;
			w) mode="wireless"; option="${OPTARG}"; break;;
			m) mode"monitor"; option="${OPTARG}"; break;;
			s) mode="scan"; option="${OPTARG}"; break;;
			d) mode="database"; option="${OPTARG}"; break;;
			x) mode="exploit"; option="${OPTARG}"; break;;
			a) mode="advance"; option="${OPTARG}"; break;;
			h) mode="usage"; break;;
			u) mode="update"; break;;
			v) mode="version"; break;;
			*) unset mode option; break;;
		esac
	done

	if [ -z "${mode}" ] && [ -z "${option}" ]; then
		_sprint_message "See help manual: -h"
		return 1
	elif [ "${mode}" = "version" ]; then
		_sprint_message "wspot-${version}-${commit}"
		return 0
	elif [ "${mode}" = "usage" ]; then
		_spotter_main_usage
		return 0
	elif [ $(id -u) -eq 0 ]; then
		_sprint_message "Error, running with sudo is not allowed."
		return 1
	elif [ "${mode}" = "update" ]; then
		${src}/modules/updater.sh --install-latest || return ${?}
		return 0
	elif [ -s "${src}/modules/updater.sh" ]; then
		${src}/modules/updater.sh --update-install && return 0
	fi

	# logs
	echo -e "\n\n\n$(date)" >>"${spotter_root}/tmp/wspot.log"
	_print_verbose(){ echo "${@}" >>"${spotter_root}/tmp/wspot.log"; }
	readonly -f _print_verbose

	_sprint_message "Loading modules.."
	source "${src}/modules/connection-status.sh" || return ${?}
	source "${src}/modules/merge-database.sh" || return ${?}
	source "${src}/modules/iproute-parser.sh" || return ${?}
	source "${src}/modules/302-parser.sh" || return ${?}
	source "${src}/modules/spotter.sh" || return ${?}
	_spotter_get_config

	if [ "${mode}" = "wireless" ]; then
		_spotter_main_spotwifi ${option}
	elif [ "${mode}" = "mointor" ]; then
		_sprint_message "not implemented yet"
	elif [ "${mode}" = "scan" ]; then
		_spotter_main_getwifi "scan-select" || return ${?}
		_spotter_main_getinfo || { err=${?}; [ ${err} -eq 4 ] || return ${err}; }
		_spotter_main_scanwifi "${option}" || return ${?}
	elif [ "${mode}" = "exploit" ]; then
		_spotter_main_exploit "${option}"
	elif [ "${mode}" = "database" ]; then
		_spotter_main_optdb "${option}"
	elif [ "${mode}" = "advance" ]; then
		_spotter_main_optadvance "${option}"
	fi
			[ -s "${spotter_root}/tmp/reporter.pid" ] && kill -9 "$(cat "${spotter_root}/tmp/reporter.pid")" 2>/dev/null
			nohup "${src}/modules/reporter.sh" &>>"${spotter_root}/tmp/reporter.log" &
			echo ${!}>"${spotter_root}/tmp/reporter.pid"; disown
			return 0
}


_spotter_main_optdb(){
	local option; option="${1}"; option="${option:0:1}"; option="${option,,}"

	if [ "${option}" = "m" ]; then
		_spotter_return_db_measure
		_sprint_message "Networks: ${ret[0]}\nUsers: ${ret[1]}\nInactive: ${ret[2]}\nReserved: ${ret[3]}"
	elif [ "${option}" = "b" ]; then
		_database_merger_save "--backup"
	elif [ "${option}" = "r" ]; then
		_database_merger_find "/sdcard/Download"
	elif [ "${option}" = "s" ]; then
		_database_merger_save "--share"
	fi
}


_spotter_main_optadvance(){
	local option err x i; option="${1}"

	if [[ "${option}" =~ "set-addr" ]]; then
		[[ "${option,,}" =~ (set-addr=r) ]] && option="--random" || option="${option/set-addr=/}"
		_connection_interface_reconnect "1" "${spotter_root}/tmp/disconnect.state" "${spotter_root}/tmp/setaddr.state" "${option}"
	elif [[ "${option}" =~ "auto-macsposed" ]]; then
		_connection_interface_reconnect "1" "${spotter_root}/tmp/disconnect.state" "${spotter_root}/tmp/setaddr.state" "--random"; err=${?}
		([ ${err} -eq 4 ] || [ ${err} -eq 11 ]) && { _sprint_message "Failed, status code is ${err}"; return ${err}; }
		_iproute2iw_parse_auto "${iface}" || return ${?}
		[ "${ret}" = "${iwaddr}" ] && sudo pm disable "com.berdik.macsposed" || { sudo pm enable "com.berdik.macsposed"; }
	elif [[ "${option}" =~ "select-wifi" ]]; then
		_spotter_main_getwifi "scan-select" || return ${?}
	elif [ "${option}" = "reconnect-wifi" ]; then
		_connection_interface_reconnect "0" "${spotter_root}/tmp/disconnect.state"
	elif [ "${option}" = "target-open-wifi" ]; then
		_spotter_main_targetwifi "${option}"
	elif [[ "${option}" =~ "target-wifi" ]]; then
		_spotter_main_targetwifi "${option}"
	elif [ "${option}" = "reset-wifi" ]; then
		_connection_interface_reset
	elif [ "${option}" = "keep-selected-wifi" ]; then
		_spotter_main_getwifi "scan-select" || return ${?}
		_iproute2iw_parse_auto "${iface}" || return ${?}
		while read -r x; do
			echo "${x}"
			if [[ "${x}" =~ "Network is unreachable" ]]; then
			i=$((i+1))
			if [ ${i} -eq 1 ]; then
			echo "Dropping once is fine, continuing.."
			sleep 1
			elif [ ${i} -eq 2 ]; then
			echo "This smells bad, but I will continue.."
			sleep 1
			elif [ ${i} -eq 3 ]; then
			echo "hey, I will not accept that anymore.."
			until (_connection_interface_connect "${ssid}" "${sec}"); do sleep 1; done
			i=0
			fi
			fi
		done< <(ping "${gateip}" 2>&1)
	fi
}


_spotter_main_targetwifi(){
	local option target list err x i; option="${1}"

	if [ "${option}" = "target-open-wifi" ]; then
		option=1
	elif [[ "${option}" =~ "target-wifi" ]]; then
		[ "${option}" = "target-wifi" ] && { _sprint_message "Error, incorrect syntax you passed \"target-wifi\" but correct syntax is \"target-wifi=STRING\""; return 1; }
		target="${option/target-wifi=/}"
		[ -n "${target}" ] || { _sprint_message "Error, invalid value you passed \"target-wifi=NULL\" but correct option is \"target-wifi=STRING\""; return 1; }
		option=2
	else
		return 1
	fi

		i=1
	while true; do
			[ ${option} -eq 2 ] && _sprint_message "--------------------------------------------------\nSearching for a Wi-Fi that matches: ${target}\nCurrent scan attempt: ${i}\nTime: $(date "+%c")\n--------------------------------------------------"
			[ ${option} -eq 1 ] && _sprint_message "--------------------------------------------------\nSearching for a Wi-Fi with free internet access..\nCurrent scan attempt: ${i}\nTime: $(date "+%c")\n--------------------------------------------------"
			_spotter_main_getwifi "scan-parse"; err=${?}
			[ ${err} -eq 0 ] && i=$((i+1)) || { [ ${err} -eq 3 ] && { _notify_message "failed"; return ${err}; } || { sleep 0.5; continue; }; }
		for x in ${array_index[@]}; do
			ssid="${array_ssid[${x}]}"; bssid="${array_addr[${x}]}"; sec="${array_sec[${x}]}"
			[[ "${list}" =~ "${bssid}" ]] && { _sprint_message "Skipping: ${ssid}"; continue; }
			[ ${option} -eq 1 ] && _spotter_return_gid_status "${bssid}" && { _sprint_message "Skipping captive-portal network: ${ssid}"; list+=" ${bssid}"; continue; }
			[ ${option} -eq 2 ] && { ([[ "${ssid,,}" =~ "${target,,}" ]] || [ "${bssid}" = "${target}" ]) && { _sprint_message "Succeed, Target \"${target}\" matches \"SSID=${ssid}\" or \"BSSID=${bssid}\"."; _notify_message "completed"; return 0; }; continue; }
			_connection_interface_disconnect "${spotter_root}/tmp/disconnect.state"
			until _connection_interface_connect "${ssid}" "${sec}" || { err=${?}; [ ${err} -eq 12 ] && list+=" ${bssid}" && break; }; do _connection_interface_state "status" && _speak_message "signal strength is ${sig}%... get closer to... ${ssid}" || { err=${?}; _notify_message "failed"; return ${err}; }; done
			[ ${err} -eq 12 ] && continue
			_spotter_main_getinfo || { err=${?}; [ ${err} -eq 4 ] && { _sprint_message "Succeed, \"SSID=${ssid}\" \"BSSID=${bssid}\" has free internet access."; _notify_message "completed"; return 0; }; continue; }
			_spotter_main_scanwifi "3" "0" || continue
			list+=" ${bssid}"
		done
		sleep 3
	done
}


_spotter_main_scanwifi(){
	local rate

	if [ "${1}" = "1" ]; then
		_arpscan_parser "${iface}" "${route}" || return ${?}
	elif [ "${1}" = "2" ]; then
		_arpscan_parser "${iface}" "${host}/16" || return ${?}
	elif [ "${1}" = "3" ]; then
		_ipv6neighbor_parser "${iface}" "${2}" || return ${?}
	else
		return 1
	fi

	if [ ${int} -le 2 ]; then
		rate="empty"
		_notify_message "empty"
	elif [ ${int} -le 20 ]; then
		rate="dominate"
		_notify_message "dominate"
	elif [ ${int} -gt 20 ]; then
		rate="checkmate"
		_notify_message "checkmate"
	else
		return 1
	fi
		_spotter_put_bssid_list "${iwbssid}" "${ret}" || return ${?}
		_spotter_put_bssid_rate "${iwbssid}" "${rate}=${int}"
}



_spotter_main_exploit(){
	local option err x
	[ -z "${1}" ] && exploit="1" || exploit="${1}"

	if [ "${exploit}" = "1" ]; then
		source "${src}/exploits/act2sess2bf"
		_exploit_act2sess2bf && return ${?} || return ${?}
	else
		return 1
	fi
}


_spotter_main_spotwifi(){
	local option list err x i
	[ -z "${1}" ] && option="1" || option="${1}"

		i=0
	while true; do
			([ ${i} -eq ${option} ] && [ ${option} -eq 1 ]) && return 0
			_spotter_main_getwifi "scan-parse"; err=${?}
			[ ${err} -eq 0 ] && i=$((i+1)) || { [ ${err} -eq 3 ] && { _notify_message "failed"; return ${err}; } || { sleep 0.5; continue; }; }
			_sprint_message "--------------------------------------------------\nSession: ${i} | Time: $(date "+%c")\n--------------------------------------------------"
		for x in ${array_index[@]}; do
			ssid="${array_ssid[${x}]}"; bssid="${array_addr[${x}]}"; sec="${array_sec[${x}]}"; sig="${array_sig[${x}]}"
			[ ${option} -eq 2 ] && (_spotter_get_bssid_rate "${bssid}" >/dev/null || [[ "${list}" =~ "${bssid}" ]]) && { _sprint_message "Skipping: ${ssid}"; continue; }
			_connection_interface_disconnect "${spotter_root}/tmp/disconnect.state"
			until _connection_interface_connect "${ssid}" "${sec}" || { err=${?}; [ ${err} -eq 12 ] && list+=" ${bssid}" && break; }; do _connection_interface_state "status" && _speak_message "signal strength is ${sig}%... get closer to... ${ssid}" || { err=${?}; _notify_message "failed"; return ${err}; }; done
			[ ${err} -eq 12 ] && continue
			_spotter_main_getinfo || continue
			_spotter_main_scanwifi "3" "0" || continue
			list+=" ${bssid}"
		done
	done
}


_spotter_main_getwifi(){

	if [ "${1}" = "scan-parse" ]; then
		_connection_interface_iwscan "${iface}" "--scan-parse" "${spotter_root}/tmp/iwscan.log" "${spotter_root}/tmp/iwscan.json" || return ${?}
	elif [ "${1}" = "scan-select" ]; then
		_connection_interface_getinfo || { _connection_interface_iwscan "${iface}" "--scan-select" "${spotter_root}/tmp/iwscan.log" "${spotter_root}/tmp/iwscan.json" && _connection_interface_disconnect "${spotter_root}/tmp/disconnect.state" && _connection_interface_connect "${ssid}" "${sec}" || return ${?}; }
	fi
}


_spotter_main_getinfo(){
	_iproute2iw_parse_auto "${iface}" || return ${?}
	_spotter_get_bssid_info "${iwbssid}" "$(date +%m%d%y)" && return 0 || { _302parser_parse_auto "http://google.com" "${spotter_root}/tmp/response.log"; err=${?}; [ ${err} -eq 0 ] && return ${err} || return ${err}; }
	_spotter_put_bssid_info "${iwbssid}" "${iwssid}" "${iwfreq}" "${sec}" "${gateip}" "${gaddr}" "${route}" "${gid}" "${domain}" "${host}" "${port}" "${status}" "$(date +%m%d%y)"
	_spotter_put_gid_state "${gid}" "state2" "${gaddr}"
}


_spotter_main_config "${@}"
