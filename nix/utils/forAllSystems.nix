# given `system -> value`, returns
#   { aarch64-darwin = value; x86_64-linux = ...; ... }
# for all three supported systems.
#
# why: flake outputs like `devShells`, `packages`, `apps` are required to be
# keyed by system (`devShells.<system>.<name>`). this builds that shape from
# a single function so we don't write three near-identical blocks.
#
# usage:
#   devShells = forAllSystems (system: { default = ...; });

{ nixpkgs }:

# `nixpkgs.lib.genAttrs names f` builds `{ <name> = f name; ... }`.
# we partially apply it with the system list, returning a function that
# awaits the caller's `f`.
nixpkgs.lib.genAttrs [
  "aarch64-darwin"
  "x86_64-linux"
  "aarch64-linux"
]
