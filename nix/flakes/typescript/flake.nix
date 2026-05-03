# standalone typescript flake. directly consumable via:
#   nix develop github:rhizomatous/tendril?dir=nix/flakes/typescript
#   nix build   github:rhizomatous/tendril?dir=nix/flakes/typescript#packages.x86_64-linux.default
#
# also re-exported by the umbrella `flake.nix` at `nix/flake.nix`, so consumers
# pinning `github:rhizomatous/tendril?dir=nix` can reach this as
# `tendril.devShells.<sys>.typescript`, `tendril.lib.typescript`, and
# `tendril.packages.<linux-sys>.typescript`.
{
  description = "tendril typescript: node 24 dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # pull in the parent repo as a plain source tree so we can `import` the
    # shared `lib/` helpers and the IDE builder without duplicating either in
    # every sub-flake. `flake = false` means "don't evaluate as a flake, just
    # expose the files". this avoids circular flake evaluation and an unnecessary
    # lockfile input. the `path:../..` form works for both:
    #   - local dev: `nix develop ./nix/flakes/typescript`
    #   - published: `github:rhizomatous/tendril?dir=nix/flakes/typescript`
    # (in the published case, the whole repo is copied to the nix store, so
    # `../..` resolves to the parent within that store path.)
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

      # the IDE-specific nvim builder. signature: pkgs -> configured nvim.
      tendrilNvim = import "${tendril-root}/flakes/ide/build.nix" { inherit nixvim; };

      langLib = mkLanguageLib (import ./module.nix);

      # docker images need linux pkgs; see umbrella for the longer note.
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
            name = "tendril-typescript";
          };
        }
      );

      lib = langLib;
    };
}
