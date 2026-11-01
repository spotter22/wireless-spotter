#!/bin/bash


		unset list raw
	while read x; do
		raw+=" | ${x}"
		x="${x//\"/\\\"}"; x="${x//)/\\)}"; x="${x//(/\\(}"
		list+="|${x}"
	done< <(cat "${1}")
		echo "PATTERN: ${list}"
		echo "RAW: ${raw}"
