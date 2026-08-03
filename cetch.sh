#!/usr/bin/env bash
((BASH_VERSINFO[0] >= 4)) || { echo "cetch: needs bash 4.0+, found $BASH_VERSION" >&2; exit 1; }
set -u
shopt -s extglob
shopt -s nullglob

# ~/.config/cetch/cetch.conf: lines are either "CETCH_VAR=value" (applied
# only if that variable isn't already set in the environment) or anything
# else, which is tokenized and treated as if typed on the command line
# (ahead of the real argv, so real flags still win).
CONFIG_DIR=${XDG_CONFIG_HOME:-${HOME:-}/.config}/cetch
CONFIG_FILE=$CONFIG_DIR/cetch.conf
CONFIG_ARGS=()

# seed a commented starter config the first time cetch runs, so the image
# options (and everything else) are discoverable without reading the manpage
ensure_config() {
	[[ -e $CONFIG_FILE ]] && return 0
	[[ -n ${HOME:-} ]] || return 0

	mkdir -p -- "$CONFIG_DIR" 2>/dev/null || return 0
	# re-check in case we lost a race with another cetch
	[[ -e $CONFIG_FILE ]] && return 0

	cat >"$CONFIG_FILE" <<'CONF'
# cetch configuration
#
# Each line is either:
#   CETCH_VAR=value   (only applied if that variable is not already set)
#   a flag            (as if typed on the command line, before real argv)
# Blank lines and lines starting with # are ignored.
#
# Hierarchy (most favoured → least): terminal flags, flag lines here,
# exported CETCH_* in your shell, CETCH_* lines here, then defaults.

# --- Image logo (optional) ---
# Uncomment one of these to replace the ASCII logo with an image.
# Needs chafa (https://hpjansson.org/chafa/); without it cetch falls
# back to the ASCII logo and prints a warning.
#
# Built-in image for your detected distro (from DistroLogos/):
# CETCH_IMAGE=auto
#
# Or any image file you like (png, webp, jpg, gif, …):
# CETCH_IMAGE=~/Pictures/my-logo.png
#
# Width in terminal cells (height follows the aspect ratio, default 24):
# CETCH_IMAGE_SIZE=24

# --- Common knobs ---
# CETCH_TITLE=System Info
# CETCH_ROWS=user,kernel,os,wm,packages,disk
# CETCH_COLOR=7aa2f7
# --style rounded
# --palette dots
CONF
}

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
			[[ -v "$key" ]] || export "$key=$val"
		else
			read -ra words <<<"$line"
			((${#words[@]})) && CONFIG_ARGS+=("${words[@]}")
		fi
	done <"$CONFIG_FILE"
}

ensure_config
load_config

BOX_TITLE=${CETCH_TITLE:-System Info}
BOX_MIN_WIDTH=${CETCH_MIN_WIDTH:-42}
LABEL_GAP=2
TITLE_DASHES=2
DISK_MOUNT=${CETCH_DISK:-/}
USE_ACCENT=0
ACCENT_HEX=${CETCH_COLOR:-}

DEFAULT_ROWS=user,kernel,os,wm,packages,disk
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

TEMP_FILE=${CETCH_TEMP_ZONE:-/sys/class/thermal/thermal_zone0/temp}

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

USE_COLOR=1
USE_ICONS=1
USE_LOGO=1
USE_IMAGE=0
LOGO_FILE=${CETCH_LOGO_FILE:-}
# empty = ASCII logo; "auto" = DistroLogos/<distro>; otherwise a file path
IMAGE_SRC=${CETCH_IMAGE:-}
IMAGE_SIZE=${CETCH_IMAGE_SIZE:-24}
IMAGE_PATH=
SIDE=0
SIDE_PAD=0
COLS_OVERRIDE=${CETCH_COLS:-}


usage() {
	cat <<'EOF'
cetch

Usage: cetch.sh [options]

Options:
  -w, --width N       render as if the terminal were N columns wide
      --accent        use terminal's accent color
      --color HEX     use a specific color (#7aa2f7, 7aa2f7 or #7af)
      --side [N]      place the logo to the left of the box, N extra
                      columns clear of it (default 0)
      --style STYLE   box style: rounded (default), boxy, or plain
                      to drop the box and just list the rows
      --palette NAME  colour swatches under the box: dots (default),
                      blocks, or none to leave them out
      --logo-file F   draw the ascii art in file F instead of the
                      built-in logo
      --image [SRC]   draw an image logo instead of ASCII; SRC is a
                      path, or "auto" for the built-in distro image
                      (default auto if SRC is omitted). needs chafa
      --image-size N  image width in terminal cells (default 24)
      --no-logo       draw the box on its own
      --no-color      monochrome output (--colour/--no-colour also work)
      --no-icons      drop the Nerd Font glyphs (plain labels)
      --list-distros  print the logo names CETCH_DISTRO accepts
  -h, --help          show this message

Environment:
  CETCH_DISTRO=id     force a logo (see --list-distros)
  CETCH_ROWS=a,b,c    pick the rows and their order (default:
                      user,kernel,os,wm,packages,disk); choose from
                      user, kernel, os, wm, packages, disk, uptime,
                      shell, memory, cpu, temp, ip
  CETCH_ICON_CELLS=2  if your terminal draws Nerd Font icons two cells wide
  CETCH_TITLE=text    box title (default "System Info")
  CETCH_MIN_WIDTH=n   minimum box width (default 42)
  CETCH_STYLE=name    same as --style
  CETCH_PALETTE=name  same as --palette
  CETCH_LOGO_FILE=f   same as --logo-file
  CETCH_IMAGE=src     same as --image (auto or a file path)
  CETCH_IMAGE_SIZE=n  same as --image-size
  CETCH_LOGOS_DIR=d   directory of built-in distro images (DistroLogos)
  CETCH_DISK=path     filesystem for the disk row (default /)
  CETCH_TEMP_ZONE=f   sysfs file for the temp row (default
                      /sys/class/thermal/thermal_zone0/temp)
  CETCH_COLS=n        same as --width
  CETCH_COLOR=hex     same as --color
  NO_COLOR=1          disable colour (https://no-color.org)

Config file:
  ~/.config/cetch/cetch.conf is created on first run with commented
  examples. Each line is either CETCH_VAR=value or a flag, as if typed
  on the command line. Uncomment CETCH_IMAGE=auto to enable images.
EOF
}

list_distros() {
	local d
	for d in $DISTROS; do printf '%s\n' "$d"; done
}

parse_args() {
	while (($#)); do
		case $1 in
		-w | --width)
			COLS_OVERRIDE=${2:-}
			shift
			;;
		--width=*) COLS_OVERRIDE=${1#*=} ;;
		--color | --colour)
			ACCENT_HEX=${2:-}
			shift
			;;
		--color=* | --colour=*) ACCENT_HEX=${1#*=} ;;
		--no-color | --no-colour) USE_COLOR=0 ;;
		--no-icons) USE_ICONS=0 ;;
		--no-logo) USE_LOGO=0 ;;
		--side)
			SIDE=1
			# the count is optional, so only eat the next word if it is one
			if [[ ${2:-} == +([0-9]) ]]; then
				SIDE_PAD=$2
				shift
			fi
			;;
		--side=*)
			SIDE=1
			SIDE_PAD=${1#*=}
			if [[ $SIDE_PAD != +([0-9]) ]]; then
				printf 'cetch: warning: ignoring invalid --side value %q\n' "$SIDE_PAD" >&2
				SIDE_PAD=0
			fi
			;;
		--style)
			STYLE=${2:-}
			shift
			;;
		--style=*) STYLE=${1#*=} ;;
		--palette)
			PALETTE=${2:-}
			shift
			;;
		--palette=*) PALETTE=${1#*=} ;;
		--logo-file)
			LOGO_FILE=${2:-}
			shift
			;;
		--logo-file=*) LOGO_FILE=${1#*=} ;;
		--image)
			# optional argument: bare --image means auto
			if [[ -n ${2:-} && $2 != -* ]]; then
				IMAGE_SRC=$2
				shift
			else
				IMAGE_SRC=auto
			fi
			;;
		--image=*) IMAGE_SRC=${1#*=} ;;
		--image-size)
			IMAGE_SIZE=${2:-}
			shift
			;;
		--image-size=*) IMAGE_SIZE=${1#*=} ;;
		--accent) USE_ACCENT=1 ;;
		--list-distros)
			list_distros
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

	NCOLORS=0
	if ((USE_COLOR)); then
		NCOLORS=$(tput colors 2>/dev/null)
		[[ $NCOLORS == +([0-9]) ]] || NCOLORS=8
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
}

