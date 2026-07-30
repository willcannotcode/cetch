# cetch

A small terminal fastfetch-esque tool, in a single bash script. Info gets laid out vertically, and it is all horizontally centered.

<pre>
                      _-----_
                     (   0   \
                      \      )
                      /    _-
                     (____-

     ╭── System Info ─────────────────────────╮
     │ User                       will@gentoo │
     │ Kernel                  7.1.2-cachyos2 │
     │ OS                 Gentoo Linux x86_64 │
     │ WM/DE                   niri (Wayland) │
     │ Packages   1097 (portage), 8 (flatpak) │
     │ Disk                  90G / 220G (44%) │
     ╰────────────────────────────────────────╯

                  ● ● ● ● ● ● ● ●
</pre>

## Why

Most fetch tools lay information out in two columns next to a logo, which
looks great in a wide terminal and terrible in a narrow split. `cetch`
stacks the logo, an info box, and a color swatch, all centered, so it holds
up in a 40-column pane just as well as a full-width window.

## Requirements

- bash 4.0+
- coreutils (`df`, `tput` if you want proper column detection)
- a [Nerd Font](https://www.nerdfonts.com/) if you want the little icons —
  otherwise pass `--no-icons`

Nothing else. No Python, no external fetch library, no package to install.

## Install

```sh
curl -o cetch.sh https://raw.githubusercontent.com/willcannotcode/cetch/main/cetch.sh
chmod +x cetch.sh
./cetch.sh
```

Or just clone the repo:

```sh
git clone https://github.com/willcannotcode/cetch.git
cd cetch
./cetch.sh
```

Drop it somewhere on your `$PATH` (`~/.local/bin`, for instance) if you want
to run it as `cetch` from anywhere.

## Usage

```
cetch.sh [options]

  -w, --width N    render as if the terminal were N columns wide
      --no-color   monochrome output
      --no-icons   drop the Nerd Font glyphs (plain labels)
  -h, --help       show the help text
```

## Configuration

Everything is an environment variable, so you can drop overrides straight
into your shell rc file.

| Variable            | Effect                                                      |
| ------------------- | ------------------------------------------------------------ |
| `CETCH_DISTRO`      | force a logo (`arch`, `cachyos`, `debian`, `ubuntu`, `fedora`, `gentoo`, `mint`, `linux`) |
| `CETCH_ICON_CELLS`  | set to `2` if your terminal draws Nerd Font icons two cells wide |
| `CETCH_TITLE`       | box title, default `System Info`                             |
| `CETCH_MIN_WIDTH`   | minimum box width, default `42`                               |
| `CETCH_DISK`        | filesystem to report on for the Disk row, default `/`         |
| `CETCH_COLS`        | same as `--width`                                             |
| `NO_COLOR`          | disable color output ([no-color.org](https://no-color.org))   |

## Supported logos

Arch, CachyOS, Debian, Ubuntu, Fedora, Gentoo, and Mint get their own logo.
Anything else falls back to a generic Tux-ish face colored from
`/etc/os-release`'s `ANSI_COLOR`, so it still looks reasonable on distros
that aren't explicitly handled.

## Status

Early days — this has mostly been tested on my own machines. If something
breaks on your setup, open an issue with your distro, `$TERM`, and the
output you got.
