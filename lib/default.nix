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

  # turn a language's `module` *function* (`{ pkgs }: { packages, env, shellHook }`)
  # into the public-facing per-language lib that consumers reach as
  # `tendril.lib.<lang>`.
  #
  # consumers use `lib.<lang>.mkShell { pkgs = ...; extraPackages = [...]; }`
  # to extend the base shell without re-deriving it from scratch.
  mkLanguageLib = mkModule: {
    module = mkModule;
    mkShell =
      {
        pkgs,
        extraPackages ? [ ],
        extraEnv ? { },
        extraShellHook ? "",
      }:
      # call the canonical builder with the module evaluated for the
      # consumer's chosen `pkgs`.
      import ./mkShell.nix {
        inherit
          pkgs
          extraPackages
          extraEnv
          extraShellHook
          ;
        module = mkModule { inherit pkgs; };
      };
  };
}
