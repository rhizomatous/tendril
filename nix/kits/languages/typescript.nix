# the typescript dev environment, expressed as a reusable `kit`.
#
# a `kit` is the unit of reuse in tendril: an attrset of
#   { packages, env ? {}, shellHook ? "" }
# builders consume kits; kits don't know which builder will use them.
#
# this file is a *function* `{ pkgs } -> kit` — pkgs because nixpkgs is
# per-system.

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
