#!/usr/bin/env bash
((BASH_VERSINFO[0] >= 4)) || { echo "cetch: needs bash 4.0+, found $BASH_VERSION" >&2; exit 1; }
set -u
shopt -s extglob
shopt -s nullglob

BOX_TITLE=${CETCH_TITLE:-System Info}
BOX_MIN_WIDTH=${CETCH_MIN_WIDTH:-42}
LABEL_GAP=2
TITLE_DASHES=2
DISK_MOUNT=${CETCH_DISK:-/}

BLANK_AFTER_LOGO=1
BLANK_BEFORE_DOTS=1

DOT=●
DOT_GAP=' '

ICON_CELLS=${CETCH_ICON_CELLS:-1}
[[ $ICON_CELLS == +([0-9]) ]] || ICON_CELLS=1
((ICON_CELLS < 1)) && ICON_CELLS=1
((ICON_CELLS > 4)) && ICON_CELLS=4

B_TL=╭ B_TR=╮ B_BL=╰ B_BR=╯ B_V=│ B_H=─

ICON_USER=$'\xef\x80\x87'
ICON_KERNEL=$'\xf3\xb0\x8c\xbd'
ICON_OS=$'\xef\x85\xbc'
ICON_WM=$'\xef\x8b\x90'
ICON_PKG=$'\xef\x92\x87'
ICON_DISK=$'\xef\x82\xa0'

USE_COLOR=1
USE_ICONS=1
COLS_OVERRIDE=${CETCH_COLS:-}


usage() {
	cat <<'EOF'
cetch.sh — vertical, terminal-centred system info

Usage: cetch.sh [options]

Options:
  -w, --width N    render as if the terminal were N columns wide
      --no-color   monochrome output
      --no-icons   drop the Nerd Font glyphs (plain labels)
  -h, --help       show this message

Environment:
  CETCH_DISTRO=id     force a logo (arch, cachyos, debian, ubuntu,
                      fedora, gentoo, mint, linux) — handy for previewing
  CETCH_ICON_CELLS=2  if your terminal draws Nerd Font icons two cells wide
  CETCH_TITLE=text    box title (default "System Info")
  CETCH_MIN_WIDTH=n   minimum box width (default 42)
  CETCH_DISK=path     filesystem for the Disk row (default /)
  CETCH_COLS=n        same as --width
  NO_COLOR=1          disable colour (https://no-color.org)
EOF
}

parse_args() {
	while (($#)); do
		case $1 in
		-w | --width)
			COLS_OVERRIDE=${2:-}
			shift
			;;
		--width=*) COLS_OVERRIDE=${1#*=} ;;
		--no-color | --no-colour) USE_COLOR=0 ;;
		--no-icons) USE_ICONS=0 ;;
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

setup_colors() {
	C_RESET= C_BOLD= C_ACCENT=
	((USE_COLOR)) || return 0

	C_RESET=$'\e[0m'
	C_BOLD=$'\e[1m'
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
	arch | archarm | arcolinux | artix) printf arch ;;
	cachyos) printf cachyos ;;
	debian | raspbian | devuan) printf debian ;;
	ubuntu | pop | elementary | zorin | neon) printf ubuntu ;;
	fedora | nobara | rhel | centos | rocky | almalinux) printf fedora ;;
	gentoo | funtoo) printf gentoo ;;
	linuxmint | mint | lmde) printf mint ;;
	'')
		printf linux
		;;
	*)
		case ${OS_ID_LIKE,,} in
		*arch*) printf arch ;;
		*ubuntu*) printf ubuntu ;;
		*debian*) printf debian ;;
		*fedora* | *rhel*) printf fedora ;;
		*gentoo*) printf gentoo ;;
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

ICONS=() LABELS=() VALUES=()

row() {
	ICONS+=("$1")
	LABELS+=("$2")
	VALUES+=("$3")
}

collect_info() {
	row "$ICON_USER" User "$(get_user)"
	row "$ICON_KERNEL" Kernel "$(get_kernel)"
	row "$ICON_OS" OS "$(get_os)"
	row "$ICON_WM" WM/DE "$(get_wm)"
	row "$ICON_PKG" Packages "$(get_packages)"
	row "$ICON_DISK" Disk "$(get_disk)"
}


render_logo() {
	local line max=0 pad
	for line in "${LOGO[@]}"; do
		vwidth "$line"
		((_W > max)) && max=$_W
	done
	pad=$(((COLS - max) / 2))
	((pad < 0)) && pad=0
	for line in "${LOGO[@]}"; do
		printf '%*s%s%s%s\n' "$pad" '' "$C_BOLD$C_ACCENT" "$line" "$C_RESET"
	done
}

render_box() {
	local i n=${#LABELS[@]} icon_w=0 inner=0 need tw lw vw gap pad
	local icon label value

	((USE_ICONS)) && icon_w=$((ICON_CELLS + 1))

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
	((inner > COLS - 2)) && inner=$((COLS - 2))

	local title
	_fit "$BOX_TITLE" $((inner - TITLE_DASHES - 3))
	title=$_S
	vwidth "$title"
	tw=$_W

	pad=$(((COLS - inner - 2) / 2))
	((pad < 0)) && pad=0

	_rep "$B_H" "$TITLE_DASHES"
	local top=$_R
	_rep "$B_H" $((inner - TITLE_DASHES - tw - 2))
	printf '%*s%s%s%s %s%s%s %s%s%s%s\n' "$pad" '' \
		"$C_ACCENT" "$B_TL" "$top" \
		"$C_BOLD" "$title" "$C_RESET$C_ACCENT" \
		"$_R" "$B_TR" "$C_RESET"

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

		printf '%*s%s%s ' "$pad" '' "$C_ACCENT" "$B_V"
		((USE_ICONS)) && printf '%s ' "$icon"
		printf '%s%s%s%s%s %s%s%s\n' \
			"$label" "$_R" "$C_RESET$C_BOLD" "$value" "$C_RESET" \
			"$C_ACCENT" "$B_V" "$C_RESET"
	done

	_rep "$B_H" "$inner"
	printf '%*s%s%s%s%s%s\n' "$pad" '' "$C_ACCENT" "$B_BL" "$_R" "$B_BR" "$C_RESET"
}

render_dots() {
	local i line= gap=$DOT_GAP
	while ((${#gap} > 0 && 8 + 7 * ${#gap} > COLS)); do gap=${gap:1}; done
	for i in {0..7}; do
		if ((USE_COLOR)); then
			line+=$'\e[1;3'$i'm'$DOT$C_RESET
		else
			line+=$DOT
		fi
		((i < 7)) && line+=$gap
	done
	center "$line"
}


main() {
	parse_args "$@"
	setup_term
	read_os_release
	load_logo "$(distro_family)"
	setup_colors
	collect_info

	blank 1
	render_logo
	blank "$BLANK_AFTER_LOGO"
	render_box
	blank "$BLANK_BEFORE_DOTS"
	render_dots
	blank 1
}

main "$@"
