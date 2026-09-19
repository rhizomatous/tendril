# Build a dev shell from a list of `kit` attrsets.
#
# The list gets merged, then any consumer extras are layered on.

{
  pkgs,
  kits ? [ ],
  extraPackages ? [ ], # additional packages to add to the shell
  extraEnv ? { }, # additional env vars (override kit env on collision)
  extraShellHook ? "", # bash appended after the kits' shellHooks
}:

let
  mergeKits = import ../utils/mergeKits.nix { inherit (pkgs) lib; };
  merged = mergeKits kits;
in
pkgs.mkShell (
  {
    packages = merged.packages ++ extraPackages;
    shellHook = merged.shellHook + extraShellHook;
  }
  # kit env vars first, then consumer overrides.
  // merged.env
  // extraEnv
)
