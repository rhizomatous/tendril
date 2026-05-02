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
      tendril-root,
    }:
    let
      tendrilLib = import "${tendril-root}/lib" { inherit nixpkgs; };
      inherit (tendrilLib) forAllSystems mkLanguageLib;

      langLib = mkLanguageLib (import ./module.nix);
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = langLib.mkShell { inherit pkgs; };
        }
      );

      lib = langLib;
    };
}