get_term_accent_color() {
	local old_stty= reply=
	{
		old_stty=$(stty -g < /dev/tty) &&
		stty raw -echo < /dev/tty &&
		printf '\e]12;?\a' > /dev/tty &&
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

hex_to_escape() {
	local hex=${1#"#"}

	[[ $hex =~ ^([0-9A-Fa-f])([0-9A-Fa-f])([0-9A-Fa-f])$ ]] &&
		hex=${BASH_REMATCH[1]}${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}${BASH_REMATCH[3]}

	[[ $hex =~ ^[0-9A-Fa-f]{6}$ ]] || return 1

	local r=$((16#${hex:0:2}))
	local g=$((16#${hex:2:2}))
	local b=$((16#${hex:4:2}))

	printf '\e[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

setup_colors() {
	C_RESET=
	C_BOLD=
	C_ACCENT=

	((USE_COLOR)) || return 0

	C_RESET=$'\e[0m'
	C_BOLD=$'\e[1m'

	if [[ -n $ACCENT_HEX ]]; then
		if C_ACCENT=$(hex_to_escape "$ACCENT_HEX"); then
			return
		fi
		printf 'cetch: warning: ignoring invalid color %q, using the logo default\n' "$ACCENT_HEX" >&2
	fi

	if ((USE_ACCENT)); then
		local accent_color

		accent_color=$(get_term_accent_color)

		if [[ -n $accent_color ]] && C_ACCENT=$(hex_to_escape "$accent_color"); then
			return
		fi
	fi

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

# where the packaged / repo DistroLogos live. CETCH_LOGOS_DIR wins so
# packagers (nix, distro packages) can point at a share directory.
logos_dir() {
	local d src

	if [[ -n ${CETCH_LOGOS_DIR:-} ]]; then
		[[ -d $CETCH_LOGOS_DIR ]] || return 1
		printf '%s' "$CETCH_LOGOS_DIR"
		return 0
	fi

	src=${BASH_SOURCE[0]}
	# resolve one symlink hop so a ~/.local/bin/cetch link still finds
	# DistroLogos next to the real script
	[[ -L $src ]] && src=$(readlink -f -- "$src" 2>/dev/null || readlink -- "$src" 2>/dev/null || printf '%s' "$src")
	d=$(cd -- "$(dirname -- "$src")" 2>/dev/null && pwd) || d=
	if [[ -n $d && -d $d/DistroLogos ]]; then
		printf '%s' "$d/DistroLogos"
		return 0
	fi

	for d in \
		"${XDG_DATA_HOME:-${HOME:-}/.local/share}/cetch/DistroLogos" \
		/usr/local/share/cetch/DistroLogos \
		/usr/share/cetch/DistroLogos; do
		if [[ -d $d ]]; then
			printf '%s' "$d"
			return 0
		fi
	done
	return 1
}

# map distro_family id → filename inside DistroLogos/
distro_image_name() {
	case $1 in
	arch) printf 'Arch.png' ;;
	cachyos) printf 'Cachyos.png' ;;
	debian) printf 'Debian.png' ;;
	ubuntu) printf 'Ubuntu.png' ;;
	fedora) printf 'Fedora.png' ;;
	gentoo) printf 'Gentoo.png' ;;
	mint) printf 'Mint.png' ;;
	nixos) printf 'NixOS.png' ;;
	opensuse) printf 'Opensuse.png' ;;
	void) printf 'Void.png' ;;
	alpine) printf 'Alpine.png' ;;
	manjaro) printf 'Manjaro.png' ;;
	macos) printf 'MacOS.png' ;;
	*) printf 'lfs.png' ;; # generic tux-ish fallback
	esac
}

