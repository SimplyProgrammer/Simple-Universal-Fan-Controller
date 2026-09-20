#!/bin/sh

# Configuration script for creating/updating fan configs of the individual fans
# Note that "Fan name" has to be unique and correspond to the actual fan device, fans starting with _ are ignored
# You can group multiple fans under one config by creating a base config and including it in individual fan configs or symlinking it. 
# Base config can refer to existing configurations in current directory or in the ./configs directory

cd "$(dirname "$0")" || exit 1

comment="# use evl for advanced expressions ('evl \"\$(./sensors/cpu-all-cores) + 5\"')"
default_fan_name=$1
default_base_config=$2
default_sensor_command=$3

if [ -n "$default_fan_name" ]; then
	printf 'Fan name [%s]: ' "$default_fan_name"
else
	printf 'Fan name: '
fi
IFS= read -r fan_name || exit 1
[ -n "$fan_name" ] || fan_name=$default_fan_name
[ -n "$fan_name" ] || exit 0

if [ -e "$fan_name" ]; then
	printf 'Fan file exists. Override? [Y/n] '
	IFS= read -r override || exit 1
	case "$override" in
		n|N) exit 0 ;;
	esac
fi

if [ -n "$default_base_config" ]; then
	printf 'Base fan config [%s]: ' "$default_base_config"
else
	printf 'Base fan config: '
fi
IFS= read -r base_config || exit 1
[ -n "$base_config" ] || base_config=$default_base_config

base_file=
if [ -n "$base_config" ]; then
	if [ -f "./configs/$base_config" ]; then
		base_file="./fans/configs/$base_config"
	elif [ -f "./$base_config" ]; then
		base_file="./fans/$base_config"
	else
		printf 'Base fan config not found: %s\n' "$base_config" >&2
		exit 1
	fi
fi

if [ -n "$default_sensor_command" ]; then
	printf 'Sensor command [%s]: ' "$default_sensor_command"
else
	printf 'Sensor command: '
fi
IFS= read -r sensor_command || exit 1
[ -n "$sensor_command" ] || sensor_command=$default_sensor_command

if [ -z "$sensor_command" ]; then
	sensor_command='./sensors/cpu-all-cores'
elif case "$sensor_command" in *[[:space:]]*) true ;; *) false ;; esac; then
	sensor_command="evl \"$sensor_command\""
fi

{
	printf '%s\n\n' '#!/bin/sh'
	if [ -n "$base_file" ]; then
		printf '. %s\n\n' "$base_file"
	fi
	printf "SENSOR_CMD='%s' %s\n" "$sensor_command" "$comment"
	if [ -z "$base_file" ]; then
		printf '\n%s\n' "#FAN_CURVE='<temperature>=<speed> ...' points that will be linearly interpolated"
	fi
} > "$fan_name"