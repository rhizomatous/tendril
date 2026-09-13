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
  # Language-server binaries live here so nvim can attach to them.
  packages = with pkgs; [
    nodejs_24
    typescript-language-server
    vscode-langservers-extracted
  ];
}
