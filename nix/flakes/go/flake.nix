# standalone go flake.
{
  description = "tendril go: go 1.26 dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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
