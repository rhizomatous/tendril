# standalone go flake. directly consumable via:
#   nix develop github:rhizomatous/tendril?dir=flakes/go
#
# also re-exported by the umbrella `flake.nix` at the repo root, so consumers
# pinning `github:rhizomatous/tendril` can reach this as
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
      inherit (tendrilLib) forAllSystems mkShell mkLanguageLib;

      mkModule = import ./module.nix;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkShell {
            inherit pkgs;
            module = mkModule { inherit pkgs; };
          };
        }
      );

      lib = mkLanguageLib mkModule;
    };
}
