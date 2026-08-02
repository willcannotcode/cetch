# Cetch

A small terminal fastfetch-esque tool, in a single bash script, all horizontally centered.

<img width="687" height="485" alt="image" src="https://github.com/user-attachments/assets/c0af5f7a-2740-490b-879e-df4bb8319258" />
<img width="687" height="485" alt="image" src="https://github.com/user-attachments/assets/ca27cc85-15f0-48c0-9d80-fee99021a1b1" />

## Why?

Most fetch tools show a huge logo and pretty verbose information, which looks great in a wide terminal but looks terrible in a narrow split (such as on niri). `cetch` aligns the info vertically, all stacked and centered, so it looks just as good in a 40-column slice as it does in a full width window.

## Requirements

- bash 4.0+
- coreutils (`df`, `tput` if you want proper column detection)
- a [Nerd Font](https://www.nerdfonts.com/) if you want the little icons, otherwise pass `--no-icons`

## Install

On Arch (or anything with an AUR helper):

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
cetch [options]
-w, --width N     render as if the terminal were N columns wide
--accent          use terminal's accent color
--color HEX       use a specific color (#7aa2f7, 7aa2f7 or #7af)
--side [N]        place the logo to the left of the box, N extra columns clear of it (default 0)
--no-logo         draw the box on its own
--no-color        monochrome output
--no-icons        drop the Nerd Font glyphs (plain labels)
--list-distros    print the logo names CETCH_DISTRO accepts
-h, --help        show this message
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
`Arch, CachyOS, Debian, Ubuntu, Fedora, Gentoo, Mint, NixOS, OpenSUSE, Void, Alpine, Manjaro` all get their own logo.
Anything else falls back to a generic Tux(ish) face colored from
`/etc/os-release`'s `ANSI_COLOR`, so it still looks reasonable on distros
that I haven't hardcoded.

## License

MIT, see [LICENSE](LICENSE).
