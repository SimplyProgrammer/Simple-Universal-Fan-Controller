# Simple Universal Fan Controller

Small yet powerful POSIX shell fan controller for Linux systems.
It was designed with dell 13/14 gen servers and/or hardware that supports manual fan control through `ipmitool` or similar utility, but in theory it can be adapted for any system.
Unlike similar scripts, this one is:
* Fully extensible
* Supports per fan control or fan group control
* Supports any sensors and or custom user definable sensors
* Control through user defined or pre made fan curves that can be extended
* Bare bones and fairly minimalistic - no docker required, minimal extra dependencies, it runs directly on the host in basic `sh`

## Installation as a systemd Service (work in progress)
The controller needs `awk`, `sensors`/`lm-sensors`, and `ipmitool` (for supported devices). `grep` and `sed` are optional but you might need them.<br>
You need to be root or have root permissions (`sudo`) in order to proceed!

Clone this repo into /opt/fanctrl and set proper permissions:
```sh
sudo mkdir -p /opt/fanctrl && cd "$_" && sudo git clone --depth 1 "https://github.com/SimplyProgrammer/Simple-Universal-Fan-Controller.git" . || exit 1

sudo chown -R root:root /opt/fanctrl

sudo find /opt/fanctrl -type d -exec chmod 750 {} +
sudo find /opt/fanctrl -type f -exec chmod 640 {} +
sudo find /opt/fanctrl -type f -name "_*.sh" -exec chmod 750 {} +

sudo chmod 750 /opt/fanctrl/run-fanctrl
sudo chmod 660 /opt/fanctrl/fanctrl
sudo find /opt/fanctrl/commands -type f -exec chmod 750 {} +
sudo find /opt/fanctrl/sensors -type f -exec chmod 750 {} +
```

Create and enable the service (systemd):
```sh
tmp=$(mktemp)
cat > "$tmp" <<EOF
[Unit]
Description=Simple Universal Fan Controller
After=ipmi.service

[Service]
Type=simple
WorkingDirectory=/opt/fanctrl
ExecStart=/opt/fanctrl/run-fanctrl 3
Restart=always
RestartSec=9

[Install]
WantedBy=multi-user.target
EOF

sudo install -o root -g root -m 644 "$tmp" /etc/systemd/system/fanctrl.service
[ -f "$tmp" ] && rm -f "$tmp"

sudo systemctl daemon-reload
sudo systemctl enable --now fanctrl.service
```

Check the service with `systemctl status fanctrl.service` and view its output
with `journalctl -u fanctrl.service`.

## Folder Structure

* run-fanctrl			Main script that periodically executes the main pass
  * commands/			Hardware-specific manual-control and PWM commands
    * _use.sh			Activate command files from a hardware profile
    * dell-srvr/		Dell server command support implementations
  * fans/				One configuration file per physical fan
    * _config-fan.sh	Interactive fan configuration generator
    * configs/ 			Reusable fan curves: default, silent, turbo, etc.
* includes/ 			Shared shell variables loaded in each pass
* sensors/ 				Custom pre made sensor

The active hardware commands are `commands/enable-manual-fan-ctrl` and
`commands/set-fan-speed`. The active fan files are the regular files or
symlinks directly inside `fans/`; `_`-prefixed helper files and subdirectories
are not treated as fans.

## Configure the Controller

Run these commands from the repository root unless noted otherwise.

### 1. Select hardware commands with `_use.sh`

`commands/_use.sh` takes a profile directory and symlinks its command files
into `commands/`. For the included Dell server commands:

```sh
cd /opt/fanctrl/commands
./_use.sh dell-srvr
```

Likewise a custom hardware profile should provide
both `enable-manual-fan-ctrl` and `set-fan-speed` with the same argument
contracts as the files in `commands/`.

#### Servers - ipmitool
For servers make sure that you have ipmi support enabled (if required) and ipmitool installed (or other utility that can control the fan speeds).<br>
Note: Supermicro servers are supported as well in theory, but script was only ever tested with dell 13gen server.

### 2. Create fan configurations with `_config-fan.sh`

Create or update a fan interactively from the `fans/` directory. Example:

```sh
./_config-fan.sh 0 default ./sensors/cpu-all-cores
```

The arguments provide defaults for fan name, base config, and sensor command;
the script prompts for confirmation and lets you change them. It creates a
file such as `fans/0` containing `SENSOR_CMD` and, when appropriate, a sourced
`FAN_CURVE`. Fan names must match the IDs accepted by the hardware command.

Use a profile as a base when several fans share a curve. The generated fan
file can source a file in `fans/configs/` or another fan file, then override
`SENSOR_CMD` for that fan.

## Sensors and Curves

The premade custom sensor helpers print a numeric temperature in degrees Celsius:

```sh
./sensors/cpu-all-cores         # avg, min or max of specified cpu package cores
./sensors/cpu-package 0         # temperature of specified cpu package
./sensors/sensors               # avg, min or max of all or specified sensor
```

Which are expected to be used in particular fans `SENSOR_CMD`, for instance:


```sh
SENSOR_CMD='evl "$(./sensors/cpu-all-cores) + 5"'
```

The bundled curves are:

- `default`: moderate baseline cooling.
- `silent`: lower speeds for quieter operation.
- `turbo`: max speed sooner.
- `linear`: 0% to 100% linear behavior (temp = speed).
- `elbow`: quieter <50, louder above it.

Feel free to create your own sensors as well as fan curves.
Its general good practice for the custom ones to be dot files, so they are distinguished.<br>
All of this makes the script equivalent or even superior to what your motherboard UEFI allows.

## Safety Notes

- Test the selected hardware commands manually before enabling the service.
- Note that script and sensors are not officially designed for sub-zero scenarios.
- Keep a conservative minimum speed - `fanctrl` uses
  thresholds `DEFAULT_MIN_SPEED`/`DEFAULT_MAX_SPEED` as the clamp
  values when those variables are provided by `includes/`. They have default fallbacks and is recommended to not change them.
- Ensure every active fan has both `SENSOR_CMD` and `FAN_CURVE` (in place or sourced from base).
- In case of any pass errors or termination, the script is configured to immediately hand over control back to the hardware (to disable manual control), preventing thermal issues in case of script failure.
  - But note that if your system kernel panics or crashes in such a way that this never occurs it is theoretically possible for the fans to get stuck at low speeds which may result in equipment damage.<br>
Note that author is not responsibly for any such cases!