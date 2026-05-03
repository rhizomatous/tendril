# the typescript dev environment, expressed as a reusable `module`.
#
# a `module` is the unit of reuse in tendril: an attrset of
#   { packages, env ? {}, shellHook ? "" }
# builders consume modules; modules don't know which builder will use them.
#
# this file is a *function* `{ pkgs } -> module` — pkgs because nixpkgs is
# per-system. composition with the ide module happens at the builder layer
# (see `lib/mkLanguageLib.nix`); this module is language-only.

{ pkgs }:
{
  # tools globally available on PATH inside the shell.
  # node 24 LTS, with npm and corepack bundled.
  # `typescript-language-server` is here so nvim's lsp config (`ts_ls`) finds
  # a binary to attach to. project-specific tools (typescript, eslint,
  # prettier, vitest, ...) live in the consumer's `package.json`.
  packages = with pkgs; [
    nodejs_24
    typescript-language-server
  ];
}