# expand ~, demand a regular readable file, reject anything odd. prints
# the cleaned path on success. never evals the path.
resolve_image_file() {
	local f=$1

	[[ -n $f ]] || return 1
	[[ $f == '~' || $f == '~/'* ]] && f=${HOME:-~}${f#'~'}

	# no command substitution / glob surprises from the config value —
	# we only ever open this as a pathname argument, quoted
	if [[ ! -e $f ]]; then
		printf 'cetch: warning: image not found: %q\n' "$1" >&2
		return 1
	fi
	if [[ -L $f ]]; then
		# follow one level so a normal symlink to a png is fine, but
		# still require the target to be a regular file
		f=$(readlink -f -- "$f" 2>/dev/null || readlink -- "$f" 2>/dev/null || printf '%s' "$f")
	fi
	if [[ ! -f $f || -d $f || ! -r $f ]]; then
		printf 'cetch: warning: image is not a readable regular file: %q\n' "$1" >&2
		return 1
	fi

	printf '%s' "$f"
}

# turn IMAGE_SRC (auto | path) into IMAGE_PATH. returns non-zero if we
# should stick with the ASCII logo.
resolve_image_src() {
	local src=$1 family dir name path

	[[ -n $src ]] || return 1

	case ${src,,} in
	auto | distro | yes | 1 | true)
		dir=$(logos_dir) || {
			printf 'cetch: warning: DistroLogos not found (set CETCH_LOGOS_DIR?), using the ASCII logo\n' >&2
			return 1
		}
		family=$(distro_family)
		name=$(distro_image_name "$family")
		path=$dir/$name
		if [[ ! -f $path ]]; then
			printf 'cetch: warning: no image for distro %q in %q, using the ASCII logo\n' "$family" "$dir" >&2
			return 1
		fi
		;;
	*)
		path=$(resolve_image_file "$src") || return 1
		;;
	esac

	IMAGE_PATH=$path
	return 0
}

