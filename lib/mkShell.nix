# build a dev shell from a `module` attrset (plus optional consumer extras).
#
# `pkgs.mkShell` is nixpkgs' helper for declaring a development environment
# (the thing you enter via `nix develop`). it accepts:
#   - `packages`:  tools made available on PATH inside the shell
#   - `shellHook`: bash run on shell entry
#   - any other attribute name: exported as an env var inside the shell
#
# our `module` is the reusable per-language unit, shape:
#   { packages = [...]; env = { FOO = "bar"; }; shellHook = "..."; }
# we splat it into mkShell's call, then layer on the consumer's extras.

{ pkgs
, module
, extraPackages ? [ ]   # additional packages to add to the shell
, extraEnv ? { }        # additional env vars (override module env on collision)
, extraShellHook ? ""   # bash appended after the module's shellHook
}:

pkgs.mkShell (
  {
    packages = (module.packages or [ ]) ++ extraPackages;
    shellHook = (module.shellHook or "") + extraShellHook;
  }
  # `//` is nix's attrset-merge operator (right-hand wins on duplicate keys).
  # module env vars first, then consumer overrides.
  // (module.env or { })
  // extraEnv
)
