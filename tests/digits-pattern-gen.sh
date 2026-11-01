#!/bin/bash


	while read x; do
		x="${x//\"/}"; x="${x//(/\\(}"
		x="${x//)/\\)}"; x="${x//9/[0-9]}"
		echo "|$x\\"
	done< <(cat "${1}")
