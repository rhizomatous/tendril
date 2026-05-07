# the nix dev environment, expressed as a reusable `kit`.

{ pkgs }:
{
  # tools globally available on PATH inside the shell.
  packages = with pkgs; [
    nixfmt # formatter (RFC 166 standard)
    nil # language server
    nix-tree # interactive closure inspector
  ];
}
