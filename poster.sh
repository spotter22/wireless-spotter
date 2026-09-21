#!/bin/bash


_version(){
		commit=$(git rev-parse --short HEAD)
		version=$(cat "./LATEST")
	if [ -z "${commit}" ]; then
		echo "Error: could not obtain current commit"
		read -p "Are you going to reboot again (Y/N)?:" option
		[[ "${option}" =~ (Y|y) ]] && commit="initial" && return 0 || return 1
	elif [ -z "${version}" ]; then
		echo "Error: could not obtain current version"
		return 1
	fi

		echo -e "Version: ${version}\nCommit: ${commit}"
		read -p "Do you want to continue (y/n)?:" option
	if ! [[ "${option}" =~ (Y|y) ]]; then
		return 1
	fi
}


_release(){
		_version || return 1
	if [ ! -s "./releases/wireless-spotter-${version}.tar.gz" ]; then
		echo "copying release files ..."
		rm -rf "./releases/tmp/"
		mkdir -p "./releases/tmp/src"
		cp -r "./src/modules" "./src/exploits" "./src/sfx" "./src/wireless-spotter.sh" "./releases/tmp/src/"
		cp "./install.sh" "./LICENSE" "./HISTORY.md" "./releases/tmp/"

		echo "setting release info ..."
		sed -i "s|commit=.*|commit=\"${commit}\"|; s|version=.*|version=\"${version}\"|" \
			"./releases/tmp/src/wireless-spotter.sh" \
			"./releases/tmp/install.sh" \
			|| { echo "Error: unexpected error while setting release info"; exit 1; }

		echo "now packing files ..."
		tar -czvf "./releases/wireless-spotter-${version}.tar.gz" -C "./releases/tmp/" . \
			|| { echo "Error: unexpected error while packing files"; exit 1; }

		echo "release: ./releases/wireless-spotter-${version}.tar.gz"
	else
		echo "Warning release already exists: ./releases/wireless-spotter-${version}.tar.gz"
	fi

	echo "creating release ..."
	export GH_TOKEN="${ws_token}"
	git remote add origin "https://github.com/${ws_contributor}/wireless-spotter"
	gh release create "${version}" --title "${version}" --notes "revision: ${version}"
	gh release create "LATEST" --title "LATEST" --notes ""
	echo "uploading release ..."
	gh release upload "${version}" "./releases/wireless-spotter-${version}.tar.gz"
	gh release upload "LATEST" "./LATEST"
	gh release upload "LATEST" "./UPDATE"
}


_commit(){
		_version || return 1
		echo "getting environment variables ..."
	if [ -z "${ws_contributor}" ]; then
		echo "Error: ws_contributor variable is not set"
		return 1
	elif [ -z "${ws_email}" ]; then
		echo "Error: ws_email variable is not set"
		return 1
	elif [ -z "${ws_token}" ]; then
		echo "Error: ws_token variable is not set"
		return 1
	fi

	if [ "${commit}" != "initial" ]; then
			status=$(git status 2>&1)
		if [[ "${status}" =~ "Untracked files:" ]]; then
			git status
			read -p "Commit includes new files continue (y/n)?:" option
			[[ "${option}" =~ (Y|y) ]] || return 1
		fi
		if [[ "${status}" =~ "modified:" ]]; then
			if [ ! -s "./UPDATE" ] || [[ ! "${status}" =~ "UPDATE" ]]; then
				echo "New changes must be written into: ./UPDATE"
				return 1
			elif [ ! -s "./LATEST" ] || [[ ! "${status}" =~ "LATEST" ]]; then
				echo "New version must be set into: ./LATEST"
				return 1
			elif [[ "${status}" =~ "UPDATE" ]]; then
				cat "./UPDATE"
				read -p "Your changes looks like this, continue (y/n)?" option
				[[ "${option}" =~ (Y|y) ]] || return 1
			fi
		fi
	fi

	if [ "${commit}" = "initial" ] || [ "$(git log -n1 --oneline | awk '{print $3}')" != "${version}" ]; then	
		echo "commiting changes ..."
		tmp=$(mktemp)
		cat "./HISTORY.md" >"${tmp}"
		cat "./UPDATE" >"./HISTORY.md"
		cat "${tmp}" >>"./HISTORY.md"
		[ "${commit}" = "initial" ] && git init
		git add .
		git config user.email "${ws_email}"
		git config user.name "${ws_contributor}"
		git commit --author="${ws_contributor} <${ws_email}>" -m "revision: ${version}"
	fi
		echo "pushing changes ..."
		git push "https://${ws_contributor}:${ws_token}@github.com/${ws_contributor}/wireless-spotter.git" main

		echo "posting commit changes..."
		_tg_notify || return 1
}


_tg_notify(){
	local x y z h c a b d e i
	mkdir -p "./releases/.notify/" || return 1; [ -f "./releases/.notify/${version}" ] && return 0
	x="h211t211t211p211s211:211/211/211a211pi.tel211eg211r211a211m.211o211rg/b211ot"; y="${ws_token2}"; z="211/se211nd211M211es211sa211ge"
	h="Co111nte111nt-Ty111pe: appl111ica111tion/j111s111on; ch111ars111et=ut111f-1118"; c="c1h1a1t1_1i1d"; i="1iii0i03iii94iiiiiiii601i28ii1iii5"
	a="p1ar1se_1mo1de"; b="M1ark1do1wn"; d="di1sa1ble_web_p1a1ge1_11pr1ev1iew"; e="di1s1ab1le_noti1fic1a1ti1on"; msg=$(cat "./UPDATE")
	r=$(curl -s -X POST "${x//211/}${y}${z//211/}" -H "${h//111/}" -d "{\"${c//1/}\": "-${i//i/}",\"text\": \"${msg}\",\"${a//1/}\": \"${b//1/}\",\"${d//1/}\": true,\"${e//1/}\": true,}" 2>&1); [[ "${r}" =~ '"ok":true' ]] && { touch "./releases/.notify/${version}"; echo "succedd !"; return 0; } || { echo "error could not post commit changes."; echo "unexpected error: ${r}"; return 1; }
}


	if [ "${1}" = "--release" ]; then
		_release
	elif [ "${1}" = "--commit" ]; then
		_commit
	else
		cat <<EOF
usage: poster.sh [options]
 --commit, Commit release
 --release, Make Release
EOF
	fi
