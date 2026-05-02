# the nix dev environment, expressed as a reusable `module`.

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
