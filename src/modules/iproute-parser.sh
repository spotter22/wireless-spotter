#!/bin/bash

#export debug=1
{ _print_verbose(){ [ "${debug}" = "1" ] && echo -e "${@}"; }; } 2>/dev/null
_print_message(){ [ "${debug}" = "1" ] || echo -e "${@}"; }
_iproute2iw_parse_auto()
{
	# route ref: http://www.rjsmith.com/CIDR-Table.html
	route=0; riface=0; devip=0; tgateip=0 # ip r
	gateip=0; niface=0; gaddr=0 # ip n
	iwface=0; iwaddr=0; iwssid=0; iwbssid=0; iwfreq=0
	local iface prefix i x arr stdin rskip nskip tskip table IFS
	if [ -p /dev/stdin ]; then
		stdin="cat"
	elif [ -s "${1}" ]; then
		stdin="cat ${@}"
	else
		[ -z "${1}" ] && iface="wlan0" || iface="${1}"
		[ -z "${2}" ] && prefix="${PREFIX}/bin" || prefix="${2}"
		stdin="eval su -c 'iw dev '${iface}' link; iw dev '${iface}' info; ip r show table all; ip n'"
	fi

		i=0; rskip=0; nskip=0; tskip=0
		_print_message "Getting network information.."
	while read -r x; do
		if [[ "${x}" =~ (Connected to [a-fA-F0-9]{2}:[a-fA-F0-9]{2}:[a-fA-F0-9]{2}:[a-fA-F0-9]{2}:[a-fA-F0-9]{2}:[a-fA-F0-9]{2} \(on) ]]; then
			# iw scan dev wlan0 link
			arr=(${x}); iwbssid="${arr[2]}"; n="${arr[4]/)/}"; iwface="${n}"
			read -r x; [[ "${x}" =~ "SSID:" ]] && iwssid=$(echo -e "${x}" | sed "s/SSID: //") || { echo "error expected: \"SSID:\" but got: \"${x}\""; return 1; }
			read -r x; [[ "${x}" =~ "freq:" ]] && { arr=(${x}); iwfreq="${arr[1]}"; } || { until [[ "${x}" =~ "freq:" ]]; do read -r x; done; arr=(${x}); iwfreq="${arr[1]}"; }
			read -r x; read -r x; read -r x; read -r x; read -r x; continue
		elif [[ "${x}" =~ (Interface [a-z0-9]{4,8}[0-9]$) ]]; then
			# iw dev wlan0 info
			arr=(${x}); iwface="${arr[1]}"
			read -r x; read -r x; read -r x
			arr=(${x}); iwaddr="${arr[1]}"
			read -r x; [[ "${x}" =~ "ssid " ]] && iwssid=$(echo -e "${x}" | sed "s/ssid //")
			read -r x; read -r x; continue
		elif [[ "${x}" =~ (^phy#[0-9]$) ]]; then
			# iw dev
			read -r x
			until [ -z "${x}" ]; do
			 [ -z "${x}" ] && break
			arr=(${x}); iwface[${i}]="${arr[1]}"
			read -r x; read -r x; read -r x
			arr=(${x}); iwaddr[${i}]="${arr[1]}"
			read -r x; [[ "${x}" =~ "ssid " ]] && { iwssid[${i}]=$(echo -e "${x}" | sed "s/ssid //"); read -r x; }
			i=$((i+1)); read -r x; continue
			done
			continue
		elif [ ${tskip} -eq 0 ] && [[ "${x}" =~ (default via [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3} ) ]]; then
			# ip route show table all
			arr=(${x}); tgateip="${arr[2]}"
			if [ "${arr[3]}" = "dev" ]; then
				riface="${arr[4]}"
				table="${arr[6]}"
			elif [ "${arr[3]}" = "table" ]; then
				table="${arr[4]}"
			else
				_print_verbose "_iproute2iw_parse_auto: error expected either dev or table but got: ${x}"
				return 1
			fi
			until ([[ "${x}" =~ (table ${table} .*scope link) ]] && [[ ! "${x}" =~ "${tgateip}" ]]); do read -r x; done
			[[ "${x}" =~ (table ${table} .*scope link) ]] || { _print_verbose "_iproute2iw_parse_auto: error expected table ${table} .*scope link but got: ${x}"; return 1; }
			arr=(${x}); [[ "${arr[0]}" =~ "/" ]] && route="${arr[0]}" || { IFS=$'.'; devip="${arr[0]}"; arr=(${devip}); route="${arr[0]}.${arr[1]}.${arr[2]}.0/16"; IFS=$'\n \t'; }
			if [ "${devip}" = "0" ]; then
				until [[ "${x}" =~ (${route} .* link src) ]]; do read -r x; done
				[[ "${x}" =~ (${route} .* link src) ]] || { _print_verbose "_iproute2iw_parse_auto: error expected ${route} .* link src but got: ${x}"; return 1; }
					arr=(${x})
				if [ "${arr[7]}" = "src" ]; then
					devip="${arr[8]}"
				elif [ "${arr[5]}" = "src" ]; then
					devip="${arr[6]}"
				else
					_print_verbose "_iproute2iw_parse_auto: error expected either dev at 5 or 7 but got: ${x}"
					return 1
				fi
			fi
			tskip=1; continue
		elif [ ${rskip} -eq 0 ] && [[ "${x}" =~ (^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2} dev .*link src ) ]] && [[ ! "${x}" =~ " table " ]]; then
			# ip r
			arr=(${x}); route="${arr[0]}"; riface="${arr[2]}"; devip="${arr[8]}"
			rskip=1; continue
		elif [ ${nskip} -eq 0 ] && [[ "${x}" =~ (^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3} dev .* lladdr ) ]]; then
			# ip n
			arr=(${x}); gateip="${arr[0]}"; niface="${arr[2]}"; gaddr="${arr[4]}"
			nskip=1; continue
			# ip r show table all
		fi
		#echo $x; continue
	done< <(${stdin})
	if [ "${debug}" = "1" ]; then
		declare -p iwface iwaddr iwssid iwbssid iwfreq
		declare -p route riface devip gateip niface gaddr tgateip
	fi
}


_arpscan_parser()
{
	unset ret int
	local iface args option prefix stdin IFS arr x i v len; i=(0 0); int=0
	if [ -p /dev/stdin ]; then
		stdin="cat"
	elif [ -s "${1}" ]; then
		stdin="cat ${@}"
	else
		[ -z "${1}" ] && iface="wlan0" || iface="${1}"
		[ -z "${4}" ] && prefix="${PREFIX}/bin" || prefix="${3}"
		[ -z "${2}" ] && stdin="eval su -c ''${prefix}'/arp-scan -I'${iface}' --localnet'" || { args="${2}"; stdin="eval su -c ''${prefix}'/arp-scan -I'${iface}' '${args}''"; }
		[ -z "${3}" ] && option="1" || option="${3}"
	fi

	_print_message "Scanning network with arp-scan.."
	while read -r x; do
		if [[ "${x}" =~ (Operation not permitted|You don\'t have permission|ERROR: Could not obtain MAC|ioctl failed: Permission denied) ]]; then
			_print_message "Error permission denied."
			_print_verbose "_arpscan_parser: error permission denied: ${x}"
			return 1
		elif [[ "${x}" =~ (Interface:|Starting|packets|Ending|WARNING|which may not|Either configure|with the|No such device exists|ERROR: failed to send packet) ]]; then
			continue
		fi
		[ -n "${x}" ] && { arr=(${x}); i[0]=$((i[0]+1)); } || continue
		[[ "${ret}" =~ "${arr[1]}" ]] && continue
		ret+=" ${arr[1]}"; i[1]=$((i[1]+1)); int=$((int+1)); v="${arr[2]/(/}"; v="${v/)/}"; v="${v/:/}"
		if [ "${option}" = "1" ]; then
			[ ${i[1]} -eq 1 ] && { echo "--------------------------------------------------"; echo "IPv4:           Address:              Vendor:"; }
			IFS=$'.'; len=(${arr[0]}); len="${len[3]}"; len="${#len}"; IFS=$' \t\n'
			[ ${len} -eq 1 ] && len="     " || { [ ${len} -eq 2 ] && len="    " || { [ ${len} -eq 3 ] && len="   "; }; }
			echo -e " ${arr[0]}${len}${arr[1]}${len}${v}"
		fi
	done< <(${stdin} 2>&1)
	([ "${option}" = "1" ] && [ ${i[1]} -ne 0 ]) && { echo "--------------------------------------------------"; err=0; } || err=1
	echo "Finished, ${i[1]} devices found."
	return ${err}
}


_ipv6neighbor_parser(){
	unset ret int
	local iface seconds option prefix stdin IFS list err ip addr len x i
	if [ -p /dev/stdin ]; then
		stdin="cat"
	elif [ -s "${1}" ]; then
		stdin="cat ${@}"
	else
		[ -z "${1}" ] && iface="wlan0" || iface="${1}"
		[ -z "${2}" ] && option="1" || option="${2}"
		[ -z "${3}" ] && seconds="3" || seconds="${3}"
		[ -z "${4}" ] && prefix="${PREFIX}/bin" || prefix="${4}"
		stdin="eval su -c ''${prefix}'/timeout -k'${seconds}' '${seconds}' '${prefix}'/ping6 ff02::01%'${iface}''"
	fi

	# implemention: https://stackoverflow.com/a/37316533
	_ip2mac(){
			mac=0; local list arr x y z u
		for x in ${@}; do
			[ "${1:0:6}" = "fe80::" ] || continue
			y="${x}"; y="${y/\/*/}"; y="${y//:/ }"
			for z in ${y:4}; do while [ "${#z}" -lt 4 ]; do z="0${z}"; done; u+=" ${z:0: -2}"; u+=" ${z:2}"; done
			arr=(${u}); arr[0]=$(printf "%02x" $((0x${arr[0]} ^ 2)))
			unset arr[3]; unset arr[4]; mac="${arr[@]}"; mac="${mac// /:}"
		done
		return 0
	}

	_mac2ip(){
			ip=0; local arr x y z
		for x in ${@}; do
			x="${x//:/ }"; arr=(${x}); arr[2]+=" ff"; arr[2]+=" fe"; arr[0]=$(printf "%x" $((0x${arr[0]} ^ 2)))
			for y in ${arr[@]}; do [ -z "${z}" ] && { z="${y}"; continue; }; ip+="${z}${y}:"; unset z; done
			ip="${ip:0: -1}"; ip="${ip:1}"; ip="fe80::${ip}"
		done
		return 0
	}

	[ "${iwaddr}" = "0" ] || { _mac2ip "${iwaddr}"; list="${ip}"; }

		_print_message "Scanning network with IPv6-neighbor.."
		i=0; err=0; int=0
	while read -r x; do
		[[ "${x}" =~ (unreachable) ]] && { err=1; break; }
		([ -z "${x}" ] || [[ "${x}" =~ (data|statistics|\.) ]] || [ ${#x} -le 15 ]) && continue
		ip="${x:0: -1}"; [[ "${list}" =~ "${ip}" ]] && continue || list+=" ${ip}"
		_ip2mac "${ip}" && { ret+=" ${mac}"; i=$((i+1)); int=$((int+1)); } || continue
		if [ "${option}" = "1" ]; then
				[ ${i} -eq 1 ] && { echo "--------------------------------------------------"; echo "IPv6:                       Address:"; }
			if [ ${#ip} -eq 25 ]; then
				len="   "
			elif [ ${#ip} -eq 24 ]; then
				len="    "
			elif [ ${#ip} -eq 22 ]; then
				len="      "
			elif [ ${#ip} -eq 21 ]; then
				len="       "
			fi
			echo " ${ip}${len}${mac}"
		fi
	done< <(${stdin} 2>&1 | stdbuf -oL awk '{print $4}')
	([ "${option}" = "1" ] && [ ${i} -ne 0 ]) && echo "--------------------------------------------------"
	echo "Finished, ${i} devices found."
	return ${err}
}

