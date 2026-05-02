# standalone ide flake. directly consumable via:
#   nix develop github:rhizomatous/tendril?dir=nix/flakes/ide
#
# consumers usually don't need to pin this directly. the IDE module is
# auto-composed into every language shell built by tendril.
{
  description = "tendril ide: neovim module";

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
