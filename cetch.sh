#!/usr/bin/env bash
((BASH_VERSINFO[0] >= 4)) || { echo "cetch: needs bash 4.0+, found $BASH_VERSION" >&2; exit 1; }
set -u
shopt -s extglob
shopt -s nullglob

# ~/.config/cetch/cetch.conf: lines are either "CETCH_VAR=value" (applied
# only if that variable isn't already set in the environment) or anything
# else, which is treated as if typed on the command line
# (ahead of the real argv, so real flags still win).
CONFIG_FILE=${HOME:-}/.config/cetch/cetch.conf
CONFIG_ARGS=()

declare -A OPT_SRC=()
PARSE_SRC=cfg

mark() { OPT_SRC[$1]=$PARSE_SRC; }
opt_cli() { [[ ${OPT_SRC[$1]:-} == cli ]]; }
opt_cfg() { [[ ${OPT_SRC[$1]:-} == cfg ]]; }

load_config() {
	[[ -r $CONFIG_FILE ]] || return 0

	local line key val
	local -a words
	while IFS= read -r line || [[ -n $line ]]; do
		[[ $line =~ ^[[:space:]]*(#.*)?$ ]] && continue

		if [[ $line =~ ^[[:space:]]*(CETCH_[A-Za-z0-9_]+)=(.*)$ ]]; then
			key=${BASH_REMATCH[1]}
			val=${BASH_REMATCH[2]}
			val=${val#[\"\']}
			val=${val%[\"\']}
			if [[ ! -v "$key" ]]; then
				export "$key=$val"
				case $key in
				CETCH_COLOR) mark color ;;
				CETCH_THEME) mark theme ;;
				CETCH_GRADIENT) mark gradient ;;
				CETCH_IMAGE) mark image ;;
				CETCH_LOGO_FILE) mark logo-file ;;
				esac
			fi
		else
			read -ra words <<<"$line"
			((${#words[@]})) && CONFIG_ARGS+=("${words[@]}")
		fi
	done <"$CONFIG_FILE"
}

load_config

BOX_TITLE=${CETCH_TITLE:-System Info}
BOX_MIN_WIDTH=${CETCH_MIN_WIDTH:-42}
LABEL_GAP=2
TITLE_DASHES=2
DISK_MOUNT=${CETCH_DISK:-/}
USE_ACCENT=0
ACCENT_HEX=${CETCH_COLOR:-}

DEFAULT_ROWS=user,kernel,os,wm,packages,disk,battery
ROWS=${CETCH_ROWS:-$DEFAULT_ROWS}
DISTROS='arch cachyos debian ubuntu fedora gentoo mint nixos opensuse void alpine manjaro macos linux'

BLANK_AFTER_LOGO=1
BLANK_BEFORE_DOTS=1
LOGO_GAP=3
SIDE_MIN_BOX=20

DOT=●
BLOCK=██
DOT_GAP=' '
PALETTE=${CETCH_PALETTE:-dots}
PALETTE_N=${CETCH_PALETTE_N:-8}

THEME=${CETCH_THEME:-}
THEME_ACCENT= THEME_PAL=
THEMES='catppuccin nord gruvbox dracula tokyonight everforest rose-pine solarized onedark'

GRADIENT=${CETCH_GRADIENT:-}
USE_GRADIENT=0
GRAD_R1=0 GRAD_G1=0 GRAD_B1=0 GRAD_R2=0 GRAD_G2=0 GRAD_B2=0

HAS_TRUECOLOR=0
ACCENT_SRC=cursor
OUT_JSON=0
PCI_IDS=

TEMP_FILE=${CETCH_TEMP_ZONE:-/sys/class/thermal/thermal_zone0/temp}

ICON_BATTERY="ϟ"
ICON_CELLS=${CETCH_ICON_CELLS:-1}
[[ $ICON_CELLS == +([0-9]) ]] || ICON_CELLS=1
((ICON_CELLS < 1)) && ICON_CELLS=1
((ICON_CELLS > 4)) && ICON_CELLS=4

B_TL=╭ B_TR=╮ B_BL=╰ B_BR=╯ B_V=│ B_H=─
STYLE=${CETCH_STYLE:-rounded}

ICON_USER=$'\xef\x80\x87'
ICON_KERNEL=$'\xf3\xb0\x8c\xbd'
ICON_OS=$'\xef\x85\xbc'
ICON_WM=$'\xef\x8b\x90'
ICON_PKG=$'\xef\x92\x87'
ICON_DISK=$'\xef\x82\xa0'
ICON_UPTIME=$'\xef\x80\x97'
ICON_SHELL=$'\xef\x84\xa0'
ICON_MEM=$'\xf3\xb0\x8d\x9b'
ICON_CPU=$'\xef\x8b\x9b'
ICON_IP=$'\xef\x82\xac'
ICON_TEMP=$'\xef\x8b\x87'
ICON_GPU=$'\xef\x89\xac'
ICON_RES=$'\xef\x84\x88'
ICON_SWAP=$'\xef\x87\x80'
ICON_TERM=$'\xef\x92\x89'
ICON_LOAD=$'\xef\x83\xa4'
ICON_PROCS=$'\xef\x82\x85'
ICON_INIT=$'\xef\x80\x93'
ICON_FREQ=$'\xef\x83\xa7'

USE_COLOR=1
USE_ICONS=1
USE_LOGO=1
LOGO_FILE=${CETCH_LOGO_FILE:-}
IMAGE_FILE=${CETCH_IMAGE:-}
IMAGE_SIZE=${CETCH_IMAGE_SIZE:-auto}
IMAGE_COLS=16 IMAGE_ROWS=8
SHOW_IMAGE=0 IMAGE_WARN=0 IMAGE_SSH=0
PNG_W=0 PNG_H=0
CELL_W=10 CELL_H=20
GFX_TERMS='kitty, Ghostty, WezTerm, Konsole, Rio, wayst'
SIDE=0
SIDE_PAD=0
SIDE_ALIGN=left
COLS_OVERRIDE=${CETCH_COLS:-}


usage() {
	cat <<'EOF'
cetch

Usage: cetch.sh [options]

Options:
  -w, --width N       render as if the terminal were N columns wide
      --accent [SRC]  use a colour the terminal reports: cursor
                      (default), fg or bg
      --color HEX     use a specific color (#7aa2f7, 7aa2f7 or #7af)
      --theme NAME    use a named palette (see --list-themes); sets the
                      accent and the swatches under the box
      --gradient A-B  fade the logo from colour A to colour B down its
                      lines (hex, same forms as --color)
      --side [right] [N]
                      place the logo beside the box, on the left by
                      default, N extra columns clear of it (default 0)
      --style STYLE   box style: rounded (default), boxy, or plain
                      to drop the box and just list the rows
      --palette [NAME] [N]
                      colour swatches under the box: dots (default),
                      blocks, or none to leave them out; N is how many
                      to show, 8 (default) or 16
      --json          print the rows as JSON and nothing else
      --logo-file F   draw the ascii art in file F instead of the
                      built-in logo
      --image FILE    draw the PNG in FILE instead of the ascii art;
                      needs a terminal that speaks the kitty graphics
                      protocol (kitty, Ghostty, WezTerm, Konsole, ...)
      --image-size S  auto (default) to keep the image's own shape, N to
                      set the width and let the height follow, or WxH to
                      pin both cell counts and stretch to fit
      --no-logo       draw the box on its own
      --no-color      monochrome output (--colour/--no-colour also work)
      --no-icons      drop the Nerd Font glyphs (plain labels)
      --list-distros  print the logo names CETCH_DISTRO accepts
      --list-themes   print the names --theme accepts
  -h, --help          show this message

Environment:
  CETCH_DISTRO=id     force a logo (see --list-distros)
  CETCH_ROWS=a,b,c    pick the rows and their order (default:
                      user,kernel,os,wm,packages,disk); choose from
                      user, kernel, os, wm, packages, disk, uptime,
                      shell, memory, swap, cpu, cpufreq, gpu, temp, ip,
                      resolution, terminal, load, procs, init
  CETCH_ICON_CELLS=2  if your terminal draws Nerd Font icons two cells wide
  CETCH_TITLE=text    box title (default "System Info")
  CETCH_MIN_WIDTH=n   minimum box width (default 42)
  CETCH_STYLE=name    same as --style
  CETCH_PALETTE=name  same as --palette
  CETCH_PALETTE_N=n   how many swatches, 8 or 16
  CETCH_THEME=name    same as --theme
  CETCH_GRADIENT=A-B  same as --gradient
  CETCH_LOGO_FILE=f   same as --logo-file
  CETCH_IMAGE=f       same as --image
  CETCH_IMAGE_SIZE=n  same as --image-size
  CETCH_DISK=path     filesystem for the disk row (default /)
  CETCH_TEMP_ZONE=f   sysfs file for the temp row (default
                      /sys/class/thermal/thermal_zone0/temp)
  CETCH_COLS=n        same as --width
  CETCH_COLOR=hex     same as --color
  NO_COLOR=1          disable colour (https://no-color.org)

Config file:
  ~/.config/cetch/cetch.conf, if present, is read before argv: each line
  is either CETCH_VAR=value or a flag, as if typed on the command line.
EOF
}

list_distros() {
	local d
	for d in $DISTROS; do printf '%s\n' "$d"; done
}

list_themes() {
	local t
	for t in $THEMES; do printf '%s\n' "$t"; done
}

resolve_conflicts() {
	local o

	for o in color accent theme gradient; do
		if opt_cli "$o" && opt_cfg no-color; then
			USE_COLOR=1
			break
		fi
	done

	for o in image logo-file side; do
		if opt_cli "$o" && opt_cfg no-logo; then
			USE_LOGO=1
			break
		fi
	done

	opt_cli logo-file && opt_cfg image && IMAGE_FILE=
	return 0
}

load_theme() {
	case ${1,,} in
	catppuccin | catppuccin-mocha | mocha)
		THEME_ACCENT=cba6f7
		THEME_PAL='45475a f38ba8 a6e3a1 f9e2af 89b4fa f5c2e7 94e2d5 bac2de 585b70 f38ba8 a6e3a1 f9e2af 89b4fa f5c2e7 94e2d5 a6adc8'
		;;
	nord)
		THEME_ACCENT=88c0d0
		THEME_PAL='3b4252 bf616a a3be8c ebcb8b 81a1c1 b48ead 88c0d0 e5e9f0 4c566a bf616a a3be8c ebcb8b 81a1c1 b48ead 8fbcbb eceff4'
		;;
	gruvbox)
		THEME_ACCENT=fabd2f
		THEME_PAL='282828 cc241d 98971a d79921 458588 b16286 689d6a a89984 928374 fb4934 b8bb26 fabd2f 83a598 d3869b 8ec07c ebdbb2'
		;;
	dracula)
		THEME_ACCENT=bd93f9
		THEME_PAL='21222c ff5555 50fa7b f1fa8c bd93f9 ff79c6 8be9fd f8f8f2 6272a4 ff6e6e 69ff94 ffffa5 d6acff ff92df a4ffff ffffff'
		;;
	tokyonight | tokyo-night)
		THEME_ACCENT=7aa2f7
		THEME_PAL='15161e f7768e 9ece6a e0af68 7aa2f7 bb9af7 7dcfff a9b1d6 414868 f7768e 9ece6a e0af68 7aa2f7 bb9af7 7dcfff c0caf5'
		;;
	everforest)
		THEME_ACCENT=a7c080
		THEME_PAL='343f44 e67e80 a7c080 dbbc7f 7fbbb3 d699b6 83c092 d3c6aa 475258 e67e80 a7c080 dbbc7f 7fbbb3 d699b6 83c092 d3c6aa'
		;;
	rose-pine | rosepine)
		THEME_ACCENT=c4a7e7
		THEME_PAL='26233a eb6f92 31748f f6c177 9ccfd8 c4a7e7 ebbcba e0def4 6e6a86 eb6f92 31748f f6c177 9ccfd8 c4a7e7 ebbcba e0def4'
		;;
	solarized)
		THEME_ACCENT=268bd2
		THEME_PAL='073642 dc322f 859900 b58900 268bd2 d33682 2aa198 eee8d5 002b36 cb4b16 586e75 657b83 839496 6c71c4 93a1a1 fdf6e3'
		;;
	onedark | one-dark)
		THEME_ACCENT=61afef
		THEME_PAL='282c34 e06c75 98c379 e5c07b 61afef c678dd 56b6c2 abb2bf 5c6370 e06c75 98c379 e5c07b 61afef c678dd 56b6c2 ffffff'
		;;
	*)
		printf 'cetch: warning: unknown theme %q (try --list-themes)\n' "$1" >&2
		return 1
		;;
	esac
}