# render IMAGE_PATH through chafa into LOGO[] as symbol cells, so the
# existing centering / --side layout keeps working without special cases
# for kitty/sixel cursor protocols
load_logo_image() {
	local f=$1 size=$2 i n start=0
	local -a lines

	if ! hash chafa 2>/dev/null; then
		printf 'cetch: warning: chafa not found; install chafa to use --image, using the ASCII logo\n' >&2
		return 1
	fi

	if [[ $size != +([0-9]) ]]; then
		printf 'cetch: warning: ignoring invalid --image-size %q, using 24\n' "$size" >&2
		size=24
	fi
	((size < 4)) && size=4
	((size > 120)) && size=120
	# keep the image from blowing past the terminal
	((size > COLS)) && size=$COLS
	((size < 4)) && size=4

	# -f symbols: cell output we can measure and center like ASCII art.
	# path is a single quoted argument — never interpolated into a shell.
	mapfile -t lines < <(chafa -f symbols -s "$size" -- "$f" 2>/dev/null) || true

	for i in ${lines[@]+"${!lines[@]}"}; do
		lines[i]=${lines[i]%$'\r'}
		lines[i]=${lines[i]%%*([[:space:]])}
	done

	n=${#lines[@]}
	while ((start < n)) && [[ -z ${lines[start]} ]]; do ((start++)); done
	while ((n > start)) && [[ -z ${lines[n - 1]} ]]; do ((n--)); done

	((n > start)) || {
		printf 'cetch: warning: chafa produced no output for %q, using the ASCII logo\n' "$f" >&2
		return 1
	}

	LOGO=("${lines[@]:start:n - start}")
	USE_IMAGE=1
	return 0
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
	packages | pkgs) row "$ICON_PKG" Packages "$(get_packages)" ;;
	disk) row "$ICON_DISK" Disk "$(get_disk)" ;;
	uptime) row "$ICON_UPTIME" Uptime "$(get_uptime)" ;;
	shell) row "$ICON_SHELL" Shell "$(get_shell)" ;;
	memory | mem | ram) row "$ICON_MEM" Memory "$(get_memory)" ;;
	cpu) row "$ICON_CPU" CPU "$(get_cpu)" ;;
	temp | temperature | cputemp) row "$ICON_TEMP" Temp "$(get_temp)" ;;
	ip | localip) row "$ICON_IP" 'Local IP' "$(get_ip)" ;;
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


