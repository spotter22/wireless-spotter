


_getlastlog(){
while read -r x; do
	if [[ "${x/??:??:??/}" = "${1}" ]]; then
		until [ -z "${x}" ]; do
			echo "${x}">>"./wspot_${1}.log"
			read -r x
		done
	fi
done< <(cat ~/wspot-root/tmp/wspot.log)
}


d=$(date)
d="${d/??:??:??/}"
#_getlastlog "${d}"

while read -r x; do
	if [ "${x}" = "_connection_interface_reconnect: trying to reconnect with mode: 2" ]; then
			read -r x
		if [[ ! "${x}" =~ "_connection_interface_disconnect: success" ]]; then
			echo "unexpected: ${x}"
			grep -n "${x}" "./wspot_${d}.log"
			exit 1
		fi
	fi
done< <(cat "./wspot_${d}.log")
