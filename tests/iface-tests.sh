

	export debug=1
if [ -s "./src/modules/connection-status.sh" ]; then
	source "./src/modules/connection-status.sh"
	tmp="./tmp"
elif [ -s "../src/modules/connection-status.sh" ]; then
	source "../src/modules/connection-status.sh"
	tmp="../tmp"
else
	echo "error cannot find: connection-status.sh"
	exit 1
fi
	statefile_disconnect="${tmp}/disconnect.state"
	statefile_setaddr="${tmp}/setaddr.state"
	mkdir -p "${tmp}"

_print_msg(){ echo -e "\033[0;93m${@}\033[0m"; }
_print_done(){ echo -e "\033[0;92m${@}\033[0m"; }
_print_error(){ echo -e "\033[1;91m${@}\033[0m"; }
_perform_test(){
	_print_msg "testing condition: ${1}"
	unset PREV_ADDR; rm "${statefile_disconnect}" "${statefile_setaddr}" 2>/dev/null
	export disconnect_error_msg="${2}"
	export setaddr_error_msg="${3}"
	export setaddr_error_msg2="${4}"
	_connection_interface_disconnect "${statefile_disconnect}"
	_connection_interface_setaddr "--random" "${statefile_setaddr}"
}

_confirm_test(){
	local err e; err=0
	for e in ${@/[0-9]/}; do
	echo "checking: ${e}"
	if [[ "${e}" =~ "set-not-empty" ]] && \
		[ ! -s "${statefile_setaddr}" ]; then
		echo "setaddr: error file is empty"
		err=$((err+1))
	fi
	if [[ "${e}" =~ "set-is-empty" ]] && \
		[ -s "${statefile_setaddr}" ]; then
		echo "setaddr: error file not empty"
		err=$((err+1))
	fi
	if [[ "${e}" =~ "set-not-exe" ]] && \
		[ -x "${statefile_setaddr}" ]; then
		echo "setaddr: error file is exe"
		err=$((err+1))
	fi
	if [[ "${e}" =~ "set-is-exe" ]] && \
		[ ! -x "${statefile_setaddr}" ]; then
		echo "setaddr: error file not exe"
		err=$((err+1))
	fi

	if [[ "${e}" =~ "dis-not-empty" ]] && \
		[ ! -s "${statefile_disconnect}" ]; then
		echo "disconnect: error file is empty"
		err=$((err+1))
	fi
	if [[ "${e}" =~ "dis-is-empty" ]] && \
		[ -s "${statefile_disconnect}" ]; then
		echo "disconnect: error file not empty"
		err=$((err+1))
	fi
	done

	if [ ${err} -eq 0 ]; then
		_print_done "passed-${1}"
		p=$((p+1))
	else
		_print_error "failed-${1}"
		exit
	fi
}


t=5
p=0

# e.g: redmi-camellia
_perform_test "1"
_confirm_test "1" "dis-is-empty" "set-not-exe set-is-empty" 

# e.g: redmi-sunstone
_perform_test "2" "Operation not permitted" "Permission denied+"
_confirm_test "2" "dis-not-empty" "set-not-exe set-not-empty"

# e.g: redmi-alioh
_perform_test "3" "Operation not permitted" "Invalid argument+"
_confirm_test "3" "dis-not-empty" "set-is-exe set-is-empty"

# e.g: redmi-?
_perform_test "4" "Operation not permitted" "Permission denied" "Invalid argument"
_confirm_test "4" "dis-not-empty" "set-not-empty set-is-exe"

# e.g: redmi-?
_perform_test "5" "Operation not permitted" "Invalid argument" "Permission denied"
_confirm_test "5" "dis-not-empty" "set-is-exe set-not-empty"

echo -e "tests: ${t}\npassed: ${p}"

