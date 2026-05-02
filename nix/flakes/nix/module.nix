# the nix dev environment, expressed as a reusable `module`.
#
# composes the IDE module so the resulting shell has the configured nvim
# on PATH; `nil` is auto-attached by nvim's lsp config when present.

{ pkgs, nvim }:
let
  ideModule = import ../ide/module.nix;
  mergeModules = import ../../lib/mergeModules.nix { inherit (pkgs) lib; };
in
mergeModules [
  (ideModule { inherit pkgs nvim; })
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
