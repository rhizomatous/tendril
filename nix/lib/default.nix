# tendril's internal helper library.
#
# takes `nixvim` so it can wire the ide module into `mkComposer`.

{ nixpkgs, nixvim }:

let
  # the environment helper.
  forAllSystems = import ./forAllSystems.nix { inherit nixpkgs; };

  # `pkgs -> { ide, withIde, withoutIde }`. the single source of truth for
  # language & ide composition; consumed by both the flake outputs and
  # `mkLanguageLib`.
  mkComposer = import ./mkComposer.nix { inherit nixvim; };

  # the `mkModule -> { mkShell, mkDockerImage }` public-api adapter.
  mkLanguageLib = import ./mkLanguageLib.nix { inherit mkComposer; };
in
{
  inherit
    forAllSystems
    mkComposer
    mkLanguageLib
    ;
}
