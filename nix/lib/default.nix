# tendril's internal helper library.
#
# takes `nixvim` so it can wire the ide module into `mkComposer`.
# consumers of `lib.<lang>.mkShell` don't have to know about ide pieces.

{ nixpkgs, nixvim }:

let
  # the environment helper.
  forAllSystems = import ./forAllSystems.nix { inherit nixpkgs; };

  # combine N modules into one.
  mergeModules = import ./mergeModules.nix { lib = nixpkgs.lib; };

  # the `modules -> devShell` builder.
  mkShell = import ./mkShell.nix { inherit mergeModules; };

  # the `modules -> docker image` builder; see ./mkDockerImage.nix.
  mkDockerImage = import ./mkDockerImage.nix { inherit mergeModules; };

  # `pkgs -> { ide, withIde, withoutIde }`. the single source of truth for
  # language+ide composition; consumed by both the flake outputs and
  # `mkLanguageLib`.
  mkComposer = import ./mkComposer.nix { inherit nixvim; };

  # the `mkModule -> { mkShell, mkDockerImage }` public-api adapter;
  # see ./mkLanguageLib.nix.
  mkLanguageLib = import ./mkLanguageLib.nix {
    inherit
      mkShell
      mkDockerImage
      mkComposer
      ;
  };
in
{
  inherit
    forAllSystems
    mkShell
    mkDockerImage
    mkComposer
    mkLanguageLib
    ;
}
