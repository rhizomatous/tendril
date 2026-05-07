# tendril's internal helper library.
#
# takes `nixvim` so it can wire the ide kit into `mkComposer`.

{ nixpkgs, nixvim }:

let
  # the environment helper.
  forAllSystems = import ./forAllSystems.nix { inherit nixpkgs; };

  # `pkgs -> { ide, withIde, withoutIde }`. the single source of truth for
  # language & ide composition; consumed by both the flake outputs and
  # `mkLanguageLib`.
  mkComposer = import ./mkComposer.nix { inherit nixvim; };

  # the `mkKit -> { mkShell, mkDockerImage }` public-api adapter.
  mkLanguageLib = import ./mkLanguageLib.nix { inherit mkComposer; };
in
{
  inherit
    forAllSystems
    mkComposer
    mkLanguageLib
    ;
}
