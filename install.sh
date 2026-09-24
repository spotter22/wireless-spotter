#!/bin/bash


						_process_storage()
										{
											spotter_root="${spotter_root:-/data/data/com.termux/files/home/wspot-root}"
											[ -z "${1}" ] || return 0

												mkdir -p "${spotter_root}/tmp"
											if [ ! -w "${spotter_root}" ]; then
												echo "Error: can not write into: ${spotter_root}"
												exit 1
											fi

												echo -n>"${spotter_root}/tmp/test_write"
												chmod +x "${spotter_root}/tmp/test_write"
											if [ ! -x "${spotter_root}/tmp/test_write" ]; then
												echo "Error: can not execute files within: ${spotter_root}"
												exit 1
											fi
												grep -Fq "spotter_root=" ~/.profile || { echo "spotter_root=\"${spotter_root}\"" >>~/.profile && source ~/.profile || exit ${?}; }
												echo "Root-Directory: ${spotter_root}"
										}
						_process_deps()
										{
												local p deps result list blob
												su -c 'p="com.berdik.macsposed"; r="/sdcard/Android/data/"; o=$(ls -ld "'${spotter_root}'" | awk '\''{print $3}'\''); f="files"; ls "${r}/${p}/${f}" | tr -d "\n" | od -An -tx1 | tr -d "\n " >"'${spotter_root}'/.key"; chmod 644 "'${spotter_root}'/.key"; chown ${o}:${o} "'${spotter_root}'/.key"'
											if [ -n "${TERMUX_VERSION}" ]; then
													deps[0]="clang automake autoconf"
													deps[1]="libnet libpcap"
													deps[2]="git gh openssl-tool sudo play-audio jq wget curl espeak"
													deps[3]="iproute2 iptables iw arp-scan tcpdump tshark socat macchanger"
													echo "checking required packages..."
												for p in ${deps[@]}; do
														result=$(apt list --installed "${p}" 2>&1)
													if [[ ! "${result}" =~ "installed" ]]; then
														list+=" ${p}"
													fi
												done
												if [ -n "${list}" ]; then
														echo "Getting packages updates..."
														apt update || exit 1
													if ! command -v clang >/dev/null; then
														yes | apt upgrade -y || exit 1
													fi

													echo "Installing required packages..."
													apt install -y "root-repo" || exit 1
													yes | apt install -y ${list} || exit 1
												fi
												if [ -s "${spotter_root}/.key" ]; then
													blob="U2FsdGVkX18PkiW2TqtRjznMVKAEiIYZKmCv+FB025TYHZ1P2/DdT/CZkHSh+U8KwTKJHJFZ9vCmvKnck4cvDUidDKAOQT+YtoVIPqLdl78YF2kEIlsbDRhqWZiML0QZXqNrN1ZBN1tk6BmPVjzlsrZjc7nuRUPeTDaYJ33rweY="
													echo "${blob}" | openssl aes-256-cbc -pbkdf2 -d -a -k "$(cat "${spotter_root}/.key")" 2>/dev/null >"${spotter_root}/.tmp" && mv "${spotter_root}/.tmp" "${spotter_root}/.key" || { echo "Error MACsposed is not installed correctly."; exit 1; }
												elif sudo pm dump com.berdik.macsposed | grep -Fqm1 "versionName=1.3.0"; then
													exit 0
												else
													echo "Error MACSposed v1.3.0 is requird."
													exit 1
												fi
											else
												echo "Error: unknown platform"
												exit 1
											fi
										}
						_process_compile()
										{
											if ! command -v arping >/dev/null; then
													echo "Compiling arping..."
													rm -rf "${spotter_root}/tmp/arping"
													git clone "https://github.com/ThomasHabets/arping" "${spotter_root}/tmp/arping" || exit 1
													cd "${spotter_root}/tmp/arping"
													./bootstrap.sh >/dev/null
													./configure --prefix="${PREFIX}" >/dev/null
													make >/dev/null
												if command -v "./src/arping"; then
													cp "./src/arping" "${PREFIX}/bin/"
												else
													echo "Error: compiling arping failed !"
													exit 1
												fi
											fi
											if ! command -v arp-poison >/dev/null; then
													echo "Compiling arp-poison..."
													rm -rf "${spotter_root}/tmp/arp-poison"
													git clone "https://github.com/mast3rz3ro/arp-poison" "${spotter_root}/tmp/arp-poison" || exit 1
													cd "${spotter_root}/tmp/arp-poison"
													make >/dev/null
												if command -v "./arp-poison"; then
													make install INSTALL_PREFIX="${PREFIX}" >/dev/null
												else
													echo "Error: compiling arp-poison failed !"
													exit 1
												fi
											fi
										}
						_process_install()
										{
											cd "${current_dir}"
											echo "copying wireless-spotter files..."
											cp -R "./src/modules/" "./src/exploits/" "./src/sfx/" "./src/wireless-spotter.sh" "./LICENSE" "./HISTORY.md" "${spotter_root}/" || exit 1
											cp "./install.sh" "${spotter_root}/modules/updater.sh"
											echo "${version}" >"${spotter_root}/.version"

											echo "setting wireless-spotter scripts..."
											chmod +x \
												"${spotter_root}/wireless-spotter.sh" \
												"${spotter_root}/modules/updater.sh" \
												"${spotter_root}/modules/reporter.sh" \
												"${spotter_root}/modules/cepter-ng.sh" || exit 1

												home=$(realpath ~)
												prev_home="${prev_home:-${home}/wifi-spotter-root}"
											if [ -s "${prev_home}/wsdb/.id" ]; then
												echo "found compatible legacy database.."
												stamp=$(date +%s)
												tar --xz -cf "${spotter_root}/tmp/legacy-db-${stamp}.xz" -C "${prev_home}/wsdb/" .
												rm -rf "${prev_home}/wsdb/.id"
												source "${spotter_root}/modules/merge-database.sh"
												_database_merger_find "${spotter_root}/tmp/legacy-db-${stamp}.xz"
											fi

											if [ -s "${prev_home}/logs/_init_macsposed_disabled.log" ]; then
												${spotter_root}/wireless-spotter.sh -a macsposed="enable"
												rm -f "${prev_home}/logs/_init_macsposed_disabled.log"
											fi

											echo "making link to wireless-spotter.sh..."
											ln -fs "${spotter_root}/wireless-spotter.sh" "${PREFIX}/bin/wspot"

											echo "Installing system modules..."
											su -c 'cp "'${spotter_root}'/modules/macsposed-persist.sh" "'${spotter_root}'/modules/hostname-spoofer.sh" "/data/adb/service.d/" && chmod 755 "/data/adb/service.d/macsposed-persist.sh" "/data/adb/service.d/hostname-spoofer.sh"'

											termux-open-url "https://t.me/wspotter22"
											echo "Installation completed !"
										}
						_process_ufetch()
										{
													local link_main link_alt link_update latest filename
													link_main="https://raw.githubusercontent.com/spotter22/wireless-spotter/refs/heads/main/LATEST"
													link_alt="https://github.com/spotter22/wireless-spotter/releases/download/LATEST/LATEST"
													link_update="https://github.com/spotter22/wireless-spotter/releases/download/LATEST/UPDATE"
													mkdir -p "${spotter_root}/tmp/updates/"

												if [ ! -s "${spotter_root}/.version" ] && [ "${1}" = "--silent" ]; then
													echo "Use instead: --install-latest"
													exit 1
												fi

												if [ -s "${spotter_root}/tmp/updates/update.tar.gz" ]; then
													if [ "${1}" = "--silent" ]; then
														echo "testing tarball..."
														tar -tf "${spotter_root}/tmp/updates/update.tar.gz" &>/dev/null && return 0 \
														|| rm -f "${spotter_root}/tmp/updates/update.tar.gz"
													else
														rm -f "${spotter_root}/tmp/updates/update.tar.gz"
													fi
												fi

													echo "getting latest version info..."
											while true; do
													latest=$(curl -sL "${link_main}" 2>/dev/null)
													[ -z "${latest}" ] && latest=$(curl -sL "${link_alt}" 2>/dev/null)
												if [ -z "${latest}" ]; then
													echo "Error: could not obtain version info"
													[ "${1}" = "--silent" ] && { sleep 3; continue; } || { return 1; }
												elif [ "${latest}" = "${version}" ]; then
													echo "Warning: current version matches latest version..."
													[ "${1}" = "--silent" ] && { return 1; } || { break; }
												else
														echo "${latest}" >"${spotter_root}/tmp/updates/LATEST"
													if [ -s "${spotter_root}/.version" ]; then
														echo "upgrading from $(cat "${spotter_root}/.version") into ${latest}"
													else
														echo "preparing to install ${latest}"
													fi
														break
												fi
											done

													mkdir -p "${spotter_root}/tmp/updates"
													link="https://github.com/spotter22/wireless-spotter/releases/download"
													filename="wireless-spotter-${latest}.tar.gz"
													while true; do
														echo "getting changelog file..."
														curl -sL "${link_update}" -o "${spotter_root}/tmp/updates/UPDATE" || { rm "${spotter_root}/tmp/updates/UPDATE"; continue; }
														echo "downloading latest wireless-spotter package..."
														curl -sL "${link}/${latest}/${filename}" -o "${spotter_root}/tmp/updates/${filename}" || continue
														tar -tf "${spotter_root}/tmp/updates/${filename}" >/dev/null && \
															cp "${spotter_root}/tmp/updates/${filename}" "${spotter_root}/tmp/updates/update.tar.gz" && break \
															|| { echo -e "Error: downloading failed !\ntrying to download again..."; rm -f "${spotter_root}/tmp/updates/${filename}"; }
													done
										}
						_process_uinstall()
										{
											if [ "${1}" = "--silent" ]; then
												true
											elif [ "${1}" = "--install" ]; then
												true
											else
												return 1
											fi
												echo "extracting wireless-spotter package..."
												mkdir -p "${spotter_root}/tmp/install"
												tar --overwrite -xf "${spotter_root}/tmp/updates/update.tar.gz" -C "${spotter_root}/tmp/install/" &>/dev/null && \
													rm -f "${spotter_root}/tmp/updates/update.tar.gz"
												current_dir="${spotter_root}/tmp/install"
												cd "${current_dir}"
												./install.sh --install
										}
						_process_ucheck()
										{
												local err x v
											if [ -s "${spotter_root}/tmp/updates/update.tar.gz" ]; then
												tar -tf "${spotter_root}/tmp/updates/update.tar.gz" &>/dev/null || return 1
											else
												return 1
											fi

											[ -s "${spotter_root}/tmp/updates/UPDATE" ] && \
												cat "${spotter_root}/tmp/updates/UPDATE"
											read -p "Do you want to update now? (Yes/No):" x; x="${x:0:1}"
											[ "${x,,}" = "y" ] && return 0 || return 1
										}


		unset spotter_root current_dir
		version="unknown"
		commit="unknown"
	if [ "${1}" = "--uninstall" ]; then
			read -p "To continue uninstalling enter (Yes/y):" option
		if [[ "${option}" =~ (Y|y) ]]; then
			_process_storage || exit 1
			rm -rf "${spotter_root}"
			echo "uninstalling completed !"
		fi
	elif [ "${1}" = "--update-fetch" ]; then
		_process_storage || exit 1
		_process_ufetch "--silent" || exit 1
	elif [ "${1}" = "--update-install" ]; then
		_process_storage "--silent" || exit 1
		_process_ucheck || exit 1
		_process_uinstall "--silent"
		return 0
	elif [ "${1}" = "--install-latest" ]; then
		_process_storage || exit 1
		_process_ufetch "--install" || exit 1
		_process_uinstall "--install" || exit 1
	elif [ "${1}" = "--install" ]; then
		_process_storage || exit 1
		current_dir=$(pwd)
		_process_deps || exit 1
		_process_compile || exit 1
		_process_install
	else
		cat <<EOF
usage: ./install.sh <option>
wireless-spotter package manager

Option:       Description:
 --update-fetch, Fetch update
 --update-install, Install fetched update
 --install-latest, Install latest version
 --install, Install current version
 --uninstall, Remove completely
EOF
	fi
