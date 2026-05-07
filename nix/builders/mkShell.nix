# build a dev shell from a list of `module` attrsets (plus optional consumer
# extras).
#
# `pkgs.mkShell` is nixpkgs' helper for declaring a development environment
# (the thing you enter via `nix develop`). it accepts:
#   - `packages`:  tools made available on PATH inside the shell
#   - `shellHook`: bash run on shell entry
#   - any other attribute name: exported as an env var inside the shell
#
# a `module` is the unit of reuse, shape:
#   { packages = [...]; env = { FOO = "bar"; }; shellHook = "..."; }
# we accept a list and merge them via `mergeModules`, then layer on consumer
# extras. taking a list lets the caller compose ide & language & whatever
# without re-deriving the merge logic.

{
  pkgs,
  modules ? [ ],
  extraPackages ? [ ], # additional packages to add to the shell
  extraEnv ? { }, # additional env vars (override module env on collision)
  extraShellHook ? "", # bash appended after the modules' shellHooks
}:

let
  mergeModules = import ../lib/mergeModules.nix { inherit (pkgs) lib; };
  merged = mergeModules modules;
in
pkgs.mkShell (
  {
    packages = merged.packages ++ extraPackages;
    shellHook = merged.shellHook + extraShellHook;
  }
  # `//` is nix's attrset-merge operator (right-hand wins on duplicate keys).
  # module env vars first, then consumer overrides.
  // merged.env
  // extraEnv
)