# battery info support for Mac and Linux:
get_battery() {
    # Linux
    if [ -r /sys/class/power_supply/BAT0/capacity ]; then
        printf "%s%% (%s)\n" \
            "$(cat /sys/class/power_supply/BAT0/capacity)" \
            "$(tr '[:upper:]' '[:lower:]' < /sys/class/power_supply/BAT0/status)"
        return
    fi

    # macOS
    if command -v pmset >/dev/null 2>&1; then
        pmset -g batt | awk '
            /InternalBattery/ {
                gsub(";", "", $3)
                gsub(";", "", $4)
                print $3 " (" tolower($4) ")"
            }
        '
        return
    fi

    echo "No Battery"
}

parse_args() {
	local _v _w
	while (($#)); do
		case $1 in
		-w | --width)
			COLS_OVERRIDE=${2:-}
			shift
			;;
		--width=*) COLS_OVERRIDE=${1#*=} ;;
		--color | --colour)
			ACCENT_HEX=${2:-}
			mark color
			shift
			;;
		--color=* | --colour=*)
			ACCENT_HEX=${1#*=}
			mark color
			;;
		--no-color | --no-colour)
			USE_COLOR=0
			mark no-color
			;;
		--no-icons) USE_ICONS=0 ;;
		--no-logo)
			USE_LOGO=0
			mark no-logo
			;;
		--side)
			SIDE=1
			mark side
			# the count is optional, so only eat the next word if it is one
			while :; do
				if [[ ${2:-} == left || ${2:-} == right ]]; then
					SIDE_ALIGN=$2
					shift
				elif [[ ${2:-} == +([0-9]) ]]; then
					SIDE_PAD=$2
					shift
				else
					break
				fi
			done
			;;
		--side=*)
			SIDE=1
			mark side
			_v=${1#*=}
			for _w in ${_v//,/ }; do
				if [[ $_w == left || $_w == right ]]; then
					SIDE_ALIGN=$_w
				elif [[ $_w == +([0-9]) ]]; then
					SIDE_PAD=$_w
				else
					printf 'cetch: warning: ignoring invalid --side value %q\n' "$_w" >&2
				fi
			done
			;;
		--style)
			STYLE=${2:-}
			shift
			;;
		--style=*) STYLE=${1#*=} ;;
		--palette)
			while :; do
				if [[ ${2:-} == dots || ${2:-} == blocks || ${2:-} == none ]]; then
					PALETTE=$2
					shift
				elif [[ ${2:-} == +([0-9]) ]]; then
					PALETTE_N=$2
					shift
				else
					break
				fi
			done
			;;
		--palette=*)
			_v=${1#*=}
			for _w in ${_v//,/ }; do
				if [[ $_w == dots || $_w == blocks || $_w == none ]]; then
					PALETTE=$_w
				elif [[ $_w == +([0-9]) ]]; then
					PALETTE_N=$_w
				else
					printf 'cetch: warning: ignoring invalid --palette value %q\n' "$_w" >&2
				fi
			done
			;;
		--theme)
			THEME=${2:-}
			mark theme
			shift
			;;
		--theme=*)
			THEME=${1#*=}
			mark theme
			;;
		--gradient)
			GRADIENT=${2:-}
			mark gradient
			shift
			;;
		--gradient=*)
			GRADIENT=${1#*=}
			mark gradient
			;;
		--json) OUT_JSON=1 ;;
		--logo-file)
			LOGO_FILE=${2:-}
			mark logo-file
			shift
			;;
		--logo-file=*)
			LOGO_FILE=${1#*=}
			mark logo-file
			;;
		--image)
			IMAGE_FILE=${2:-}
			mark image
			shift
			;;
		--image=*)
			IMAGE_FILE=${1#*=}
			mark image
			;;
		--image-size)
			IMAGE_SIZE=${2:-}
			shift
			;;
		--image-size=*) IMAGE_SIZE=${1#*=} ;;
		--accent)
			USE_ACCENT=1
			mark accent
			case ${2:-} in
			fg | foreground | bg | background | cursor)
				ACCENT_SRC=$2
				shift
				;;
			esac
			;;
		--accent=*)
			USE_ACCENT=1
			ACCENT_SRC=${1#*=}
			mark accent
			;;
		--list-distros)
			list_distros
			exit 0
			;;
		--list-themes)
			list_themes
			exit 0
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			printf 'cetch: unknown option %s (try --help)\n' "$1" >&2
			exit 2
			;;
		esac
		shift
	done
}

