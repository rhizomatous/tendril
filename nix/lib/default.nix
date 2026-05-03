# tendril's internal helper library.
#
# takes `nixvim` so it can pre-build the configured nvim derivation and wire
# the ide module into `mkLanguageLib`. consumers of `lib.<lang>.mkShell`
# don't have to know about ide pieces.

{ nixpkgs, nixvim }:
# `rec` lets sibling attributes reference each other.
rec {
  # the environment helper.
  forAllSystems = import ./forAllSystems.nix { inherit nixpkgs; };

  # combine N modules into one.
  mergeModules = import ./mergeModules.nix { lib = nixpkgs.lib; };

  # the `modules -> devShell` builder.
  mkShell = import ./mkShell.nix { inherit mergeModules; };

  # the `modules -> docker image` builder; see ./mkDockerImage.nix.
  mkDockerImage = import ./mkDockerImage.nix { inherit mergeModules; };

  # the ide module (configured nvim + git). exposed so consumers composing
  # shells from raw modules can include it themselves; auto-included by
  # `mkLanguageLib`'s `mkShell` / `mkDockerImage`.
  ideModule = import ../modules/ide/module.nix;

  # `pkgs -> configured nvim derivation`. used by `mkLanguageLib` to build
  # nvim per-system without the consumer having to thread it through.
  tendrilNvim = import ../modules/ide/build.nix { inherit nixvim; };

  # the `mkModule -> { module, mkShell, mkDockerImage }` public-api adapter;
  # see ./mkLanguageLib.nix.
  mkLanguageLib = import ./mkLanguageLib.nix {
    inherit
      mkShell
      mkDockerImage
      ideModule
      tendrilNvim
      ;
  };
}
