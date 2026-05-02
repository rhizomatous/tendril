# the typescript dev environment, expressed as a reusable `module`.
#
# a `module` is the unit of reuse in tendril: an attrset of
#   { packages, env, shellHook }
# builders consume modules; modules don't know which builder will use them.
# today the only builder is `mkShell` (see `pkgs.mkShell`). future builders
# (`mkDockerImage`, `mkNixosModule`, ...) will reuse the same module unchanged.
#
# this file is a *function* `{ pkgs } -> module` because nixpkgs is per-system
# (the `nodejs_24` derivation for aarch64-darwin is not the same store path
# as for x86_64-linux). callers pass in the `pkgs` for their target system.
#
# composes the IDE module via `mergeModules`, so the resulting shell has
# an editor (neovim) on PATH alongside the language toolchain.

{ pkgs }:
let
  ideModule = import ../ide/module.nix;
  mergeModules = import ../../lib/mergeModules.nix { inherit (pkgs) lib; };
in
mergeModules [
  (ideModule { inherit pkgs; })
  {
    # tools globally available on PATH inside the shell.
    # node 24 LTS, with npm and corepack bundled.
    # project-specific tools (typescript, eslint, prettier, vitest, ...) live
    # in the consumer's `package.json`, so each project can pin its own versions.
    packages = with pkgs; [ nodejs_24 ];

    # env vars exported inside the shell. (none for TS so far.)
    env = { };

    # bash run on shell entry. (none for TS so far.)
    shellHook = "";
  }
]
