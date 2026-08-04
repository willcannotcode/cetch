# Cetch

A small terminal fastfetch-esque tool, in a single bash script, all horizontally centered with dynamic sizing to avoid horrible line wraps.

<img width="737" height="443" alt="image" src="https://github.com/user-attachments/assets/e78b8de6-3d2d-4ee8-a0c8-384917c6a33e" />

*- See Examples/boxy for the config + ascii art*

<img width="903" height="837" alt="image" src="https://github.com/user-attachments/assets/d219f77f-351e-49b8-bafc-522e9bc4baaa" />

## Why?

Most fetch tools show a huge logo and pretty verbose information, which looks great in a wide terminal but looks terrible in a narrow split (such as on niri). `cetch` aligns the info vertically, all stacked and centered, so it looks just as good in a 40-column slice as it does in a full width window.
<details>
  <summary>Example</summary>
  <img width="1027" height="1018" alt="image" src="https://github.com/user-attachments/assets/3f1639b2-9686-40af-9ade-0cbbebc95f56" />
</details>

---

## Requirements

- bash 4.0+
- coreutils (`df`, `tput` if you want proper column detection)
- a [Nerd Font](https://www.nerdfonts.com/) if you want the little icons, otherwise pass `--no-icons`

Optional, only if you want the feature attached to it:

- `stty` - used to ask the terminal questions (`--accent`, and working out the cell size for `--image`)
- a terminal that speaks the [kitty graphics protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/) for `--image`
- `pci.ids` (usually the `hwdata` package) so the `gpu` row can print a model name instead of a bare PCI id

Everything else is read straight out of `/proc` and `/sys`, so there are no other runtime dependencies.

## Install

**On NixOS (flakes)**
<details>
  <summary>NixOS Installation</summary>
  Either run it using nix:

  ```
  nix run github:willcannotcode/cetch
  ```
  
  Or install it system-wide by adding it to your inputs:
  
  ```
  {
    inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  
      # Add this input to your flake
      cetch.url = "github:willcannotcode/cetch";
    };
  
    # example config of how to handle your outputs
    outputs = { self, nixpkgs, ... }@inputs: {
      nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
        ];
      };
    };
  }
  ```
  
  ...Then in configuration.nix add:
  
  
  ```
  { pkgs, inputs, ... }: {
    environment.systemPackages = [
      inputs.cetch.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  }
  ```
</details>

**On Arch (or anything with an AUR helper):**

*Please note that the AUR is down because of the massive amounts of malware being pushed into it, so the aur package is stuck at v1.2.0 until this gets resolved*
```
yay -Sy cetch
```

Or (universal) grab the script directly:

```sh
curl -o cetch.sh https://raw.githubusercontent.com/willcannotcode/cetch/main/cetch.sh
chmod +x cetch.sh
./cetch.sh
```

...or just clone the repo:

```sh
git clone https://github.com/willcannotcode/cetch.git
cd cetch
./cetch.sh
```

**Put it somewhere on your `$PATH` (like `~/.local/bin`) if you want to run it as `cetch` from anywhere.**

---

## Usage
**Usage:** `cetch.sh [options]`

### Options

| Short | Flag & Arguments | Description |
| :--- | :--- | :--- |
| `-w` | `--width N` | Render as if the terminal were `N` columns wide |
| | `--accent [SRC]` | Use a colour the terminal reports: `cursor` (default), `fg` or `bg` |
| | `--color HEX` | Use a specific color (`#7aa2f7`, `7aa2f7`, or `#7af`) |
| | `--theme NAME` | Use a named palette (see `--list-themes`); sets the accent *and* the swatches under the box |
| | `--gradient A-B` | Fade the logo from colour `A` to colour `B` down its lines (hex, same forms as `--color`) |
| | `--side [left\|right] [N]` | Place the logo beside the box, on the left by default, `N` extra columns clear of it (default 0) |
| | `--style STYLE` | Box style: `rounded` (default), `boxy`, or `plain` (to drop the box entirely) |
| | `--palette [NAME] [N]` | Colour swatches under the box: `dots` (default), `blocks`, or `none`. `N` is how many to show, `8` (default) or `16` |
| | `--json` | Print the rows as JSON and nothing else |
| | `--logo-file F` | Draw the ascii art from file F instead of the built-in logo |
| | `--image FILE` | Draw the PNG in FILE instead of the ascii art (needs a terminal with kitty graphics support) |
| | `--image-size S` | `auto` (default) to keep the image's own shape, `N` to set the width and let the height follow, or `WxH` to pin both cell counts |
| | `--no-logo` | Draw the box on its own |
| | `--no-color` | Monochrome output (`--colour`/`--no-colour` also work) |
| | `--no-icons` | Drop the Nerd Font glyphs (plain labels) |
| | `--list-distros` | Print the logo names `CETCH_DISTRO` accepts |
| | `--list-themes` | Print the names `--theme` accepts |
| `-h` | `--help` | Show this message |

Flags that take an optional argument (`--accent`, `--side`, `--palette`) also work in the
`--flag=value` form, and `--side`/`--palette` will take both of their values at once,
separated by a comma or a space:

```sh
cetch.sh --side right 4          # or --side=right,4
cetch.sh --palette blocks 16     # or --palette=blocks,16
cetch.sh --accent=fg
```

## Configuration
Everything is an environment variable, so you can just add overrides to your shell rc file.

| Variable | Effect |
| :--- | :--- |
| `CETCH_DISTRO` | force a logo (see `--list-distros` for accepted values) |
| `CETCH_ROWS` | comma-separated list of rows to display and their order (see [Rows](#rows))<br>Default: `user,kernel,os,wm,packages,disk` |
| `CETCH_ICON_CELLS` | set to `2` if your terminal draws Nerd Font icons two cells wide |
| `CETCH_TITLE` | box title, default `System Info` |
| `CETCH_MIN_WIDTH` | minimum box width, default `42` |
| `CETCH_STYLE` | same as `--style` |
| `CETCH_PALETTE` | same as `--palette` |
| `CETCH_PALETTE_N` | how many swatches, `8` (default) or `16` |
| `CETCH_THEME` | same as `--theme` |
| `CETCH_GRADIENT` | same as `--gradient` |
| `CETCH_LOGO_FILE` | same as `--logo-file` |
| `CETCH_IMAGE` | same as `--image` |
| `CETCH_IMAGE_SIZE` | same as `--image-size` |
| `CETCH_DISK` | filesystem to report on for the Disk row, default `/` |
| `CETCH_TEMP_ZONE` | sysfs file for the temp row, default `/sys/class/thermal/thermal_zone0/temp` |
| `CETCH_COLS` | same as `--width` |
| `CETCH_COLOR` | same as `--color` (e.g., `#7aa2f7`) |
| `NO_COLOR` | disable color output ([no-color.org](https://no-color.org)) |

## Rows

`CETCH_ROWS` picks which rows show up and in what order. Anything it doesn't
recognise is skipped with a warning, and any row that can't find its data on
your system prints `unknown` rather than disappearing.

| Row | Aliases | Shows |
| :--- | :--- | :--- |
| `user` | | `user@hostname` |
| `kernel` | | kernel release |
| `os` | | pretty name from `/etc/os-release` |
| `wm` | `wm/de`, `de` | window manager / desktop |
| `packages` | `pkgs` | package counts per manager |
| `disk` | | used / total and percent for `CETCH_DISK` |
| `uptime` | | how long the box has been up |
| `shell` | | `$SHELL` |
| `memory` | `mem`, `ram` | used / total and percent |
| `swap` | | used / total and percent, or `none` if there is no swap |
| `cpu` | | model name and core count |
| `cpufreq` | `freq` | current / max clock |
| `gpu` | | every PCI display device, named via `pci.ids` where possible |
| `temp` | `temperature`, `cputemp` | reading from `CETCH_TEMP_ZONE` |
| `ip` | `localip` | local address |
| `resolution` | `res`, `display` | mode of each enabled DRM connector |
| `terminal` | `term` | terminal emulator (env vars, else walking up the process tree) |
| `load` | `loadavg` | 1/5/15 minute load averages |
| `procs` | `processes` | number of processes |
| `init` | | whatever is running as PID 1 |

```sh
CETCH_ROWS=user,os,kernel,cpu,gpu,memory,swap,uptime cetch.sh
```

## Themes

`--theme NAME` sets the accent colour and replaces the swatches under the box
with the theme's own colours, so the palette shows the theme rather than
whatever your terminal happens to be configured with. With the default 8
swatches you get the bright half; `--palette 16` shows the lot.

`catppuccin` (aka `mocha`), `nord`, `gruvbox`, `dracula`, `tokyonight` (`tokyo-night`),
`everforest`, `rose-pine` (`rosepine`), `solarized`, `onedark` (`one-dark`).

`--list-themes` prints the same list.

```sh
cetch.sh --theme gruvbox --palette blocks 16
```

## Colors

There are four ways to set the accent, and if more than one is in play they're
tried in this order: `--color`, then `--accent`, then `--theme`, then the
logo's own default colour. Flags typed in the terminal are tried before the
same thing coming from the config file, so a `--theme` on the command line
beats a `CETCH_COLOR` in `cetch.conf`.

`--accent` asks the terminal itself what colour it's using (`cursor` by
default, or `fg`/`bg`). Terminals that don't answer are no problem, `cetch`
gives up after a moment and moves on to the next option in the list.

Any hex colour you hand it is tweaked to match what the terminal can actually
do: 24-bit escapes when truecolor is available (`COLORTERM`, a `*-direct*
TERM`, or `tput colors` saying so), the nearest xterm-256 colour when it isn't,
and the closest of the basic 8 as a last resort. So `--color`, `--theme` and
`--gradient` still look somewhat sensible in a 16-colour terminal instead of
printing junk.

`--gradient A-B` colours the logo only, fading line by line from `A` to `B`.
The box and the rows keep using the accent.

```sh
cetch.sh --gradient 7aa2f7-bb9af7
cetch.sh --accent fg
```

## Images

`--image FILE` swaps the ascii art out for a PNG, drawn with the kitty graphics
protocol. Compatible terminals include kitty, Ghostty, WezTerm, Konsole, Rio
and wayst. It works nicely with everything else: `--side` puts the image next
to the box, and the layout reserves the right number of rows so nothing
overlaps.

`--image-size` controls how big it lands:

- `auto` (default) - picks a height from the image's real aspect ratio, asking the terminal for its cell size to get it right
- `N` - `N` columns wide, height follows the aspect ratio
- `WxH` - exactly `W` columns by `H` rows, stretched to fit

The height is capped so the image plus the box still fits on screen.

A few things worth knowing:

- PNG only, since `cetch` reads the header itself to get the dimensions
- if the terminal can't draw it, the fetch is printed without a logo rather than swapping in ascii art you didn't ask for
- images can't work over SSH, because the terminal opens the file itself and it isn't on the same machine
- `--no-logo` still means no logo, image or not

```sh
cetch.sh --image ~/pics/logo.png --image-size 20 --side right 2
```

## JSON

`--json` prints the rows as JSON and stops there, ignoring the logo, colours,
box and palette entirely. Each row gets a `key` (its label lowercased, with
anything non-alphanumeric turned into `_`) alongside the label and value, and
rows that came back empty are left out.

```sh
$ cetch.sh --json
{
  "title": "System Info",
  "rows": [
    {"key": "user", "label": "User", "value": "will@gentoo"},
    {"key": "kernel", "label": "Kernel", "value": "7.1.2"},
    {"key": "os", "label": "OS", "value": "Gentoo Linux x86_64"},
    {"key": "wm_de", "label": "WM/DE", "value": "niri (Wayland)"},
    {"key": "packages", "label": "Packages", "value": "1097 (portage), 8 (flatpak)"},
    {"key": "disk", "label": "Disk", "value": "93G / 220G (45%)"}
  ]
}
```

It respects `CETCH_ROWS`, so `CETCH_ROWS=cpu,memory,load cetch.sh --json` is an
easy way to feed a status bar.

## Supported logos
`Arch, CachyOS, Debian, Ubuntu, Fedora, Gentoo, Mint, NixOS, OpenSUSE, Void, Alpine, Manjaro, MacOS` all get their own logo.
Anything else falls back to a generic Tux(ish) face colored from
`/etc/os-release`'s `ANSI_COLOR`, so it still looks reasonable on distros
that I haven't hardcoded.

---

## Config file

`cetch` reads `~/.config/cetch/cetch.conf` before it looks at anything you
typed.

Each line is one of:

- **`CETCH_VAR=value`** - sets one of the environment variables `cetch`
  already understands (see `cetch --help` for the full list). Values can
  also be wrapped in quotes, which is useful for anything with spaces:

  ```
  CETCH_TITLE="Will's Desktop"
  CETCH_ROWS=user,os,packages,disk
  ```

  This only affects the variable if it isn't *already* set in your shell
  environment, so `export CETCH_COLOR=...` in your `.bashrc`/`.zshrc` will always take effect over whatever the config file says.

- **Anything else** is treated exactly like if you 
  typed it in the terminal, before your actual arguments. You can put
  one flag per line or several on the same line:

  ```
  --style boxy
  --no-icons
  ```

  Because these are applied before your real arguments, a flag you type in
  the terminal always overrides the matching line in the config file.

Blank lines and lines starting with `#` are ignored:

```
# accent + box shape
CETCH_COLOR=7aa2f7
--style boxy

# cut down on some of the info
CETCH_ROWS=user,os,packages,disk
```

### Hierarchy, in order from most favoured to least.

1. Flags typed on in the terminal
2. `--flag` lines in the config file (applied as if typed, in file order)
3. `CETCH_VAR=value` variables already exported in your shell
4. `CETCH_VAR=value` lines in the config file
5. Whatever the default cetch value is

One thing worth knowing: a `CETCH_VAR` in your shell beats the `CETCH_VAR` in the config file, but it does **not** beat a `--flag` set in the config file, since flags always apply unconditionally, as if you had typed it yourself. If you want a config-file setting to win no matter what your shell has set, write it as a flag instead of a variable.

### Turning config-file switches back off

The one place the "config file first, then argv" rule isn't enough is the
off switches: `--no-color` in your config file would otherwise make
`cetch --theme nord` pointless, because the theme would be set and then never
drawn. So a flag on the command line wins over the switch that would cancel it:

- `--color`, `--accent`, `--theme` or `--gradient` on the command line turns colour back on over a `--no-color` in the config file
- `--image`, `--logo-file` or `--side` on the command line turns the logo back on over a `--no-logo` in the config file
- `--logo-file` on the command line clears an `--image`/`CETCH_IMAGE` from the config file, so you get the ascii art you just asked for

This only applies in that direction. `--no-color` typed in the terminal always
wins, and two flags that came from the same place are left alone.

### Example

```
# ~/.config/cetch/cetch.conf
CETCH_TITLE="will@gentoo"
CETCH_ROWS=user,kernel,os,wm,packages,disk,uptime,gpu,load
--theme tokyonight
--palette blocks 16
--side right 2
```
*better examples can be found in Examples. Examples/boxy is the config i personally use.*

## License

MIT, see [LICENSE](LICENSE).
