# standalone ide flake.
#
# consumers usually don't need to pin this directly. the IDE module is
# composed into every language shell built by tendril.
{
  description = "tendril ide: nixvim-built neovim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

      # local import — build.nix is a sibling.
      tendrilNvim = import ./build.nix { inherit nixvim; };

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
            name = "tendril-ide";
          };
        }
      );

      lib = langLib;
    };
}
