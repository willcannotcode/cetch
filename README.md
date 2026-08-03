# Cetch

A small terminal fastfetch-esque tool, in a single bash script, all horizontally centered.

<img width="628" height="430" alt="image" src="https://github.com/user-attachments/assets/2b90fdf7-222f-4d3e-a963-bcd709e5e501" />
<img width="840" height="308" alt="image" src="https://github.com/user-attachments/assets/0b67df72-2d63-4317-82b7-dd04583e3581" />

## Why?

Most fetch tools show a huge logo and pretty verbose information, which looks great in a wide terminal but looks terrible in a narrow split (such as on niri). `cetch` aligns the info vertically, all stacked and centered, so it looks just as good in a 40-column slice as it does in a full width window.

## Requirements

- bash 4.0+
- coreutils (`df`, `tput` if you want proper column detection)
- a [Nerd Font](https://www.nerdfonts.com/) if you want the little icons, otherwise pass `--no-icons`

## Install

On Arch (or anything with an AUR helper):

*Please note that the AUR is down because of the massive amounts of malware being pushed into it, so the aur package is stuck at v1.2.0 until this gets resolved*
```
yay -Sy cetch
```

Or grab the script directly:

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

**On NixOS (flakes)**

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
  outputs = { self, nixpkgs, cetch, ... }@inputs: {
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

## Usage

```
Usage: cetch.sh [options]

Options:
  -w, --width N      render as if the terminal were N columns wide
      --accent       use terminal's accent color
      --color HEX    use a specific color (#7aa2f7, 7aa2f7 or #7af)
      --side [N]     place the logo to the left of the box, N extra
                     columns clear of it (default 0)
      --style STYLE  box corner style: rounded (default) or boxy
      --no-logo      draw the box on its own
      --no-color     monochrome output (--colour/--no-colour also work)
      --no-icons     drop the Nerd Font glyphs (plain labels)
      --list-distros print the logo names CETCH_DISTRO accepts
  -h, --help         show this message
  ```

## Configuration
Everything is an environment variable, so you can just add overrides to your shell rc file.

| Variable | Effect |
| :--- | :--- |
| `CETCH_DISTRO` | force a logo (see `--list-distros` for accepted values) |
| `CETCH_ROWS` | comma-separated list of rows to display and their order.<br>Options: `user, kernel, os, wm, packages, disk, uptime, shell, memory, cpu, ip`<br>Default: `user,kernel,os,wm,packages,disk` |
| `CETCH_ICON_CELLS` | set to `2` if your terminal draws Nerd Font icons two cells wide |
| `CETCH_TITLE` | box title, default `System Info` |
| `CETCH_MIN_WIDTH` | minimum box width, default `42` |
| `CETCH_DISK` | filesystem to report on for the Disk row, default `/` |
| `CETCH_COLS` | same as `--width` |
| `CETCH_COLOR` | same as `--color` (e.g., `#7aa2f7`) |
| `NO_COLOR` | disable color output ([no-color.org](https://no-color.org)) |

## Supported logos
`Arch, CachyOS, Debian, Ubuntu, Fedora, Gentoo, Mint, NixOS, OpenSUSE, Void, Alpine, Manjaro, MacOS` all get their own logo.
Anything else falls back to a generic Tux(ish) face colored from
`/etc/os-release`'s `ANSI_COLOR`, so it still looks reasonable on distros
that I haven't hardcoded.

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

### Example

```
# ~/.config/cetch/cetch.conf
CETCH_TITLE="will@gentoo"
CETCH_ROWS=user,kernel,os,wm,packages,disk,uptime
--style boxy
--color 7aa2f7
```


## License

MIT, see [LICENSE](LICENSE).
