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

  # `pkgs -> module` for the configured ide (nvim + git). consumed by
  # `mkComposer`; not exposed in the public flake `lib`.
  ideModule = import ../modules/ide/module.nix { inherit nixvim; };

  # `pkgs -> { ide, withIde, withoutIde }`. the single source of truth for
  # language+ide composition; consumed by both the flake outputs and
  # `mkLanguageLib`. see ./mkComposer.nix.
  mkComposer = import ./mkComposer.nix { inherit ideModule; };

  # the `mkModule -> { module, mkShell, mkDockerImage }` public-api adapter;
  # see ./mkLanguageLib.nix.
  mkLanguageLib = import ./mkLanguageLib.nix {
    inherit
      mkShell
      mkDockerImage
      mkComposer
      ;
  };
}
