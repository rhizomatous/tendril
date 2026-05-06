# `pkgs -> { coreTools, ide, withIde, withoutIde }`. centralizes tendril's
# module composition so the flake outputs can't drift.
#
# nvim and the core-tools module are evaluated once per call. the resulting
# derivations are shared across every wrapping invocation on that composer,
# so when the flake builds a per-language list of shells, every shell points
# at the same nvim & core-tools derivations.
#
# usage:
#   composer = mkComposer pkgs;
#   composer.coreTools                 # evaluated core-tools module
#   composer.ide                       # evaluated ide module
#   composer.withIde langModule        # [ coreTools, langModule, ide ]
#   composer.withoutIde langModule     # [ coreTools, langModule ]

{ nixvim }:

let
  ideModule = import ../modules/ide/module.nix { inherit nixvim; };
  coreToolsModule = import ../modules/core-tools/module.nix;
in
pkgs:
let
  ide = ideModule { inherit pkgs; };
  coreTools = coreToolsModule { inherit pkgs; };
in
{
  inherit coreTools ide;
  withIde = langModule: [
    coreTools
    langModule
    ide
  ];
  withoutIde = langModule: [
    coreTools
    langModule
  ];
}
