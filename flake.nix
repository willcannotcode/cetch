{
  description = "A small terminal fastfetch-eque tool, in a single bash script, all horizontally centered.";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { 
    self,
    nixpkgs,
    flake-utils,
  }:
  flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
    in 
    {
      packages.default = pkgs.callPackage ./nix/package.nix { };

      apps.default = flake-utils.lib.mkApp {
        drv = self.packages.${system}.default;
      };
    }
  );
}
