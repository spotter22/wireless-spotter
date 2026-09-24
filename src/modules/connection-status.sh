#!/bin/bash

#export debug=1
{ _print_verbose(){ [ "${debug}" = "1" ] && echo -e "${@}"; }; } 2>/dev/null
_print_message(){ [ "${debug}" = "1" ] || echo -e "${@}"; }

_connection_interface_iwscan(){
	unset array_index array_ssid array_addr array_freq array_sig array_sec
	index=0; ssid=0; bssid=0; freq=0; sig=0; sec=0
	local iface mode result output prefix x list option err
	local c_reset c_green c_red c_yellow c_cyan

	[ -z "${1}" ] && iface="wlan0" || iface="${1}"
	[ -z "${2}" ] && mode="--scan-parse" || mode="${2}"
	[ -z "${3}" ] && result="./iwscan.log" || result="${3}"
	[ -z "${4}" ] && output="./iwscan.json" || output="${4}"
	[ -z "${5}" ] && prefix="${PREFIX}/bin" || prefix="${5}"
	[[ "${mode}" =~ (--scan-only|--scan-parse|--scan-select) ]] || { _print_verbose "_connection_interface_iwscan: error invalid option: ${mode} allowed options: (--scan-only|--scan-parse|--scan-select)"; return 1; }


	_iwscan_scan(){
		_print_message "Scanning for Wi-Fi networks.."
		_print_verbose "_connection_interface_iwscan: scanning networks.."
		su -c ''${prefix}'/timeout -k10 10 '${prefix}'/iw '${iface}' scan 2>&1' >"${result}"
		[ -s "${result}" ] || { _print_verbose "_connection_interface_iwscan: can not read: ${result} (err: file is empty)"; return 1; }

		while read -r x; do
			[[ "${x}" =~ "command failed: Operation not permitted" ]] && { _print_verbose "_connection_interface_iwscan: error root is required (err: ${x})"; return 2; }
			[[ "${x}" =~ "command failed: Network is down" ]] && { _print_verbose "_connection_interface_iwscan: error wifi is disabled (err: ${x})"; return 3; }
			[[ "${x}" =~ "command failed: Device or resource busy" ]] && { _print_verbose "_connection_interface_iwscan: error device is busy (err: ${x})"; return 4; }
			[[ "${x}" =~ "scan aborted!" ]] && { _print_verbose "_connection_interface_iwscan: error scan is aborted (err: ${x})"; return 5; }
		done< <(cat "${result}")
		return 0
	}
	_iwscan_scan || { err="${?}"; [ ${err} -eq 3 ] && _print_message "Failed, interface is down." || _print_message "Error something is wrong."; return ${err}; }


	_iwscan_parse(){
		_print_verbose "_connection_interface_iwscan: parsing result.."
		echo -e "$(cat "${result}" | sed -e 's#(on wlan# (on wlan#g' | awk '
			BEGIN {
			  printf("[\n")
			}
			NF > 0 {
			  if ($1 == "BSS") {
			    if ($2 ~ /^[a-z0-9:]{17}$/) {
	   		   if (e["MAC"]) {
	   		     printf("{\"mac\":\"%s\",\"ssid\":\"%s\",\"freq\":\"%s\",\"sig\":\"%s\",\"sig%\":\"%s\",\"wpa\":\"%s\",\"wpa2\":\"%s\",\"wep\":\"%s\",\"tkip\":\"%s\",\"ccmp\":\"%s\"},\n",
			          e["MAC"], e["SSID"], e["freq"], e["sig"], e["sig%"], e["WPA"], e["WPA2"], e["WEP"], e["TKIP"], e["CCMP"]);
			      }
	 		     e["MAC"] = $2;
			      e["WPA"] = "n";
			      e["WPA2"] = "n";
			      e["WEP"] = "n";
			      e["TKIP"] = "n";
			      e["CCMP"] = "n";
			      e["LAST"] = "n";
			    }
			  }
			  if ($1 == "SSID:" && e["LAST"] == "n") {
			    e["LAST"] = "y"; e["SSID"] = substr($0, index($0,$2));
			    gsub("\x1e", "0", e["SSID"]);
				gsub("\"", "\\&quot;", e["SSID"]);
				gsub(/'\''/, "\\&squot;", e["SSID"]);
				gsub("\\\\x5c", "\\&bslash;", e["SSID"]);
					  }
			  if ($1 == "freq:") {
			    e["freq"] = $NF;
			  }
			  if ($1 == "signal:") {
			    e["sig"] = $2 " " $3;
			    e["sig%"] = (60 - ((-$2) - 40)) * 100 / 60;
			  }
			  if ($1 == "WPA:") {
			    e["WPA"] = "y";
			  }
			  if ($1 == "RSN:") {
			    e["WPA2"] = "y";
			  }
			  if ($1 == "WEP:") {
			    e["WEP"] = "y";
			  }
			  if ($4 == "CCMP" || $5 == "CCMP") {
			    e["CCMP"] = "y";
			  }
			  if ($4 == "TKIP" || $5 == "TKIP") {
			    e["TKIP"] = "y";
			  }
			}
			END {
			  printf("{\"mac\":\"%s\",\"ssid\":\"%s\",\"freq\":\"%s\",\"sig\":\"%s\",\"sig%\":\"%s\",\"wpa\":\"%s\",\"wpa2\":\"%s\",\"wep\":\"%s\",\"tkip\":\"%s\",\"ccmp\":\"%s\"}\n",
	  		  e["MAC"], e["SSID"], e["freq"], e["sig"], e["sig%"], e["WPA"], e["WPA2"], e["WEP"], e["TKIP"], e["CCMP"]);
			  printf("]\n")
			}')" | tr '\0' '0' >"${output}"
	}
	_iwscan_parse


	if [ "${mode}" = "--scan-only" ]; then
		_print_verbose "_connection_interface_iwscan: scanning finished."
		return 0
	fi

	_iwscan_select(){
		unset array_index array_ssid array_addr array_freq array_sig array_sec
		unset list
		local twpa2 twpa twep IFS arr i n
		local ssid freq sig index
		_print_verbose "_connection_interface_iwscan: parsing arrays.."
		IFS=$'\n'
		array_ssid=($(jq -r '.[].ssid' "${output}"))
		array_addr=($(jq -r '.[].mac' "${output}"))
		array_freq=($(jq -r '.[].freq' "${output}"))
		twpa2=($(jq -r '.[].wpa2' "${output}"))
		twpa=($(jq -r '.[].wpa' "${output}"))
		twep=($(jq -r '.[].wep' "${output}"))

		_checksec(){
			sec=0
			if [ "${twpa2[${arr[1]}]}" = "y" ]; then
				{ sec=wpa2; return 0; }
			elif [ "${twpa[${arr[1]}]}" = "y" ]; then
				{ sec=wpa; return 0; }
			elif [ "${wep[${arr[1]}]}" = "y" ]; then
				{ sec=wep; return 0; }
			else
				{ sec=open; return 0; }
			fi
		}

		c_reset='\033[0m'; c_green='\033[0;92m'; c_red='\033[1;91m'
		c_yellow='\033[1;93m'; c_cyan='\033[1;96m'

			i=0; n=1; IFS=$'\t \n'
		while read x; do
			arr=(${x}); array_sig[${arr[1]}]="${arr[0]}"; array_index[${n}]="${arr[1]}"
			ssid="${array_ssid[${arr[1]}]}"
			freq="${array_freq[${arr[1]}]:0:1}G"
			sig="${arr[0]}"
			_checksec; array_sec[${arr[1]}]="${sec}"
			index="${arr[1]}"
			list+="\n${c_red}${n}${c_reset})@${c_green}${ssid}${c_reset}@${c_cyan}${freq}${c_reset}@${c_green}${sig}%${c_reset}@${c_yellow}${sec}${c_reset}@${c_cyan}${index}${c_reset}"
			i=$((i+1)); n=$((n+1))
		done < <(jq -r 'foreach .[] as $x (0; . + 1; "\($x."sig%" | tonumber | trunc) \(. - 1)")' "${output}" | sort -rn)

		_print_verbose "_connection_interface_iwscan: total networks: ${i}"

		unset _checksec
	}
	_iwscan_select


	if [ "${mode}" = "--scan-parse" ]; then
		_print_verbose "_connection_interface_iwscan: parsing finished."
		return 0
	else
		_show_menu(){
			echo "--------------------------------------------------"
			echo -e "N:@SSID:@G:@FQ:@Sec:@N:${list}" | column -t -s "@"
			echo -e "${c_red}s${c_reset}) ${c_green}Scan again\n${c_reset}${c_red}r${c_reset}) ${c_green}Return back${c_reset}\n${c_red}x${c_reset}) ${c_green}Exit this utility${c_reset}"
			echo "--------------------------------------------------"
		}

			_show_menu
		while true; do
			read -p "Enter the network number:" option
			if [ -z "${option}" ]; then
				echo -e "${c_red}To exit this menu enter:${c_reset} ${c_cyan}x${c_reset}"
				continue
			elif [ "${option,,}" = "x" ]; then
				return 7
			elif [ "${option,,}" = "r" ]; then
				return 6
			elif [ "${option,,}" = "s" ]; then
				_iwscan_scan || { err="${?}"; _print_message "Error something went wrong."; return ${err}; }
				_iwscan_parse; _iwscan_select; _show_menu
			elif [ ${option} -eq ${option} ] 2>/dev/null; then
				index="${array_index[${option}]}"
				[ -n "${index}" ] || { echo -e "${c_red}Error invalid option:${c_reset} ${c_cyan}${option}${c_reset}"; continue; }
				ssid="${array_ssid[${index}]}"
				bssid="${array_addr[${index}]}"
				freq="${array_freq[${index}]}"
				sig="${array_sig[${index}]}"
				sec="${array_sec[${index}]}"
				#echo :$index: $ssid $bssid $freq $sig $sec
				return 0
			else
				echo -e "${c_red}Error invalid option:${c_reset} ${c_cyan}${option}${c_reset}"
				continue
			fi
		done
	fi

	return 0
}


