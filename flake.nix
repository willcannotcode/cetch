{
  description = "A small terminal fastfetch-esque tool, in a single bash script, all horizontally centered.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    inherit (nixpkgs) lib;

    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];

    forEachSystem = perSystem:
      lib.genAttrs systems (
        system:
          perSystem {
            pkgs = nixpkgs.legacyPackages.${system};
            inherit system;
          }
      );
  in {
    overlays.default = final: prev: {
      cetch = final.callPackage ./nix/package.nix {};
    };

    packages = forEachSystem ({pkgs, ...}: rec {
      cetch = pkgs.callPackage ./nix/package.nix {};
      default = cetch;
    });
  };
}
