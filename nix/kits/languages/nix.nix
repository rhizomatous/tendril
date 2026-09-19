# The nix dev environment.

{ pkgs }:
{
  packages = with pkgs; [
    nixfmt # formatter (RFC 166 standard)
    nil # language server
    nix-tree # interactive closure inspector
  ];
}
