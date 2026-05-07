# build a dev shell from a list of `kit` attrsets (plus optional consumer
# extras).
#
# `pkgs.mkShell` is nixpkgs' helper for declaring a development environment
# (the thing you enter via `nix develop`). it accepts:
#   - `packages`:  tools made available on PATH inside the shell
#   - `shellHook`: bash run on shell entry
#   - any other attribute name: exported as an env var inside the shell
#
# a `kit` is the unit of reuse, shape:
#   { packages = [...]; env = { FOO = "bar"; }; shellHook = "..."; }
# we accept a list and merge them via `mergeKits`, then layer on consumer
# extras. taking a list lets the caller compose ide & language & whatever
# without re-deriving the merge logic.

{
  pkgs,
  kits ? [ ],
  extraPackages ? [ ], # additional packages to add to the shell
  extraEnv ? { }, # additional env vars (override kit env on collision)
  extraShellHook ? "", # bash appended after the kits' shellHooks
}:

let
  mergeKits = import ../lib/mergeKits.nix { inherit (pkgs) lib; };
  merged = mergeKits kits;
in
pkgs.mkShell (
  {
    packages = merged.packages ++ extraPackages;
    shellHook = merged.shellHook + extraShellHook;
  }
  # `//` is nix's attrset-merge operator (right-hand wins on duplicate keys).
  # kit env vars first, then consumer overrides.
  // merged.env
  // extraEnv
)
