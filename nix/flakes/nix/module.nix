# the nix dev environment, expressed as a reusable `module`.
#
# composes the IDE module so the resulting shell has an editor on PATH.

{ pkgs }:
let
  ideModule = import ../ide/module.nix;
  mergeModules = import ../../lib/mergeModules.nix { inherit (pkgs) lib; };
in
mergeModules [
  (ideModule { inherit pkgs; })
  {
    # tools globally available on PATH inside the shell.
    packages = with pkgs; [
      nixfmt # formatter (RFC 166 standard)
      nil # language server
      nix-tree # interactive closure inspector
    ];

    env = { };
    shellHook = "";
  }
]