# sometimes it counts bytes instead of characters so check if that's happening
_probe=─
((${#_probe} == 1)) && MB_OK=1 || MB_OK=0
unset _probe

vwidth() {
	local s=${1//$'\e'\[*([0-9;])m/}
	if ((MB_OK)); then
		_W=${#s}
	else
		s=${s//[$'\x80'-$'\xbf']/}
		_W=${#s}
	fi
}

_rep() {
	local s
	if (($2 < 1)); then
		_R=
		return
	fi
	printf -v s "%$2s" ''
	_R=${s// /$1}
}

_fit() {
	vwidth "$1"
	if ((_W <= $2)); then
		_S=$1
	elif (($2 < 2)); then
		_S=…
	else
		_S=${1:0:$(($2 - 1))}
		if ((MB_OK == 0)); then
			while [[ -n $_S && ${_S: -1} == [$'\x80'-$'\xbf'] ]]; do _S=${_S%?}; done
			[[ -n $_S && ${_S: -1} == [$'\xc0'-$'\xff'] ]] && _S=${_S%?}
		fi
		_S+=…
	fi
}

center() {
	local pad
	if (($# > 1)); then _W=$2; else vwidth "$1"; fi
	pad=$(((COLS - _W) / 2))
	((pad < 0)) && pad=0
	printf '%*s%s\n' "$pad" '' "$1"
}

blank() {
	local i
	for ((i = 0; i < $1; i++)); do printf '\n'; done
}


setup_term() {
	if [[ -n $COLS_OVERRIDE && ! $COLS_OVERRIDE == +([0-9]) ]]; then
		printf 'cetch: warning: ignoring invalid width %q, using terminal width\n' "$COLS_OVERRIDE" >&2
		COLS_OVERRIDE=
	fi
	COLS=${COLS_OVERRIDE:-$(tput cols 2>/dev/null)}
	[[ $COLS == +([0-9]) ]] || COLS=80
	((COLS < 1)) && COLS=80

	[[ -n ${NO_COLOR:-} || ${TERM:-dumb} == dumb ]] && USE_COLOR=0

	LINES_T=$(tput lines 2>/dev/null)
	[[ $LINES_T == +([0-9]) ]] || LINES_T=24

	NCOLORS=0
	HAS_TRUECOLOR=0
	if ((USE_COLOR)); then
		NCOLORS=$(tput colors 2>/dev/null)
		[[ $NCOLORS == +([0-9]) ]] || NCOLORS=8
		case ${COLORTERM:-} in
		truecolor | 24bit) HAS_TRUECOLOR=1 ;;
		esac
		[[ ${TERM:-} == *-direct* ]] && HAS_TRUECOLOR=1
		((NCOLORS >= 16777216)) && HAS_TRUECOLOR=1
	fi
}

setup_style() {
	case $STYLE in
	rounded) ;;
	boxy) B_TL=┌ B_TR=┐ B_BL=└ B_BR=┘ ;;
	plain) ;; # no borders to pick characters for
	*)
		printf 'cetch: warning: ignoring invalid --style value %q, using rounded\n' "$STYLE" >&2
		STYLE=rounded
		;;
	esac

	case $PALETTE in
	dots | blocks | none) ;;
	*)
		printf 'cetch: warning: ignoring invalid --palette value %q, using dots\n' "$PALETTE" >&2
		PALETTE=dots
		;;
	esac

	case $PALETTE_N in
	8 | 16) ;;
	*)
		printf 'cetch: warning: ignoring invalid swatch count %q, using 8\n' "$PALETTE_N" >&2
		PALETTE_N=8
		;;
	esac

	case $SIDE_ALIGN in
	left | right) ;;
	*)
		printf 'cetch: warning: ignoring invalid --side value %q, using left\n' "$SIDE_ALIGN" >&2
		SIDE_ALIGN=left
		;;
	esac
}

get_term_accent_color() {
	local old_stty= reply= osc=12
	case $ACCENT_SRC in
	fg | foreground) osc=10 ;;
	bg | background) osc=11 ;;
	cursor) osc=12 ;;
	*)
		printf 'cetch: warning: ignoring invalid --accent value %q, using cursor\n' "$ACCENT_SRC" >&2
		osc=12
		;;
	esac

	{
		old_stty=$(stty -g < /dev/tty) &&
		stty raw -echo < /dev/tty &&
		printf '\e]%d;?\a' "$osc" > /dev/tty &&
		IFS= read -r -t 0.3 -d $'\a' reply < /dev/tty
		[[ -n $old_stty ]] && stty "$old_stty" < /dev/tty
	} 2>/dev/null

	[[ -n $reply ]] || return 1
	osc_rgb_to_hex "${reply#*rgb:}"
}

osc_rgb_to_hex() {
	local part out=
	[[ $1 =~ ^([0-9A-Fa-f]{1,4})/([0-9A-Fa-f]{1,4})/([0-9A-Fa-f]{1,4})$ ]] || return 1
	for part in "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"; do
		((${#part} == 1)) && part+=$part
		out+=${part:0:2}
	done
	printf '#%s' "$out"
}

hex_rgb() {
	local hex=${1#"#"}

	[[ $hex =~ ^([0-9A-Fa-f])([0-9A-Fa-f])([0-9A-Fa-f])$ ]] &&
		hex=${BASH_REMATCH[1]}${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}${BASH_REMATCH[3]}

	[[ $hex =~ ^[0-9A-Fa-f]{6}$ ]] || return 1

	_R8=$((16#${hex:0:2}))
	_G8=$((16#${hex:2:2}))
	_B8=$((16#${hex:4:2}))
}

rgb_to_256() {
	local r=$1 g=$2 b=$3 ri gi bi

	if ((r == g && g == b)); then
		if ((r < 8)); then
			_C256=16
		elif ((r > 248)); then
			_C256=231
		else
			_C256=$((232 + (r - 8) * 24 / 247))
		fi
		return
	fi

	ri=$((r < 48 ? 0 : r < 115 ? 1 : (r - 35) / 40))
	gi=$((g < 48 ? 0 : g < 115 ? 1 : (g - 35) / 40))
	bi=$((b < 48 ? 0 : b < 115 ? 1 : (b - 35) / 40))
	_C256=$((16 + 36 * ri + 6 * gi + bi))
}

rgb_escape() {
	if ((HAS_TRUECOLOR)); then
		printf -v _ESC '\e[38;2;%d;%d;%dm' "$1" "$2" "$3"
	elif ((NCOLORS >= 256)); then
		rgb_to_256 "$1" "$2" "$3"
		printf -v _ESC '\e[38;5;%dm' "$_C256"
	else
		printf -v _ESC '\e[%dm' $((30 + ($1 > 127) + 2 * ($2 > 127) + 4 * ($3 > 127)))
	fi
}

hex_to_escape() {
	hex_rgb "$1" || return 1
	rgb_escape "$_R8" "$_G8" "$_B8"
	printf '%s' "$_ESC"
}

setup_gradient() {
	[[ -n $GRADIENT ]] || return 0
	((USE_COLOR)) || return 0

	local s=${GRADIENT//,/-} a b
	a=${s%%-*}
	b=${s#*-}
	a=${a#\#}
	b=${b#\#}

	if [[ $s != *-* ]] || ! hex_rgb "$a"; then
		printf 'cetch: warning: ignoring invalid --gradient value %q, want A-B\n' "$GRADIENT" >&2
		return 0
	fi
	GRAD_R1=$_R8 GRAD_G1=$_G8 GRAD_B1=$_B8

	if ! hex_rgb "$b"; then
		printf 'cetch: warning: ignoring invalid --gradient value %q, want A-B\n' "$GRADIENT" >&2
		return 0
	fi
	GRAD_R2=$_R8 GRAD_G2=$_G8 GRAD_B2=$_B8

	USE_GRADIENT=1
}

grad_escape() {
	local i=$1 n=$2

	if ((n <= 1)); then
		rgb_escape "$GRAD_R1" "$GRAD_G1" "$GRAD_B1"
		return
	fi
	rgb_escape \
		$((GRAD_R1 + (GRAD_R2 - GRAD_R1) * i / (n - 1))) \
		$((GRAD_G1 + (GRAD_G2 - GRAD_G1) * i / (n - 1))) \
		$((GRAD_B1 + (GRAD_B2 - GRAD_B1) * i / (n - 1)))
}

setup_colors() {
	C_RESET=
	C_BOLD=
	C_ACCENT=

	((USE_COLOR)) || return 0

	C_RESET=$'\e[0m'
	C_BOLD=$'\e[1m'

	local origin src accent_color

	for origin in cli cfg ''; do
		for src in color accent theme; do
			[[ ${OPT_SRC[$src]:-} == "$origin" ]] || continue
			case $src in
			color)
				[[ -n $ACCENT_HEX ]] || continue
				C_ACCENT=$(hex_to_escape "$ACCENT_HEX") && return
				printf 'cetch: warning: ignoring invalid color %q, using the logo default\n' "$ACCENT_HEX" >&2
				C_ACCENT=
				;;
			accent)
				((USE_ACCENT)) || continue
				accent_color=$(get_term_accent_color)
				[[ -n $accent_color ]] && C_ACCENT=$(hex_to_escape "$accent_color") && return
				C_ACCENT=
				;;
			theme)
				[[ -n $THEME_ACCENT ]] || continue
				C_ACCENT=$(hex_to_escape "$THEME_ACCENT") && return
				C_ACCENT=
				;;
			esac
		done
	done

	if ((NCOLORS >= 256)); then
		C_ACCENT=$'\e['$LOGO_SGR'm'
	else
		C_ACCENT=$'\e['$LOGO_SGR8'm'
	fi
}


OS_ID= OS_ID_LIKE= OS_PRETTY= OS_NAME= OS_ANSI=

read_os_release() {
	local file line key val
	for file in /etc/os-release /usr/lib/os-release; do
		[[ -r $file ]] || continue
		while IFS= read -r line; do
			key=${line%%=*}
			val=${line#*=}
			[[ $key == "$line" ]] && continue
			val=${val#[\"\']}
			val=${val%[\"\']}
			case $key in
			ID) OS_ID=$val ;;
			ID_LIKE) OS_ID_LIKE=$val ;;
			PRETTY_NAME) OS_PRETTY=$val ;;
			NAME) OS_NAME=$val ;;
			ANSI_COLOR) OS_ANSI=$val ;;
			esac
		done <"$file"
		break
	done
}

distro_family() {
	local id=${CETCH_DISTRO:-$OS_ID}
	case ${id,,} in
	macos | osx | darwin) printf macos ;;
	arch | archarm | arcolinux | artix) printf arch ;;
	cachyos) printf cachyos ;;
	debian | raspbian | devuan) printf debian ;;
	ubuntu | pop | elementary | zorin | neon) printf ubuntu ;;
	fedora | nobara | rhel | centos | rocky | almalinux) printf fedora ;;
	gentoo | funtoo) printf gentoo ;;
	linuxmint | mint | lmde) printf mint ;;
	nixos) printf nixos ;;
	opensuse | opensuse-* | suse | sles | sled | tumbleweed) printf opensuse ;;
	void) printf void ;;
	alpine | postmarketos) printf alpine ;;
	manjaro | manjaro-arm) printf manjaro ;;
	'')
		if [[ $(uname -s 2>/dev/null) == Darwin ]]; then
			printf macos
		else
			printf linux
		fi
		;;
	*)
		case ${OS_ID_LIKE,,} in
		*arch*) printf arch ;;
		*ubuntu*) printf ubuntu ;;
		*debian*) printf debian ;;
		*fedora* | *rhel*) printf fedora ;;
		*gentoo*) printf gentoo ;;
		*suse*) printf opensuse ;;
		*alpine*) printf alpine ;;
		*) printf linux ;;
		esac
		;;
	esac
}