LOGO_LINES=() BOX_LINES=() LOGO_W=0 BOX_W=0

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
	local line
	LOGO_LINES=()
	LOGO_W=0
	for line in "${LOGO[@]}"; do
		if ((USE_IMAGE)); then
			# chafa already sized + coloured the cells; do not _fit
			# (would slice mid-escape) or wrap in the accent colour
			LOGO_LINES+=("$line")
			vwidth "$line"
		else
			# a --logo-file can be any width, so keep it inside the terminal
			_fit "$line" "$COLS"
			LOGO_LINES+=("$C_BOLD$C_ACCENT$_S$C_RESET")
			vwidth "$_S"
		fi
		((_W > LOGO_W)) && LOGO_W=$_W
	done
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
		if [[ -z $bpart ]]; then
			printf '%*s%s\n' "$pad" '' "$lpart"
		else
			vwidth "$lpart"
			lw=$_W
			printf '%*s%s%*s%s\n' "$pad" '' "$lpart" $((LOGO_W - lw + LOGO_GAP)) '' "$bpart"
		fi
	done
}

render_palette() {
	local i sw line= gap=$DOT_GAP swatch=$DOT

	[[ $PALETTE == none ]] && return 0
	# blocks butt up against each other to read as one continuous bar
	[[ $PALETTE == blocks ]] && swatch=$BLOCK gap=

	vwidth "$swatch"
	sw=$_W
	while ((${#gap} > 0 && 8 * sw + 7 * ${#gap} > COLS)); do gap=${gap:1}; done
	for i in {0..7}; do
		if ((NCOLORS >= 16)); then
			line+=$'\e[38;5;'$((i + 8))'m'$swatch$C_RESET
		elif ((USE_COLOR)); then
			line+=$'\e[1;3'$i'm'$swatch$C_RESET
		else
			line+=$swatch
		fi
		((i < 7)) && line+=$gap
	done
	center "$line" $((8 * sw + 7 * ${#gap}))
}


main() {
	parse_args ${CONFIG_ARGS[@]+"${CONFIG_ARGS[@]}"} "$@"
	setup_style
	setup_term
	read_os_release
	load_logo "$(distro_family)"
	# image wins over an ascii --logo-file; both beat the built-in art
	if [[ -n $IMAGE_SRC ]] && resolve_image_src "$IMAGE_SRC"; then
		load_logo_image "$IMAGE_PATH" "$IMAGE_SIZE" || true
	elif [[ -n $LOGO_FILE ]]; then
		load_logo_file "$LOGO_FILE"
	fi
	setup_colors
	collect_info

	((USE_LOGO)) || SIDE=0
	((SIDE)) && LOGO_GAP=$((LOGO_GAP + SIDE_PAD))
	((USE_LOGO)) && build_logo_lines
	((SIDE && COLS - LOGO_W - LOGO_GAP < SIDE_MIN_BOX)) && SIDE=0

	blank 1
	if ((SIDE)); then
		build_box_lines $((COLS - LOGO_W - LOGO_GAP))
		render_side
	else
		if ((USE_LOGO)); then
			print_block "$LOGO_W" "${LOGO_LINES[@]}"
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
}

main "$@"
