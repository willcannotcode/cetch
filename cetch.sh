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
USE_ACCENT=0
ACCENT_HEX=${CETCH_COLOR:-}

DEFAULT_ROWS=user,kernel,os,wm,packages,disk
ROWS=${CETCH_ROWS:-$DEFAULT_ROWS}
DISTROS='arch cachyos debian ubuntu fedora gentoo mint nixos opensuse void alpine manjaro linux'

BLANK_AFTER_LOGO=1
BLANK_BEFORE_DOTS=1
LOGO_GAP=3
SIDE_MIN_BOX=20

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
ICON_UPTIME=$'\xef\x80\x97'
ICON_SHELL=$'\xef\x84\xa0'
ICON_MEM=$'\xf3\xb0\x8d\x9b'
ICON_CPU=$'\xef\x8b\x9b'
ICON_IP=$'\xef\x82\xac'

USE_COLOR=1
USE_ICONS=1
USE_LOGO=1
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
      --no-logo       draw the box on its own
      --no-color      monochrome output
      --no-icons      drop the Nerd Font glyphs (plain labels)
      --list-distros  print the logo names CETCH_DISTRO accepts
  -h, --help          show this message

Environment:
  CETCH_DISTRO=id     force a logo (see --list-distros)
  CETCH_ROWS=a,b,c    pick the rows and their order (default:
                      user,kernel,os,wm,packages,disk); choose from
                      user, kernel, os, wm, packages, disk, uptime,
                      shell, memory, cpu, ip
  CETCH_ICON_CELLS=2  if your terminal draws Nerd Font icons two cells wide
  CETCH_TITLE=text    box title (default "System Info")
  CETCH_MIN_WIDTH=n   minimum box width (default 42)
  CETCH_DISK=path     filesystem for the disk row (default /)
  CETCH_COLS=n        same as --width
  CETCH_COLOR=hex     same as --color
  NO_COLOR=1          disable colour (https://no-color.org)
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
		printf linux
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
		vwidth "$line"
		((_W > LOGO_W)) && LOGO_W=$_W
	done
	for line in "${LOGO[@]}"; do
		LOGO_LINES+=("$C_BOLD$C_ACCENT$line$C_RESET")
	done
}

build_box_lines() {
	local maxw=$1
	local i n=${#LABELS[@]} icon_w=0 inner=0 need tw lw vw gap
	local icon label value line

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

render_dots() {
	local i line= gap=$DOT_GAP
	while ((${#gap} > 0 && 8 + 7 * ${#gap} > COLS)); do gap=${gap:1}; done
	for i in {0..7}; do
		if ((NCOLORS >= 16)); then
			line+=$'\e[38;5;'$((i + 8))'m'$DOT$C_RESET
		elif ((USE_COLOR)); then
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
	blank "$BLANK_BEFORE_DOTS"
	render_dots
	blank 1
}

main "$@"
