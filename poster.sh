#!/bin/bash


_version(){
		commit=$(git rev-parse --short HEAD)
		version="v$(cat "./UPDATE.md" | awk '{print $3}' | sed -n 1p)"
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
	if [[ "${option}" =~ (Y|y) ]]; then
		return 0
	else
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
		cp "./install.sh" "./LICENSE" "./releases/tmp/"

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

	export GH_TOKEN="${ws_token}"
	mkdir -p "./.cache/git/tags" "./.cache/git/releases" "./.cache/git/legacy"
	echo "creating tag.."
	[ -f "./.cache/git/tags/${version}.tag" ] || { gh release create "${version}" --title "${version}" --notes "$(cat ./UPDATE.md)" && echo -n>"./.cache/git/tags/${version}.tag" || return 1; }
	[ -f "./.cache/git/tags/LATEST" ] || { gh release create "LATEST" --title "LATEST" --notes "LATEST" && echo -n>"./.cache/git/tags/LATEST" || return 1; }
	echo "uploading release.."
	[ -f "./.cache/git/releases/${version}.tag" ] || { gh release upload "${version}" "./releases/wireless-spotter-${version}.tar.gz" && echo -n>"./.cache/git/releases/${version}.tag" || return 1; }
	[ -f "./.cache/git/releases/${version}.log" ] || { gh release upload --clobber "LATEST" "./UPDATE.md" && echo -n>"./.cache/git/releases/${version}.log" || return 1; }
	[ -f "./.cache/git/legacy/${version}-latest.tag" ] || { gh release upload --clobber "LATEST" "./LATEST" && echo -n>"./.cache/git/legacy/${version}-latest.tag" || return 1; }
	[ -f "./.cache/git/legacy/${version}-update.tag" ] || { gh release upload --clobber "LATEST" "./UPDATE" && echo -n>"./.cache/git/legacy/${version}-update.tag" || return 1; }
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
			if [ ! -s "./UPDATE.md" ] || [[ ! "${status}" =~ "UPDATE.md" ]]; then
				echo "New changes must be written into: ./UPDATE.md"
				return 1
			elif [[ "${status}" =~ "UPDATE.md" ]]; then
				cat "./UPDATE.md"
				read -p "Your changes looks like this, continue (y/n)?" option
				[[ "${option}" =~ (Y|y) ]] || return 1
			fi
		fi
	fi

	if [ "${commit}" = "initial" ] || [ "$(git log -n1 --oneline | awk '{print $3}')" != "${version}" ]; then	
		echo "commiting changes ..."
		echo "${version}" >"./LATEST" # legacy
		echo "${version}" >"./UPDATE" # legacy
		[ "${commit}" = "initial" ] && git init
		[ "${commit}" = "initial" ] && git remote add origin "https://github.com/${ws_contributor}/wireless-spotter"
		git add .
		git config user.email "${ws_email}"
		git config user.name "${ws_contributor}"
		git commit --author="${ws_contributor} <${ws_email}>" -m "$(cat "./UPDATE.md")"
	fi
		echo "pushing changes ..."
		git push "https://${ws_contributor}:${ws_token}@github.com/${ws_contributor}/wireless-spotter.git" main

		echo "posting commit changes..."
		_tg_notify || return 1
}


_tg_notify(){
	local result
	mkdir -p "./.cache/tg/" || return 1; [ -f "./.cache/tg/${version}.tag" ] && return 0
	var1="111ch111at1111_i111d11111111"; var2="ri222ch_22me2222ss22222age22222"
	var3="m3333ar333k3333do3333w333333n"; var4="C4ont4ent4-T4ype4: appli4cat4ion/j44s4o4n4444"
	var5="5ht5tp5s5:5/5/a5p5i.t5el5eg5ra5m5.o5r5g/b5o5t5"; var6="6s6end6Ric6hMe6ss6ag6e6"
	result=$(curl -X POST "${var5//5/}${ws_token2}/${var6//6/}" -H "${var4//4/}" -d "{\"${var1//1/}\": \"-1003946012815\",\"${var2//2/}\": {\"${var3//3/}\": \"$(cat "./UPDATE.md" | sed "s|\`|\\\\\`|g; s|#|\\\#|g; s|/|\\\/|g")\"}}")
	[[ "${result}" =~ '"ok":true' ]] && { echo -n>"./.cache/tg/${version}.tag"; echo "posting changelog: succeed"; return 0; } || { echo "posting changelog: failed"; echo "reason: ${result}"; return 1; }
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