_connection_interface_getpsk(){
	psk=0
	local ssid result pskstore
	[ -z "${1}" ] && unset ssid || ssid="${1}"

	_print_verbose "_connection_interface_getpsk: parsing network psk: ${ssid}"
	pskstore[0]="/data/misc/apexdata/com.android.wifi/WifiConfigStore.xml"
	result=$(su -c 'cat '${pskstore[0]}'')
	([ "${ssid:0:1}" = "\"" ] && [ "${ssid: -1}" = "\"" ]) && { echo rix; ssid="${ssid:1: -1}"; }
	psk=$(echo "${result}" | grep -FB1 "<string name=\"PreSharedKey\">" | sed 's|<string name="SSID">&quot;||g; s|<string name="PreSharedKey">&quot;||g; s|&quot;</string>||g; s|&amp;|&|g; s|'\''|\&squot\;|g; s|\\\\|&bslash;|g; /^--$/d' | grep -A1 "${ssid}" 2>/dev/null | sed -n 2p)

	if [ -n "${psk}" ]; then
		_print_verbose "_connection_interface_getpsk: parsing success (ret: ${psk})."
		return 0
	else
		_print_verbose "_connection_interface_getpsk: error parsing failed (ret: 0)."
		return 12
	fi
}


_connection_interface_getinfo(){
	ssid=0; bssid=0; sec=0
	local iface prefix result
	[ -z "${1}" ] && iface="wlan0" || iface="${1}"
	[ -z "${2}" ] && prefix="${PREFIX}/bin" || prefix="${2}"

	# cannot rely on `cmd wifi status` since it does not allow to parse ssid effecttively.

	result=$(su -c '[ -n "$('${prefix}'/ip n)" ] && { '${prefix}'/iw dev '${iface}' link; '${prefix}'/cmd wifi status; } || echo "ERROR getinfo failed"')

	if [[ "${result}" =~ "ERROR" ]]; then
		_print_verbose "_connection_interface_getinfo: error interface is probably disconnected: ${result}"
		unset ssid bssid sec
		return 4
	fi

	ssid=$(echo -e "${result}" | grep "SSID:" | sed -n 1p | sed "s/.*SSID: //")
	bssid[0]=$(echo "${result}" | grep "Connected to" | sed "s/.*Connected to //; s/ (on ${iface})//")
	bssid[1]=$(echo "${result}" | grep -Po "BSSID: \K[^,]*" | sed -n 1p)
	sec=$(echo "${result}" | grep -Po "Security type: \K[^,]*" | sed -n 1p)

	if ([ -z "${bssid[0]}" ] && [ -z "${bssid[1]}" ]); then
		_print_verbose "_connection_interface_getinfo: error parsing failed result is empty (ret: iw: 0, cmd: 0)."
		return 1
	elif [ "${bssid[0]}" = "${bssid[1]}" ]; then
		_print_verbose "_connection_interface_getinfo: parsing success: ${result}"
	else
		_print_verbose "_connection_interface_getinfo: error connection was lost during parsing (ret: iw: ${bssid[0]} != cmd: ${bssid[1]})."
		return 2
	fi

	[[ "${ssid}" =~ "'" ]] && ssid="${ssid//\'/\&squot;}"
	[[ "${ssid}" =~ '"' ]] && ssid="${ssid//\"/\&quot;}"
	[[ "${ssid}" =~ '\' ]] && ssid="${ssid//\\/\&bslash;}"
	ssid="\"${ssid}\""

	if [ "${sec}" = "0" ]; then
		sec="open"
	elif [ "${sec}" = "1" ]; then
		sec="wep"
	elif [ "${sec}" = "2" ]; then
		sec="wpa2"
	elif [ "${sec}" = "3" ]; then
		sec="wpa3"
	else
		_print_verbose "_connection_interface_getinfo: error unknown security type (ret: ${sec})."
		return 3
	fi
	return 0
}


_connection_interface_reconnect(){
	local mode state state2 addr iface prefix
	[ -z "${1}" ] && mode="0" || mode="${1}"
	[ -z "${2}" ] && state="./disconnect.tmp" || state="${2}"
	[ -z "${3}" ] && state2="./setaddr.tmp" || state2="${3}"
	[ -z "${4}" ] && addr="--random" || addr="${4}"
	[ -z "${5}" ] && iface="wlan0" || iface="${5}"
	[ -z "${6}" ] && prefix="${PREFIX}/bin" || prefix="${6}"

	[ ${mode} -eq 2 ] || { _connection_interface_getinfo "${iface}" "${prefix}"; err=${?}; }
	[ ${mode} -eq 0 ] || { _connection_interface_setaddr "${addr}" "${state2}" || return ${?}; err=${?}; }

	if [ ${err} -eq 0 ] || [ ${mode} -eq 2 ]; then
		_connection_interface_disconnect "${state}" "${iface}" "${prefix}" || return ${?}
		_connection_interface_connect "${ssid}" "${sec}" "3" "${iface}" "${prefix}" || return ${?}
	fi
		return ${err}
}


_connection_interface_connect(){
	local ssid sec tries iface prefix result err
	[ -n "${1}" ] && ssid="${1}" || return 11
	[ -n "${2}" ] && sec="${2}" || return 11
	[ -z "${3}" ] && tries="3" || tries="${3}"
	[ -z "${4}" ] && iface="wlan0" || iface="${4}"
	[ -z "${5}" ] && prefix="${PREFIX}/bin" || prefix="${5}"

	_print_message "Connecting to: ${ssid}"
	_print_verbose "_connection_interface_connect: optimizing passed info ssid: ${ssid} sec: ${sec}"

	[[ "${ssid}" =~ "&squot;" ]] && ssid="${ssid//&squot;/\\\'}"
	[[ "${ssid}" =~ "&quot;" ]] && ssid="${ssid//&quot;/\\\"}"
	[[ "${ssid}" =~ "&bslash;" ]] && ssid="${ssid//&bslash;/\\\\}"
	[[ "${ssid}" =~ " " ]] && ssid="${ssid// /\\ }"
	[[ "${ssid}" =~ "*" ]] && ssid="${ssid//\*/\\*}"
	[[ "${ssid}" =~ "!" ]] && ssid="${ssid//\!/\\!}"
	[[ "${ssid}" =~ "?" ]] && ssid="${ssid//\?/\\?}"
	[[ "${ssid}" =~ ";" ]] && ssid="${ssid//\;/\\;}"
	[[ "${ssid}" =~ ":" ]] && ssid="${ssid//\:/\\:}"
	[[ "${ssid}" =~ "(" ]] && ssid="${ssid//\(/\\(}"
	[[ "${ssid}" =~ ")" ]] && ssid="${ssid//\)/\\)}"
	[[ "${ssid}" =~ "&" ]] && ssid="${ssid//\&/\\&}"
	[[ "${ssid}" =~ "|" ]] && ssid="${ssid//\|/\\|}"
	[[ "${ssid}" =~ "#" ]] && ssid="${ssid//\#/\\#}"
	if [[ "${ssid:0:1}" =~ (\") ]] && [[ "${ssid: -1}" =~ (\") ]]; then
		ssid="${ssid:1:-1}"
	fi

	if [ ${sec} != "open" ]; then
		_connection_interface_getpsk "${ssid}" || { err=${?}; _print_message "Failed, PSK is not found."; return ${err}; }
		sec="${sec} ${psk}"
	fi

	_print_verbose "_connection_interface_connect: using optimized info ssid: ${ssid} sec: ${sec}"

	# android notes:
	# 1. `cmd wifi connect-network` on successful execute it will return either: "Connection initiated" or "null string"
	# and in some devices it will return "autojoin setting skipped" which can indicate disabling autojoin (-d) has failed or
	# autojoin has already been disabled for current reconnecting network.'
	# 2. on some devices after successful execute of `cmd wifi connect-network` will require
	# to sleep for like 3 or 5 seconds until network is connected otherwise executing `cmd wifi connect-network` again
	# will result in canceling previous request which at the end will result in failling to connect into the wifi.
	# 3. before breaking `ip neigh` return should not contain "INCOMPLETE" otherwise this will result in sudden wifi disconnection.
	# 4. after setting new address some devices will disconnect from wifi within few seconds while some other devices will remain
	# connected and this causes connect function to fail. make sure to disconnect before setting new address otherwise connect function can fail.

	# Ref: https://unix.stackexchange.com/a/792827

	result=$(su -c 'local i c t wait; i=0; t=0; until ([ -n "$('${prefix}'/ip n | grep -E "REACHABLE|STALE|DELAY|PROBE|PERMANENT")" ] || [ ${i} -gt '${tries}' ]); do [ "${wait}" = "yes" ] && { c=$((c+1)); [ ${c} -ge 30 ] && wait="no"; t=$((t+1)); sleep 0.1; continue; } || { c=0; }; echo "_connection_interface_connect: connecting into wifi attempt: ${i}"; '${prefix}'/cmd wifi connect-network '${ssid}' '${sec}' -d; wait="yes"; i=$((i+1)); done; [ ${i} -gt '${tries}' ] && echo "ERROR"; echo "finished with: $((t/10)) seconds" 2>&1' | tr '\n' '#')

	if [[ "${result}" =~ (ERROR) ]]; then
		_print_message "Failed, could not connect into network."
		_print_verbose "_connection_interface_connect: error could not connect to network (ret: ${result})."
		return 11
	else
		_print_message "Succeed, connection was made."
		_print_verbose "_connection_interface_connect: success (ret: ${result})."
		return 0
	fi
}


_connection_interface_disconnect(){
	local state iface prefix result err
	[ -z "${1}" ] && state="./disconnect.tmp" || state="${1}"
	[ -z "${2}" ] && iface="wlan0" || iface="${2}"
	[ -z "${3}" ] && prefix="${PREFIX}/bin" || prefix="${3}"

	if [ -s "${state}" ]; then
		method=2
	elif [ -f "${state}" ]; then
		method=1
	elif [ -e "${state}" ]; then
		_print_message "Fatal, something is wrong with state file."
		_print_verbose "_connection_interface_disconnect: unexpected error: file exists but it is directory: state=${state}"
		return 5
	else
		method=0
	fi

	# note: `iw disconnect` will always return success when device is not connected into network,
	# and when device is connected to certain network it's can return either "operation not permitted" or success.

	_disconnect(){
		if [ ${1} -eq 2 ]; then
			result=$(su -c 'local x y; y=$('${prefix}'/iw dev '${iface}' info | grep "ssid" | sed "s/.*ssid //"); [ -z "${y}" ] && exit 0; y=$(echo -e "${y}"); '${prefix}'/cmd wifi list-networks | grep "${y}" | awk '\''{print $1}'\'' | while read x; do echo "_connection_interface_disconnect: removing network with id: ${x}"; '${prefix}'/cmd wifi forget-network ${x} >/dev/null 2>&1; done' | tr '\n' '#')
		elif [ ${1} -eq 1 ]; then
			result=$(su -c 'local i; i=0; until ([ -z "$('${prefix}'/ip n)" ] || [ ${i} -ge 10 ]); do i=$((i+1)); echo "_connection_interface_disconnect: disconnecting from wifi attempt: ${i}"; '${prefix}'/iw dev '${iface}' disconnect; done; [ ${i} -ge 10 ] && echo "ERROR" 2>&1' | tr '\n' '#')
		fi
		if [[ "${result}" =~ "No such device" ]]; then
			_print_verbose "_connection_interface_disconnect: error invalid interface: ${iface} (ret: ${result})."
			return 24
		elif [[ "${result}" =~ "Network is down" ]]; then
			_print_verbose "_connection_interface_disconnect: error interface is down (ret: ${result})."
			return 23
		elif [[ "${result}" =~ "operation not permitted" ]]; then
			_print_verbose "_connection_interface_disconnect: error disconnect failed (ret: ${result})."
			return 22
		elif [[ "${result}" =~ "ERROR" ]]; then
			_print_verbose "_connection_interface_disconnect: error disconnect failed (ret: ${result})."
			return 21
		else
			_print_verbose "_connection_interface_disconnect: success (ret: ${result})."
			return 0
		fi
	}

	if [ ${method} -eq 2 ]; then
		_disconnect "2" && return 0
		mv "${state}" "$(mktemp)"
	elif [ ${method} -eq 1 ]; then
		_disconnect "1" && return 0
		mv "${state}" "$(mktemp)"
	elif [ ${method} -eq 0 ]; then
		_print_message "Testing, disconnect compatibility.."
		_print_verbose "_connection_interface_disconnect: testing disconnect.."
		_disconnect "1"; err=${?}
		[ ${err} -eq 23 ] && { _print_message "Error, disconnect failed interface is down."; return ${err}; }
		[ ${err} -eq 22 ] && { echo >"${state}"; _disconnect "2"; return 0; }
		[ ${err} -eq 0 ] && { echo -n>"${state}"; return 0; }
		_print_message "Fatal, disconnect status code: ${err}"
		return ${err}
	fi

}


_connection_interface_state(){
	ret=0
	local mode iface prefix result
	[ -z "${1}" ] && mode="up" || mode="${1}"
	[ -z "${2}" ] && iface="wlan0" || iface="${2}"
	[ -z "${3}" ] && prefix="${PREFIX}/bin" || prefix="${3}"

	if [[ "${mode}" =~ (up|down) ]]; then
		if [ "${mode}" = "down" ]; then
			result=$(su -c 'local i; i=0; until ([ -z "$('${prefix}'/ip link show dev '${iface}' | grep -F "UP")" ] || [ ${i} -ge 3 ]); do i=$((i+1)); echo "_connection_interface_state: setting interface down attempt: ${i}"; '${prefix}'/ip link set dev '${iface}' down; done; [ ${i} -ge 3 ] && echo "ERROR" 2>&1' | tr '\n' '#')
		elif [ "${mode}" = "up" ]; then
			result=$(su -c 'local i; i=0; until ([ -n "$('${prefix}'/ip link show dev '${iface}' | grep -F "UP")" ] || [ ${i} -ge 3 ]); do i=$((i+1)); echo "_connection_interface_state: setting interface up attempt: ${i}"; '${prefix}'/ip link set dev '${iface}' up; done; [ ${i} -ge 3 ] && echo "ERROR" 2>&1' | tr '\n' '#')
		fi

		if [[ "${result}" =~ "ERROR" ]]; then
			_print_verbose "_connection_interface_state: error could not set ${mode} interface ${iface} (ret: ${result})."
			return 1
		fi

	elif [[ "${mode}" =~ (enable|disable) ]]; then
		if [ "${mode}" = "disable" ]; then
			result=$(su -c 'echo "_connection_interface_state: disabling interface.."; '${prefix}'/cmd wifi set-wifi-enabled disabled || svc wifi disable')
		elif [ "${mode}" = "enable" ]; then
			result=$(su -c 'echo "_connection_interface_state: enabling interface.."; '${prefix}'/cmd wifi set-wifi-enabled enabled || svc wifi enable')
		fi

	elif [[ "${mode}" =~ (status) ]]; then
			result=$(su -c 'echo "_connection_interface_state: getting interface status.."; '${prefix}'/cmd wifi status')
		if [[ "${result}" =~ "Wifi is enabled" ]]; then
			return 0
		elif [[ "${result}" =~ "Wifi is disabled" ]]; then
			return 3
		fi
	else
		_print_verbose "_connection_interface_state: error unknown mode is passed (mode: null)."
		return 2
	fi


	_print_verbose "${result}"
	return 0
}


_connection_interface_reset()
{
	local option props
	[ -n "${1}" ] && option="${1}" || option="2"
	[ -s "${2}" ] && props=$(realpath "${2}") || props="0"

	su -c 'local list i x y z; for x in $(echo "pm list packages" | su - | grep -F "captiveportallogin" | sed "s/package://g" | tr "\n" " "); do echo "Clearing cookies: ${x}"; echo "pm clear ${x}" | su - >/dev/null 2>&1 || echo "Failed, clearing cookies: ${x}"; done; [ -s '${props}' ] && { '${props}' >/dev/null; echo "Props-Spoofer: ${?}"; }; [ '${option}' = "1" ] && exit 0; i=0; list="$(echo "cmd wifi list-networks" | su - | grep -F "open" | awk '\''{print $1}'\'' | tr "\n" " ") EOF"; for x in ${list}; do i=$((i+1)); [ "${x}" != "EOF" ] && { y+=" ${x}"; z+="cmd wifi forget-network ${x}; "; }; ([ ${i} -ge 10 ] || [ "${x}" = "EOF" ]) && { [ -z "${y}" ] && continue; echo "Removing networks: ${y}"; unset y; i=0; echo "${z}" | su - >/dev/null; } || { continue; }; done'
}


_connection_interface_setaddr(){
	ret=0; PREV_ADDR="${PREV_ADDR:-0}"
	local addr state iface prefix method result err
	[ -z "${1}" ] && addr="--random" || addr="${1}"
	[ -z "${2}" ] && state="./setaddr.tmp" || state="${2}"
	[ -z "${3}" ] && iface="wlan0" || iface="${3}"
	[ -z "${4}" ] && prefix="${PREFIX}/bin" || prefix="${4}"

	if [ -x "${state}" ] && [[ "${addr:0:2}" =~ (1|3|5|7|9|B|D|F) ]]; then
		_print_message "Warning, address begins with odd chars."
		_print_verbose "_connection_interface_setaddr: warning interface does not allow setting address begins with odd chars: ${addr}"
		return 5
	elif [ -s "${state}" ]; then
		method=2
	elif [ -f "${state}" ]; then
		method=1
	elif [ -e "${state}" ]; then
		_print_message "Fatal, something is wrong with state file."
		_print_verbose "_connection_interface_setaddr: unexpected error: file exists but it is directory: state=${state}"
		return 6
	else
		method=0
	fi

	_setaddr(){
		if [ "${1}" = "--random" ]; then
			result=($(su -c ''${prefix}'/macchanger -r '${iface}' 2>&1 | '${prefix}'/sed "s|([^)]*)||g" 2>&1'))
		else
			result=($(su -c ''${prefix}'/macchanger -m '${1}' '${iface}' 2>&1 | '${prefix}'/sed "s|([^)]*)||g" 2>&1'))
		fi

			# 2, 5, 8
		if [[ "${result[@]}" =~ "Usage:" ]]; then
			_print_verbose "_connection_interface_setaddr: error failed setting address begins with odd char: ${2} (ret: ${result[@]})."
			return 5
		elif [[ "${result[@]}" =~ "No such device" ]]; then
			_print_message "Failed, interface is down."
			_print_verbose "_connection_interface_setaddr: error interface is down: ${2} (ret: ${result[@]})."
			return 4
		elif [[ "${result[@]}" =~ (Permission denied|insufficient permissions) ]]; then
			_print_verbose "_connection_interface_setaddr: error setting address failed: ${2} (ret: ${result[@]})."
			return 3
		elif [[ ! "${result[2]}" =~ "${PREV_ADDR}" ]] && [ "${PREV_ADDR}" != "0" ]; then
			_print_message "Failed, MACsposed is disabled."
			_print_verbose "_connection_interface_setaddr: error previous address not equals current address (most likely macchnager failed setting addr): (prev_addr=${PREV_ADDR} ret: ${result[@]})."
			return 2
		elif [[ "${result[@]}" =~ "ERROR" ]]; then
			_print_verbose "_connection_interface_setaddr: unexpected error could not set address: ${2} (ret: ${result[@]})."
			return 1
		elif [[ "${result[@]}" =~ "the same MAC" ]]; then
			ret="${result[8]}"; PREV_ADDR="${ret}"
			_print_message "Succeed, address ${ret} was set."
			return 0
		else
			ret="${result[8]}"; PREV_ADDR="${ret}"
			[ "${1}" = "--random" ] && _print_message "New random address: ${ret}" || _print_message "Succeed, address ${ret} was set."
			_print_verbose "_connection_interface_setaddr: success (ret: ${result[@]})."
			return 0
		fi
	}

	_down(){
		_connection_interface_state "down" "${iface}" "${prefix}" || return ${?}
	}
	_up(){
		_connection_interface_state "up" "${iface}" "${prefix}" || return ${?}
	}

	_validate_odd_addr(){
		[[ "${addr:0:2}" =~ (1|3|5|7|9|B|D|F) ]] && return 0 || return 1
	}


	if [ ${method} -eq 2 ]; then
		_down; _setaddr "${addr}"; err=${?}; _up
		[ ${err} -eq 0 ] && return 0
		[ ${err} -eq 4 ] && return 4
		[ ${err} -eq 2 ] && return 2
		mv "${state}" "$(mktemp)"
		return ${?}
	elif [ ${method} -eq 1 ]; then
		_setaddr "${addr}"; err=${?}
		[ ${err} -eq 0 ] && return 0
		[ ${err} -eq 4 ] && return 4
		[ ${err} -eq 2 ] && return 2
		mv "${state}" "$(mktemp)"
		return ${?}
	elif [ ${method} -eq 0 ]; then
		_print_message "Testing, interface compatibility.."
		_print_verbose "_connection_interface_setaddr: testing interface.."
		_setaddr "11:11:11:11:11:11"; err=${?}
		if [ ${err} -eq 0 ]; then
			echo -n>"${state}"
			_setaddr "${addr}"
			return 0
		elif [ ${err} -eq 5 ]; then
			_validate_odd_addr && { _setaddr "${addr}"; echo -n>"${state}"; chmod +x "${state}"; return 0; }
			_print_message "Fatal, status code is 5."
			_print_verbose "_connection_interface_setaddr: unexpected status code: 5"
			return 5
		elif [ ${err} -eq 4 ]; then
			return 4
		elif [ ${err} -eq 3 ]; then
			_down
			_setaddr "11:11:11:11:11:11"; err=${?}
			_up
			[ ${err} -eq 0 ] && echo >"${state}" && return 0
			[ ${err} -eq 5 ] && _validate_odd_addr && echo >"${state}" && chmod +x "${state}" && return 0
 			_print_message "Fatal, status code is 2."
 			return 3
		else
			_print_message "Fatal, status code is ${err}."
			return ${err}
		fi
	fi

	return 0
}
