#!/bin/sh

# Take all files from ./$1 and create symlinks in the current directory
# Used to apply and link the desired configuration files for a specific device/hardware

for file in ./$1/*; do
	# if not start with _ skip
	[ -f "$file" ] || continue

	case "${file##*/}" in
		_*) continue ;;
	esac

	ln -sf "$file" .
done