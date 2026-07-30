# Cetch

A small terminal fastfetch-esque tool, in a single bash script, all horizontally centered.

<img width="687" height="485" alt="image" src="https://github.com/user-attachments/assets/c0af5f7a-2740-490b-879e-df4bb8319258" />
<img width="687" height="485" alt="image" src="https://github.com/user-attachments/assets/ca27cc85-15f0-48c0-9d80-fee99021a1b1" />

## Why?

Most fetch tools show a huge logo and pretty verbose information, which looks great in a wide terminal but looks terrible in a narrow split (such as on niri). `cetch` stacks the logo, an info box, and a colour swatch, all centered, so it looks just as good in a 40-column slice as it does in a full width window.

## Requirements

- bash 4.0+
- coreutils (`df`, `tput` if you want proper column detection)
- a [Nerd Font](https://www.nerdfonts.com/) if you want the little icons, otherwise pass `--no-icons`

## Install

On Arch (or anything with an AUR helper):

```sh
yay -S cetch
```

Otherwise, grab the script directly:

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

Put it somewhere on your `$PATH` (like `~/.local/bin`) if you want
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

Everything is an environment variable, so you can just add overrides to your shell rc file.

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
Anything else falls back to a generic Tux(ish) face colored from
`/etc/os-release`'s `ANSI_COLOR`, so it still looks reasonable on distros
that I haven't hardcoded.

## License

MIT, see [LICENSE](LICENSE).
