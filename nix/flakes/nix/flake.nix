# standalone nix flake.
{
  description = "tendril nix: nixfmt + nil + nix-tree dev shell";

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

      forLinuxSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
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

      packages = forLinuxSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          nvim = tendrilNvim pkgs;
        in
        {
          default = langLib.mkDockerImage {
            inherit pkgs nvim;
            name = "tendril-nix";
          };
        }
      );

      lib = langLib;
    };
}
