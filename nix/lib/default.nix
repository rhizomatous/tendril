# tendril's internal helper library.
#
# imported by the umbrella `flake.nix` and by each `flakes/<lang>/flake.nix`
# (the latter via a `path:../..` flake input). single source of truth for the
# helpers that turn a per-language `module` into per-system flake outputs.
#
# `rec` lets sibling attributes reference each other.

{ nixpkgs }:
rec {
  # the environment helper
  forAllSystems = import ./forAllSystems.nix { inherit nixpkgs; };

  # the `module -> devShell` builder.
  mkShell = import ./mkShell.nix;

  # combine N modules into one (for polyglot shells); see ./mergeModules.nix.
  mergeModules = import ./mergeModules.nix { lib = nixpkgs.lib; };

  # the `module -> { module, mkShell }` public-api adapter; see ./mkLanguageLib.nix.
  mkLanguageLib = import ./mkLanguageLib.nix { inherit mkShell; };
}
