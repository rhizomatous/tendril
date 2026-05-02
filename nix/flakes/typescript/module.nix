# the typescript dev environment, expressed as a reusable `module`.
#
# a `module` is the unit of reuse in tendril: an attrset of
#   { packages, env, shellHook }
# builders consume modules; modules don't know which builder will use them.
#
# this file is a *function* `{ pkgs, nvim } -> module` — pkgs because nixpkgs
# is per-system, nvim because the configured nvim derivation is built once
# per system in lib (`tendrilNvim`) and threaded through.
#
# composes the IDE module via `mergeModules`, so the resulting shell has
# the configured nvim on PATH alongside the language toolchain.

{ pkgs, nvim }:
let
  ideModule = import ../ide/module.nix;
  mergeModules = import ../../lib/mergeModules.nix { inherit (pkgs) lib; };
in
mergeModules [
  (ideModule { inherit pkgs nvim; })
  {
    # tools globally available on PATH inside the shell.
    # node 24 LTS, with npm and corepack bundled.
    # `typescript-language-server` is here so nvim's lsp config (`ts_ls`)
    # finds a binary to attach to. project-specific tools (typescript,
    # eslint, prettier, vitest, ...) live in the consumer's `package.json`.
    packages = with pkgs; [
      nodejs_24
      typescript-language-server
    ];

    env = { };
    shellHook = "";
  }
]
