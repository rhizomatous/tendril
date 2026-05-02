# standalone go flake. directly consumable via:
#   nix develop github:rhizomatous/tendril?dir=nix/flakes/go
#
# also re-exported by the umbrella `flake.nix` at `nix/flake.nix`, so consumers
# pinning `github:rhizomatous/tendril?dir=nix` can reach this as
# `tendril.devShells.<sys>.go` and `tendril.lib.go`.
{
  description = "tendril go: go 1.26 dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # see `flakes/typescript/flake.nix` for an explanation of `path:../..`.
    tendril-root = {
      url = "path:../..";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixvim,
      tendril-root,
    }:
    let
      tendrilLib = import "${tendril-root}/lib" { inherit nixpkgs; };
      inherit (tendrilLib) forAllSystems mkLanguageLib;

      tendrilNvim = import "${tendril-root}/flakes/ide/build.nix" { inherit nixvim; };

      langLib = mkLanguageLib (import ./module.nix);
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          nvim = tendrilNvim pkgs;
        in
        {
          default = langLib.mkShell { inherit pkgs nvim; };
        }
      );

      lib = langLib;
    };
}