load_logo() {
	case $1 in
	arch)
		LOGO_SGR='38;5;39' LOGO_SGR8='36'
		mapfile -t LOGO <<'ART'
    /\
   .  \
  /    \
 / _/\_ .
/-'    `-\
ART
		;;
	cachyos)
		LOGO_SGR='38;5;43' LOGO_SGR8='36'
		mapfile -t LOGO <<'ART'
  ,------.
 /  ,----'
/  /
\  \
 \  `----.
  `------'
ART
		;;
	debian)
		LOGO_SGR='38;5;197' LOGO_SGR8='31'
		mapfile -t LOGO <<'ART'
  _____
 /  __ \
|  /    |
|  \___-
 -_
   --_
ART
		;;
	ubuntu)
		LOGO_SGR='38;5;208' LOGO_SGR8='33'
		mapfile -t LOGO <<'ART'
         _
   .----(_)
 _/  ---  \
(_) |   | |
   \ --- _/
    `---(_)
ART
		;;
	fedora)
		LOGO_SGR='38;5;33' LOGO_SGR8='34'
		mapfile -t LOGO <<'ART'
     __
    /  \
 __ |_
/   |
\__/
ART
		;;
	gentoo)
		LOGO_SGR='38;5;141' LOGO_SGR8='35'
		mapfile -t LOGO <<'ART'
 _-----_
(   0   \
 \      )
 /    _-
(____-
ART
		;;
	mint)
		LOGO_SGR='38;5;113' LOGO_SGR8='32'
		mapfile -t LOGO <<'ART'
 ___________
|_          \
  | |  _ _  |
  | | | | | |
  | \_____/ |
  \_________/
ART
		;;
	nixos)
		LOGO_SGR='38;5;69' LOGO_SGR8='34'
		mapfile -t LOGO <<'ART'
  \\  \\ //
 ==\\__\\/ //
   //   \\//
==//     //==
 //\\___//
// /\\  \\==
  // \\  \\
ART
		;;
	opensuse)
		LOGO_SGR='38;5;77' LOGO_SGR8='32'
		mapfile -t LOGO <<'ART'
  _______
__|   __ \
     / .\ \
     \__/ |
___  .____|
   \______/
ART
		;;
	void)
		LOGO_SGR='38;5;35' LOGO_SGR8='32'
		mapfile -t LOGO <<'ART'
   ______
 _ \____ \
| \  _  \ |
| | |_| | |
| \____ \_|
 \_____\
ART
		;;
	alpine)
		LOGO_SGR='38;5;33' LOGO_SGR8='34'
		mapfile -t LOGO <<'ART'
    /\ /\
   /  \  \
  /    \  \
 /|     \  \
/\,      \  \
ART
		;;
	manjaro)
		LOGO_SGR='38;5;35' LOGO_SGR8='32'
		mapfile -t LOGO <<'ART'
|||||||| |||
|||||||| |||
||||     |||
|||| ||| |||
|||| ||| |||
|||| ||| |||
ART
		;;
	macos)
		LOGO_SGR='38;5;255' LOGO_SGR8='37'
		mapfile -t LOGO <<'ART'
       .:
    _ :'_
 .'` `-' ``.
:        .-'
:       :
 :       `-;
  `._.-._.'
ART
		;;
	*)
		LOGO_SGR=${OS_ANSI:-'38;5;250'} LOGO_SGR8=${OS_ANSI:-'37'}
		mapfile -t LOGO <<'ART'
   .--.
  |o_o |
  |:_/ |
 //   \ \
(_)   (_)
ART
		;;
	esac
}


# replace the built-in art with a file's contents; the colour still comes
# from the detected distro (or --color), so only the shape changes
load_logo_file() {
	local f=$1 i n start=0
	local -a lines

	# the config file hands us words the shell never got to expand
	[[ $f == '~' || $f == '~/'* ]] && f=${HOME:-~}${f#'~'}

	if [[ -d $f || ! -r $f ]]; then
		printf 'cetch: warning: cannot read logo file %q, using the built-in logo\n' "$1" >&2
		return 1
	fi

	mapfile -t lines <"$f"
	for i in ${lines[@]+"${!lines[@]}"}; do
		lines[i]=${lines[i]%$'\r'}
		lines[i]=${lines[i]%%*([[:space:]])}
	done

	# trim blank lines top and bottom so the art still lines up with the box
	n=${#lines[@]}
	while ((start < n)) && [[ -z ${lines[start]} ]]; do ((start++)); done
	while ((n > start)) && [[ -z ${lines[n - 1]} ]]; do ((n--)); done

	((n > start)) || {
		printf 'cetch: warning: logo file %q has no art in it, using the built-in logo\n' "$1" >&2
		return 1
	}

	LOGO=("${lines[@]:start:n - start}")
}


# the kitty graphics protocol wants its thing in base64
b64() {
	# count bytes rather than characters, so non-ascii paths survive
	local LC_ALL=C
	local s=$1 n=${#1} i acc rem c1 c2 c3
	local t=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/

	_B64=
	for ((i = 0; i < n; i += 3)); do
		printf -v c1 '%d' "'${s:i:1}"
		c2=0 c3=0
		((i + 1 < n)) && printf -v c2 '%d' "'${s:i+1:1}"
		((i + 2 < n)) && printf -v c3 '%d' "'${s:i+2:1}"
		acc=$((c1 << 16 | c2 << 8 | c3))
		rem=$((n - i))
		_B64+=${t:acc>>18&63:1}${t:acc>>12&63:1}
		((rem > 1)) && _B64+=${t:acc>>6&63:1} || _B64+='='
		((rem > 2)) && _B64+=${t:acc&63:1} || _B64+='='
	done
}

# weird method (sending a 1x1 and checking the response)
# but how else am i supposed to do it when they could
# be using literally any terminal
query_graphics() {
	local old_stty= reply=
	{
		old_stty=$(stty -g < /dev/tty) &&
		stty raw -echo < /dev/tty &&
		printf '\e_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA\e\\' > /dev/tty &&
		IFS= read -r -t 0.3 -d '\' reply < /dev/tty
		[[ -n $old_stty ]] && stty "$old_stty" < /dev/tty
	} 2>/dev/null

	[[ $reply == *';OK'* ]]
}

head_bytes() {
	local want=$1 LC_ALL=C chunk i n v more=1

	BYTES=()
	while ((${#BYTES[@]} < want && more)); do
		IFS= read -r -d '' chunk || more=0
		n=${#chunk}
		for ((i = 0; i < n && ${#BYTES[@]} < want; i++)); do
			printf -v v '%d' "'${chunk:i:1}"
			BYTES+=("$v")
		done
		((more && ${#BYTES[@]} < want)) && BYTES+=(0)
	done
}

png_info() {
	local IFS=' '

	head_bytes 24 <"$1"
	((${#BYTES[@]} >= 24)) || return 1
	[[ "${BYTES[*]:0:8}" == '137 80 78 71 13 10 26 10' ]] || return 1
	[[ "${BYTES[*]:12:4}" == '73 72 68 82' ]] || return 1

	PNG_W=$((BYTES[16] << 24 | BYTES[17] << 16 | BYTES[18] << 8 | BYTES[19]))
	PNG_H=$((BYTES[20] << 24 | BYTES[21] << 16 | BYTES[22] << 8 | BYTES[23]))
	((PNG_W > 0 && PNG_H > 0))
}

query_cell_size() {
	local old_stty= reply=

	[[ -t 1 ]] || return 1
	{
		old_stty=$(stty -g < /dev/tty) &&
		stty raw -echo < /dev/tty &&
		printf '\e[16t' > /dev/tty &&
		IFS= read -r -t 0.3 -d t reply < /dev/tty
		[[ -n $old_stty ]] && stty "$old_stty" < /dev/tty
	} 2>/dev/null

	[[ $reply =~ 6\;([0-9]+)\;([0-9]+) ]] || return 1
	((BASH_REMATCH[1] > 0 && BASH_REMATCH[2] > 0)) || return 1
	CELL_H=${BASH_REMATCH[1]} CELL_W=${BASH_REMATCH[2]}
}

size_image() {
	local cols= rows= cap

	if [[ ${IMAGE_SIZE,,} == auto ]]; then
		:
	elif [[ $IMAGE_SIZE == +([0-9]) ]]; then
		cols=$IMAGE_SIZE
	elif [[ $IMAGE_SIZE =~ ^([0-9]+)[xX]([0-9]+)$ ]]; then
		cols=${BASH_REMATCH[1]}
		rows=${BASH_REMATCH[2]}
	else
		printf 'cetch: warning: ignoring invalid image size %q, using auto\n' "$IMAGE_SIZE" >&2
	fi

	[[ -n $cols ]] || cols=$IMAGE_COLS
	((cols < 1)) && cols=1
	((cols > COLS)) && cols=$COLS

	if [[ -z $rows ]]; then
		query_cell_size
		rows=$(((cols * CELL_W * PNG_H + PNG_W * CELL_H - 1) / (PNG_W * CELL_H)))
	fi

	cap=$((LINES_T - 12))
	((cap < 4)) && cap=4
	((rows > cap)) && rows=$cap
	((rows < 1)) && rows=1

	IMAGE_COLS=$cols IMAGE_ROWS=$rows
}

term_has_graphics() {
	# escape codes only belong on a terminal, never in a pipe or a file
	[[ -t 1 ]] || return 1
	[[ ${TERM:-dumb} == dumb ]] && return 1

	# the ones we can spot for free, so the common case skips the probe
	[[ -n ${KITTY_WINDOW_ID:-}${GHOSTTY_RESOURCES_DIR:-}${WEZTERM_PANE:-}${KONSOLE_VERSION:-} ]] && return 0
	case ${TERM:-}:${TERM_PROGRAM:-} in
	*kitty* | *ghostty* | *Ghostty* | *WezTerm* | *rio* | *konsole*) return 0 ;;
	esac

	query_graphics
}

setup_image() {
	[[ -n $IMAGE_FILE ]] || return 0
	# --no-logo asked for nothing in that spot, do it
	((USE_LOGO)) || return 0

	local f=$IMAGE_FILE
	# the config file hands us words the shell never got to expand
	[[ $f == '~' || $f == '~/'* ]] && f=${HOME:-~}${f#'~'}
	# the terminal opens this path itself, and its cwd is not ours
	[[ $f == /* ]] || f=$PWD/$f

	if [[ -d $f || ! -r $f ]]; then
		printf 'cetch: warning: cannot read image file %q, using the built-in logo\n' "$IMAGE_FILE" >&2
		return 0
	fi

	if ! png_info "$f"; then
		printf 'cetch: warning: %q is not a PNG, using the built-in logo\n' "$IMAGE_FILE" >&2
		return 0
	fi
	IMAGE_FILE=$f

	if [[ -n ${SSH_CONNECTION:-}${SSH_CLIENT:-}${SSH_TTY:-} ]]; then
		USE_LOGO=0
		IMAGE_SSH=1
		return 0
	fi

	# an image always replaces the ascii art. if the terminal cannot draw
	# it we drop the logo anyway and complain once the fetch is done,
	# rather than silently falling back to art the user did not ask for
	if term_has_graphics; then
		SHOW_IMAGE=1
		size_image
	else
		USE_LOGO=0
		IMAGE_WARN=1
	fi
}


get_user() {
	local user=${USER:-${LOGNAME:-}} host=
	[[ -n $user ]] || user=$(id -un 2>/dev/null)
	[[ -r /proc/sys/kernel/hostname ]] && read -r host </proc/sys/kernel/hostname
	printf '%s@%s' "${user:-unknown}" "${host:-${HOSTNAME:-localhost}}"
}

get_kernel() {
	local k=
	[[ -r /proc/sys/kernel/osrelease ]] && read -r k </proc/sys/kernel/osrelease
	printf '%s' "${k:-$(uname -r 2>/dev/null)}"
}

get_os() {
	if [[ -z $OS_PRETTY && -z $OS_NAME && $(uname -s 2>/dev/null) == Darwin ]]; then
		local ver=
		hash sw_vers 2>/dev/null && ver=$(sw_vers -productVersion 2>/dev/null)
		printf 'macOS%s %s' "${ver:+ $ver}" "${HOSTTYPE:-$(uname -m)}"
		return
	fi
	printf '%s %s' "${OS_PRETTY:-${OS_NAME:-Linux}}" "${HOSTTYPE:-$(uname -m)}"
}

get_wm() {
	local wm= name

	if [[ -n ${XDG_CURRENT_DESKTOP:-} ]]; then
		wm=${XDG_CURRENT_DESKTOP##*:}
		wm=${wm#X-}
	elif [[ -n ${DESKTOP_SESSION:-} ]]; then
		wm=${DESKTOP_SESSION##*/}
	fi

	if [[ -z $wm ]]; then
		# guess from /proc
		local w
		local known=' hyprland sway river niri wayfire labwc dwl weston
			cosmic-comp i3 bspwm dwm awesome openbox xmonad qtile spectrwm
			herbstluftwm fluxbox icewm jwm cwm leftwm 2bwm ratpoison
			kwin_wayland kwin_x11 kwin gnome-shell mutter xfwm4 marco muffin
			budgie-wm enlightenment '
		for w in /proc/[0-9]*/comm; do
			read -r name <"$w" 2>/dev/null || continue
			[[ -n $name ]] || continue
			if [[ $known == *[[:space:]]"$name"[[:space:]]* ]]; then
				wm=$name
				break
			fi
		done
	fi

	case ${wm,,} in
	hyprland) wm=Hyprland ;;
	sway) wm=Sway ;;
	river) wm=River ;;
	kwin* | kde | plasma*) wm='KDE Plasma' ;;
	gnome-shell | gnome | mutter) wm=GNOME ;;
	xfwm4 | xfce) wm=Xfce ;;
	muffin | cinnamon) wm=Cinnamon ;;
	marco | mate) wm=MATE ;;
	budgie*) wm=Budgie ;;
	esac

	[[ -n ${XDG_SESSION_TYPE:-} && -n $wm ]] &&
		case $XDG_SESSION_TYPE in
		wayland) wm+=' (Wayland)' ;;
		x11) wm+=' (X11)' ;;
		esac

	printf '%s' "${wm:-unknown}"
}

get_packages() {
	local -a d
	local out= n

	d=(/var/lib/pacman/local/*/)
	((${#d[@]})) && out+="${out:+, }${#d[@]} (pacman)"

	d=(/var/db/pkg/*/*/)
	((${#d[@]})) && out+="${out:+, }${#d[@]} (portage)"

	if [[ -r /var/lib/dpkg/status ]] && hash dpkg-query 2>/dev/null; then
		# only count installed packages
		n=$(dpkg-query -f '${db:Status-Abbrev}\n' -W 2>/dev/null | grep -c '^ii')
		((n)) && out+="${out:+, }$n (dpkg)"
	fi

	if [[ -d /var/lib/rpm ]] && hash rpm 2>/dev/null; then
		n=$(rpm -qa 2>/dev/null | wc -l)
		((n)) && out+="${out:+, }$n (rpm)"
	fi

	if [[ -r /lib/apk/db/installed ]]; then
		n=$(grep -c '^P:' /lib/apk/db/installed 2>/dev/null)
		((n)) && out+="${out:+, }$n (apk)"
	fi

	if hash xbps-query 2>/dev/null; then
		n=$(xbps-query -l 2>/dev/null | wc -l)
		((n)) && out+="${out:+, }$n (xbps)"
	fi

	d=(/var/lib/flatpak/app/*/ "${HOME:-}"/.local/share/flatpak/app/*/)
	((${#d[@]})) && out+="${out:+, }${#d[@]} (flatpak)"

	d=(/opt/homebrew/Cellar/*/ /usr/local/Cellar/*/ /opt/homebrew/Caskroom/*/ /usr/local/Caskroom/*/ /home/linuxbrew/.linuxbrew/Cellar/*/)
	((${#d[@]})) && out+="${out:+, }${#d[@]} (brew)"

        d=(/nix/store/*/)
        ((${#d[@]})) && out+="${out:+, }${#d[@]} (nix)"

	printf '%s' "${out:-unknown}"
}

get_disk() {
	local size used pcent
	{
		read -r _
		read -r _ size used _ pcent _
	} < <(df -hP "$DISK_MOUNT" 2>/dev/null)
	[[ -n ${size:-} ]] || {
		printf 'unknown'
		return
	}
	printf '%s / %s (%s)' "$used" "$size" "$pcent"
}

get_uptime() {
	local secs= d h m out=
	[[ -r /proc/uptime ]] && read -r secs _ </proc/uptime
	[[ -n $secs ]] || {
		printf 'unknown'
		return
	}
	secs=${secs%.*}
	d=$((secs / 86400))
	h=$((secs % 86400 / 3600))
	m=$((secs % 3600 / 60))
	((d)) && out+="${d}d "
	((d || h)) && out+="${h}h "
	printf '%s' "$out${m}m"
}

get_shell() {
	local sh=${SHELL:-}
	sh=${sh##*/}
	printf '%s' "${sh:-unknown}"
}

fmt_kib() {
	if (($1 >= 1048576)); then
		printf '%d.%dG' $(($1 / 1048576)) $(($1 % 1048576 * 10 / 1048576))
	elif (($1 >= 1024)); then
		printf '%dM' $(($1 / 1024))
	else
		printf '%dK' "$1"
	fi
}

get_memory() {
	local key val total=0 avail=0 free=0 used
	[[ -r /proc/meminfo ]] || {
		printf 'unknown'
		return
	}
	while IFS=': ' read -r key val _; do
		case $key in
		MemTotal) total=$val ;;
		MemAvailable) avail=$val ;;
		MemFree) free=$val ;;
		esac
	done </proc/meminfo
	((total)) || {
		printf 'unknown'
		return
	}
	((avail)) || avail=$free
	used=$((total - avail))
	printf '%s / %s (%d%%)' "$(fmt_kib "$used")" "$(fmt_kib "$total")" $((used * 100 / total))
}

get_cpu() {
	local line model= cores=0
	[[ -r /proc/cpuinfo ]] || {
		printf 'unknown'
		return
	}
	while IFS= read -r line; do
		case $line in
		processor*) ((cores++)) ;;
		'model name'* | Model* | Hardware*)
			[[ -n $model ]] || model=${line#*: }
			;;
		esac
	done </proc/cpuinfo
	model=${model//'(R)'/}
	model=${model//'(TM)'/}
	model=${model//'(tm)'/}
	model=${model// CPU/}
	model=${model//+([[:space:]])/ }
	model=${model# }
	model=${model% }
	[[ -n $model ]] || model=unknown
	((cores)) && model+=" (${cores})"
	printf '%s' "$model"
}

get_temp() {
	local raw= sign=
	[[ -r $TEMP_FILE ]] && read -r raw <"$TEMP_FILE" 2>/dev/null
	[[ $raw == ?(-)+([0-9]) ]] || {
		printf 'unknown'
		return
	}
	# sysfs reports millidegrees
	((raw < 0)) && {
		sign=-
		raw=$((-raw))
	}
	printf '%s%d.%d°C' "$sign" $((raw / 1000)) $((raw % 1000 / 100))
}

get_ip() {
	local name dest iface= addr=
	if [[ -r /proc/net/route ]]; then
		while read -r name dest _; do
			[[ $dest == 00000000 ]] && {
				iface=$name
				break
			}
		done </proc/net/route
	fi

	if hash ip 2>/dev/null; then
		if [[ -n $iface ]]; then
			addr=$(ip -4 -o addr show dev "$iface" scope global 2>/dev/null)
		else
			addr=$(ip -4 -o addr show scope global 2>/dev/null)
		fi
		if [[ $addr == *' inet '* ]]; then
			addr=${addr#* inet }
			addr=${addr%%/*}
		else
			addr=
		fi
	fi

	if [[ -z $addr ]] && hash hostname 2>/dev/null; then
		read -r addr _ < <(hostname -I 2>/dev/null)
	fi

	printf '%s' "${addr:-unknown}"
} # finally

get_swap() {
	local key val total=0 free=0 used
	[[ -r /proc/meminfo ]] || {
		printf 'unknown'
		return
	}
	while IFS=': ' read -r key val _; do
		case $key in
		SwapTotal) total=$val ;;
		SwapFree) free=$val ;;
		esac
	done </proc/meminfo
	((total)) || {
		printf 'none'
		return
	}
	used=$((total - free))
	printf '%s / %s (%d%%)' "$(fmt_kib "$used")" "$(fmt_kib "$total")" $((used * 100 / total))
}

fmt_khz() {
	printf '%d.%dGHz' $(($1 / 1000000)) $(($1 % 1000000 / 100000))
}

get_cpufreq() {
	local base=/sys/devices/system/cpu/cpu0/cpufreq cur= max=
	[[ -r $base/scaling_cur_freq ]] && read -r cur <"$base/scaling_cur_freq" 2>/dev/null
	[[ -r $base/scaling_max_freq ]] && read -r max <"$base/scaling_max_freq" 2>/dev/null

	[[ $cur == +([0-9]) ]] || cur=
	[[ $max == +([0-9]) ]] || max=

	if [[ -n $cur && -n $max ]]; then
		printf '%s / %s' "$(fmt_khz "$cur")" "$(fmt_khz "$max")"
	elif [[ -n $max ]]; then
		fmt_khz "$max"
	elif [[ -n $cur ]]; then
		fmt_khz "$cur"
	else
		printf 'unknown'
	fi
}

find_pci_ids() {
	local f
	for f in /usr/share/hwdata/pci.ids /usr/share/misc/pci.ids /usr/share/pci.ids; do
		[[ -r $f ]] && {
			PCI_IDS=$f
			return 0
		}
	done
	PCI_IDS=
}

pci_vendor_name() {
	case ${1,,} in
	0x8086) printf Intel ;;
	0x1002 | 0x1022) printf AMD ;;
	0x10de) printf NVIDIA ;;
	0x1a03) printf ASPEED ;;
	0x102b) printf Matrox ;;
	0x15ad) printf VMware ;;
	0x1234 | 0x1b36) printf QEMU ;;
	0x80ee) printf VirtualBox ;;
	0x1af4) printf Virtio ;;
	0x5333) printf S3 ;;
	*) printf '%s' "${1#0x}" ;;
	esac
}

pci_device_name() {
	local ven=${1#0x} dev=${2#0x} line seen=0 name

	[[ -n $PCI_IDS ]] || return 1
	while IFS= read -r line; do
		[[ -z $line || $line == '#'* ]] && continue
		if [[ $line != $'\t'* ]]; then
			((seen)) && return 1
			[[ ${line%% *} == "$ven" ]] && seen=1
			continue
		fi
		((seen)) || continue
		[[ $line == $'\t\t'* ]] && continue
		line=${line#$'\t'}
		if [[ ${line%% *} == "$dev" ]]; then
			name=${line#* }
			name=${name## }
			[[ $name == *'['*']'* ]] && {
				name=${name#*[}
				name=${name%%]*}
			}
			printf '%s' "$name"
			return 0
		fi
	done <"$PCI_IDS"
	return 1
}

get_gpu() {
	local d cls ven dev out= brand model

	for d in /sys/bus/pci/devices/*/; do
		[[ -r $d/class && -r $d/vendor && -r $d/device ]] || continue
		read -r cls <"$d/class"
		[[ $cls == 0x03* ]] || continue
		read -r ven <"$d/vendor"
		read -r dev <"$d/device"
		brand=$(pci_vendor_name "$ven")
		model=$(pci_device_name "$ven" "$dev") || model=${dev#0x}
		out+="${out:+, }$brand $model"
	done

	printf '%s' "${out:-unknown}"
}

get_resolution() {
	local f e mode out=

	for f in /sys/class/drm/*/enabled; do
		read -r e <"$f" 2>/dev/null || continue
		[[ $e == enabled ]] || continue
		[[ -s ${f%/enabled}/modes ]] || continue
		read -r mode <"${f%/enabled}/modes" 2>/dev/null || continue
		[[ -n $mode ]] && out+="${out:+, }$mode"
	done

	printf '%s' "${out:-unknown}"
}

get_terminal() {
	local t= pid=$PPID comm key val i

	[[ -n ${KITTY_WINDOW_ID:-} ]] && t=kitty
	[[ -n ${WEZTERM_PANE:-} ]] && t=WezTerm
	[[ -n ${GHOSTTY_RESOURCES_DIR:-} ]] && t=Ghostty
	[[ -n ${KONSOLE_VERSION:-} ]] && t=Konsole
	[[ -n ${ALACRITTY_WINDOW_ID:-} ]] && t=Alacritty
	[[ -z $t && -n ${TERM_PROGRAM:-} ]] && t=$TERM_PROGRAM

	if [[ -z $t ]]; then
		for ((i = 0; i < 12; i++)); do
			[[ -r /proc/$pid/comm ]] || break
			read -r comm </proc/$pid/comm
			case $comm in
			bash | zsh | fish | sh | dash | ksh | tcsh | csh | cetch | su | sudo | login | script) ;;
			*)
				t=$comm
				break
				;;
			esac
			val=
			while IFS=$': \t' read -r key val _; do
				[[ $key == PPid ]] && break
				val=
			done </proc/$pid/status 2>/dev/null
			[[ $val == +([0-9]) ]] && ((val > 1)) || break
			pid=$val
		done
	fi

	printf '%s' "${t:-${TERM:-unknown}}"
}

get_load() {
	local a b c
	[[ -r /proc/loadavg ]] || {
		printf 'unknown'
		return
	}
	read -r a b c _ </proc/loadavg
	printf '%s, %s, %s' "$a" "$b" "$c"
}

get_procs() {
	local runq
	[[ -r /proc/loadavg ]] || {
		printf 'unknown'
		return
	}
	read -r _ _ _ runq _ </proc/loadavg
	printf '%s' "${runq#*/}"
}

get_init() {
	local c=
	[[ -r /proc/1/comm ]] && read -r c </proc/1/comm 2>/dev/null
	printf '%s' "${c:-unknown}"
}

ICONS=() LABELS=() VALUES=()

row() {
	ICONS+=("$1")
	LABELS+=("$2")
	VALUES+=("$3")
}

add_row() {
	case $1 in
	user) row "$ICON_USER" User "$(get_user)" ;;
	kernel) row "$ICON_KERNEL" Kernel "$(get_kernel)" ;;
	os) row "$ICON_OS" OS "$(get_os)" ;;
	wm | wm/de | de) row "$ICON_WM" WM/DE "$(get_wm)" ;;
	battery | batt) row "$ICON_BATTERY" Battery "$(get_battery)" ;;
	packages | pkgs) row "$ICON_PKG" Packages "$(get_packages)" ;;
	disk) row "$ICON_DISK" Disk "$(get_disk)" ;;
	uptime) row "$ICON_UPTIME" Uptime "$(get_uptime)" ;;
	shell) row "$ICON_SHELL" Shell "$(get_shell)" ;;
	memory | mem | ram) row "$ICON_MEM" Memory "$(get_memory)" ;;
	cpu) row "$ICON_CPU" CPU "$(get_cpu)" ;;
	temp | temperature | cputemp) row "$ICON_TEMP" Temp "$(get_temp)" ;;
	ip | localip) row "$ICON_IP" 'Local IP' "$(get_ip)" ;;
	swap) row "$ICON_SWAP" Swap "$(get_swap)" ;;
	cpufreq | freq) row "$ICON_FREQ" 'CPU Freq' "$(get_cpufreq)" ;;
	gpu) row "$ICON_GPU" GPU "$(get_gpu)" ;;
	resolution | res | display) row "$ICON_RES" Resolution "$(get_resolution)" ;;
	terminal | term) row "$ICON_TERM" Terminal "$(get_terminal)" ;;
	load | loadavg) row "$ICON_LOAD" Load "$(get_load)" ;;
	procs | processes) row "$ICON_PROCS" Processes "$(get_procs)" ;;
	init) row "$ICON_INIT" Init "$(get_init)" ;;
	'') ;;
	*) printf 'cetch: warning: skipping unknown row %q (try --help)\n' "$1" >&2 ;;
	esac
}

collect_info() {
	local key
	local -a want
	IFS=', ' read -r -a want <<<"$ROWS"
	for key in ${want[@]+"${want[@]}"}; do
		add_row "${key,,}"
	done
}


LOGO_LINES=() BOX_LINES=() LOGO_W=0 BOX_W=0 IMG_UP=0 IMG_PAD=0

print_block() {
	local w=$1 pad line
	shift
	pad=$(((COLS - w) / 2))
	((pad < 0)) && pad=0
	for line in "$@"; do
		printf '%*s%s\n' "$pad" '' "$line"
	done
}

build_logo_lines() {
	local i n=${#LOGO[@]} col
	LOGO_LINES=()
	LOGO_W=0
	for ((i = 0; i < n; i++)); do
		# a --logo-file can be any width, so keep it inside the terminal
		_fit "${LOGO[i]}" "$COLS"
		col=$C_ACCENT
		if ((USE_GRADIENT)); then
			grad_escape "$i" "$n"
			col=$_ESC
		fi
		LOGO_LINES+=("$C_BOLD$col$_S$C_RESET")
		vwidth "$_S"
		((_W > LOGO_W)) && LOGO_W=$_W
	done
}

# an image is not made of text, so stand in for it with the right number
# of empty lines: every bit of centering and side-by-side maths below then
# reserves the space for free, and place_image draws into the hole after
build_image_lines() {
	local i
	LOGO_LINES=()
	LOGO_W=$IMAGE_COLS
	for ((i = 0; i < IMAGE_ROWS; i++)); do LOGO_LINES+=(''); done
}

# no borders: the title on its own line, then the rows with their values
# left-aligned in one column instead of pushed out to a right edge
build_plain_lines() {
	local maxw=$1
	local i n=${#LABELS[@]} icon_w=0 labelw=0 avail lw
	local icon label value line

	BOX_LINES=()
	BOX_W=0

	((USE_ICONS)) && icon_w=$((ICON_CELLS + 2))

	for ((i = 0; i < n; i++)); do
		[[ -n ${VALUES[i]} ]] || continue
		vwidth "${LABELS[i]}"
		((_W > labelw)) && labelw=$_W
	done

	avail=$((maxw - icon_w - labelw - LABEL_GAP))
	((avail < 1)) && avail=1

	_fit "$BOX_TITLE" "$maxw"
	printf -v line '%s%s%s%s' "$C_BOLD" "$C_ACCENT" "$_S" "$C_RESET"
	BOX_LINES+=("$line")
	vwidth "$_S"
	BOX_W=$_W

	for ((i = 0; i < n; i++)); do
		label=${LABELS[i]} value=${VALUES[i]} icon=${ICONS[i]}
		[[ -n $value ]] || continue

		_fit "$value" "$avail"
		value=$_S
		vwidth "$label"
		lw=$_W
		_rep ' ' $((labelw - lw + LABEL_GAP))

		printf -v line '%s' "$C_ACCENT"
		((USE_ICONS)) && printf -v line '%s%s  ' "$line" "$icon"
		printf -v line '%s%s%s%s%s%s' \
			"$line" "$label" "$_R" "$C_RESET$C_BOLD" "$value" "$C_RESET"
		BOX_LINES+=("$line")

		vwidth "$value"
		((icon_w + labelw + LABEL_GAP + _W > BOX_W)) &&
			BOX_W=$((icon_w + labelw + LABEL_GAP + _W))
	done
}

build_box_lines() {
	local maxw=$1
	local i n=${#LABELS[@]} icon_w=0 inner=0 need tw lw vw gap
	local icon label value line

	if [[ $STYLE == plain ]]; then
		build_plain_lines "$maxw"
		return
	fi

	BOX_LINES=()

	((USE_ICONS)) && icon_w=$((ICON_CELLS + 2))

	for ((i = 0; i < n; i++)); do
		[[ -n ${VALUES[i]} ]] || continue
		vwidth "${LABELS[i]}"
		lw=$_W
		vwidth "${VALUES[i]}"
		need=$((2 + icon_w + lw + LABEL_GAP + _W))
		((need > inner)) && inner=$need
	done

	vwidth "$BOX_TITLE"
	tw=$_W
	((inner < TITLE_DASHES + tw + 3)) && inner=$((TITLE_DASHES + tw + 3))
	((inner < BOX_MIN_WIDTH - 2)) && inner=$((BOX_MIN_WIDTH - 2))
	((inner < 12)) && inner=12
	((inner > maxw - 2)) && inner=$((maxw - 2))

	local title
	_fit "$BOX_TITLE" $((inner - TITLE_DASHES - 3))
	title=$_S
	vwidth "$title"
	tw=$_W

	_rep "$B_H" "$TITLE_DASHES"
	local top=$_R
	_rep "$B_H" $((inner - TITLE_DASHES - tw - 2))
	printf -v line '%s%s%s %s%s%s %s%s%s' \
		"$C_ACCENT" "$B_TL" "$top" \
		"$C_BOLD" "$title" "$C_RESET$C_ACCENT" \
		"$_R" "$B_TR" "$C_RESET"
	BOX_LINES+=("$line")

	for ((i = 0; i < n; i++)); do
		label=${LABELS[i]} value=${VALUES[i]} icon=${ICONS[i]}
		[[ -n $value ]] || continue

		_fit "$label" $((inner - 2 - icon_w - LABEL_GAP - 1))
		label=$_S
		vwidth "$label"
		lw=$_W
		_fit "$value" $((inner - 2 - icon_w - lw - LABEL_GAP))
		value=$_S
		vwidth "$value"
		vw=$_W

		gap=$((inner - 2 - icon_w - lw - vw))
		((gap < 0)) && gap=0
		_rep ' ' "$gap"

		printf -v line '%s%s ' "$C_ACCENT" "$B_V"
		((USE_ICONS)) && printf -v line '%s%s  ' "$line" "$icon"
		printf -v line '%s%s%s%s%s%s %s%s%s' \
			"$line" "$label" "$_R" "$C_RESET$C_BOLD" "$value" "$C_RESET" \
			"$C_ACCENT" "$B_V" "$C_RESET"
		BOX_LINES+=("$line")
	done

	_rep "$B_H" "$inner"
	printf -v line '%s%s%s%s%s' "$C_ACCENT" "$B_BL" "$_R" "$B_BR" "$C_RESET"
	BOX_LINES+=("$line")

	BOX_W=$((inner + 2))
}

render_side() {
	local i ln=${#LOGO_LINES[@]} bn=${#BOX_LINES[@]}
	local n pad ltop btop li bi lpart bpart lw

	n=$((ln > bn ? ln : bn))
	ltop=$(((n - ln) / 2))
	btop=$(((n - bn) / 2))
	pad=$(((COLS - LOGO_W - LOGO_GAP - BOX_W) / 2))
	((pad < 0)) && pad=0

	for ((i = 0; i < n; i++)); do
		li=$((i - ltop))
		bi=$((i - btop))
		lpart= bpart=
		((li >= 0 && li < ln)) && lpart=${LOGO_LINES[li]}
		((bi >= 0 && bi < bn)) && bpart=${BOX_LINES[bi]}
		if [[ $SIDE_ALIGN == right ]]; then
			if [[ -z $lpart ]]; then
				printf '%*s%s\n' "$pad" '' "$bpart"
			else
				vwidth "$bpart"
				lw=$_W
				printf '%*s%s%*s%s\n' "$pad" '' "$bpart" $((BOX_W - lw + LOGO_GAP)) '' "$lpart"
			fi
		elif [[ -z $bpart ]]; then
			printf '%*s%s\n' "$pad" '' "$lpart"
		else
			vwidth "$lpart"
			lw=$_W
			printf '%*s%s%*s%s\n' "$pad" '' "$lpart" $((LOGO_W - lw + LOGO_GAP)) '' "$bpart"
		fi
	done

	# hand place_image the top-left corner of the logo column, counted
	# back from where this left the cursor
	IMG_UP=$((n - ltop))
	if [[ $SIDE_ALIGN == right ]]; then
		IMG_PAD=$((pad + BOX_W + LOGO_GAP))
	else
		IMG_PAD=$pad
	fi
}

# draw the image into the blank rows that were just printed.
place_image() {
	local up=$1 pad=$2
	((pad < 0)) && pad=0

	b64 "$IMAGE_FILE"
	((up)) && printf '\e[%dA' "$up"
	printf '\r'
	((pad)) && printf '\e[%dC' "$pad"
	printf '\e_Ga=T,f=100,t=f,c=%d,r=%d,C=1,q=2;%s\e\\' \
		"$IMAGE_COLS" "$IMAGE_ROWS" "$_B64"
	printf '\r'
	((up)) && printf '\e[%dB' "$up"
	return 0
}

render_palette() {
	local i sw line= gap=$DOT_GAP swatch=$DOT n=$PALETTE_N idx
	local -a pal=()

	[[ $PALETTE == none ]] && return 0
	# blocks butt up against each other to read as one continuous bar
	[[ $PALETTE == blocks ]] && swatch=$BLOCK gap=

	((USE_COLOR)) && [[ -n $THEME_PAL ]] && read -ra pal <<<"$THEME_PAL"

	vwidth "$swatch"
	sw=$_W
	while ((${#gap} > 0 && n * sw + (n - 1) * ${#gap} > COLS)); do gap=${gap:1}; done
	for ((i = 0; i < n; i++)); do
		((n == 8)) && idx=$((i + 8)) || idx=$i
		if ((${#pal[@]} >= 16)) && hex_rgb "${pal[idx]}"; then
			rgb_escape "$_R8" "$_G8" "$_B8"
			line+=$_ESC$swatch$C_RESET
		elif ((NCOLORS >= 16)); then
			line+=$'\e[38;5;'$idx'm'$swatch$C_RESET
		elif ((USE_COLOR)); then
			line+=$'\e[1;3'$((idx % 8))'m'$swatch$C_RESET
		else
			line+=$swatch
		fi
		((i < n - 1)) && line+=$gap
	done
	center "$line" $((n * sw + (n - 1) * ${#gap}))
}

json_str() {
	local s=$1
	s=${s//\\/\\\\}
	s=${s//\"/\\\"}
	s=${s//$'\t'/\\t}
	s=${s//$'\n'/\\n}
	s=${s//$'\r'/\\r}
	_J=\"$s\"
}

render_json() {
	local i n=${#LABELS[@]} first=1 key

	printf '{\n'
	json_str "$BOX_TITLE"
	printf '  "title": %s,\n  "rows": [\n' "$_J"
	for ((i = 0; i < n; i++)); do
		[[ -n ${VALUES[i]} ]] || continue
		((first)) || printf ',\n'
		first=0
		key=${LABELS[i],,}
		key=${key//[^a-z0-9]/_}
		json_str "$key"
		printf '    {"key": %s, ' "$_J"
		json_str "${LABELS[i]}"
		printf '"label": %s, ' "$_J"
		json_str "${VALUES[i]}"
		printf '"value": %s}' "$_J"
	done
	((first)) || printf '\n'
	printf '  ]\n}\n'
}


main() {
	PARSE_SRC=cfg
	parse_args ${CONFIG_ARGS[@]+"${CONFIG_ARGS[@]}"}
	PARSE_SRC=cli
	parse_args "$@"
	resolve_conflicts
	setup_style
	setup_term
	read_os_release
	find_pci_ids

	if ((OUT_JSON)); then
		collect_info
		render_json
		return 0
	fi

	[[ -n $THEME ]] && load_theme "$THEME"
	load_logo "$(distro_family)"
	[[ -n $LOGO_FILE ]] && load_logo_file "$LOGO_FILE"
	setup_colors
	setup_gradient
	collect_info

	setup_image

	((USE_LOGO)) || SIDE=0
	((SIDE)) && LOGO_GAP=$((LOGO_GAP + SIDE_PAD))
	if ((SHOW_IMAGE)); then
		build_image_lines
	elif ((USE_LOGO)); then
		build_logo_lines
	fi
	((SIDE && COLS - LOGO_W - LOGO_GAP < SIDE_MIN_BOX)) && SIDE=0

	blank 1
	if ((SIDE)); then
		build_box_lines $((COLS - LOGO_W - LOGO_GAP))
		render_side
		((SHOW_IMAGE)) && place_image "$IMG_UP" "$IMG_PAD"
	else
		if ((USE_LOGO)); then
			print_block "$LOGO_W" "${LOGO_LINES[@]}"
			((SHOW_IMAGE)) && place_image "$IMAGE_ROWS" $(((COLS - LOGO_W) / 2))
			blank "$BLANK_AFTER_LOGO"
		fi
		build_box_lines "$COLS"
		print_block "$BOX_W" "${BOX_LINES[@]}"
	fi
	if [[ $PALETTE != none ]]; then
		blank "$BLANK_BEFORE_DOTS"
		render_palette
	fi
	blank 1

	((IMAGE_WARN)) &&
		printf 'cetch: Please use a compatible terminal to show images! compatible terminals: %s\n' \
			"$GFX_TERMS" >&2

	((IMAGE_SSH)) &&
		printf 'cetch: images cannot be shown over SSH, the terminal reads the file itself and cannot reach %q\n' \
			"$IMAGE_FILE" >&2

	return 0
}

main "$@"
