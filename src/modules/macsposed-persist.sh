# magisk post script

export ASH_STANDALONE=1


_persist_apply_safely(){

		# Ref: https://serverfault.com/a/631119
		file[0]="/debug_ramdisk/overlayfs_mnt/upper/vendor/nvdata/APCFG/APRDEB/WIFI"
		file[1]="/mnt/vendor/nvdata/APCFG/APRDEB/WIFI"
	if [ -s "${file[0]}" ]; then
		echo "found file[0]: ${file[0]}"
		addr=$(cat "${file[0]}" | dd skip=4 bs=1 count=6 2>/dev/null | od -An -tx1 | sed "s/^ //; s/ /:/g")
	elif [ -s "${file[1]}" ]; then
		echo "found file[1]: ${file[1]}"
		addr=$(cat "${file[1]}" | dd skip=4 bs=1 count=6 2>/dev/null | od -An -tx1 | sed "s/^ //; s/ /:/g")
	else
		echo "failed, no file[0] or file[1] was found."
		return 1
	fi
		rand=$(printf '%02x' $((0x$(od /dev/urandom -N1 -t x1 -An | tr -d ' ') & 0xFE | 0x02)); od /dev/urandom -N5 -t x1 -An | tr ' '  ':')
	if ([ -z "${addr}" ] || [ "${addr}" = "none" ]) || [ -z "${rand}" ]; then
		return 1
	fi

	while true; do
		until ip link show dev wlan0 | grep -qs ",UP"; do
			sleep 10
					done
				until iw dev wlan0 info | grep -qs "${addr}"; do
			sleep 10
		done
		ip link set dev wlan0 down
		ip link set dev wlan0 address "${rand}"
		ip link set dev wlan0 up
	done

	return 0
}

_persist_apply_safely
