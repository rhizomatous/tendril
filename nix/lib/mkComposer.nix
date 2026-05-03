# `pkgs -> { ide, withIde, withoutIde }`. centralizes the "language + ide"
# composition so the flake outputs and `mkLanguageLib` can't drift.
#
# nvim is evaluated once per call (per pkgs) and the resulting ide module is
# shared across every `withIde` invocation on that composer. so when the
# flake builds a per-language list of shells, every shell points at the same
# nvim derivation.
#
# usage:
#   composer = mkComposer pkgs;
#   composer.ide                       # evaluated ide module
#   composer.withIde langModule        # [ langModule ide ]
#   composer.withoutIde langModule     # [ langModule ]

{ nixvim }:

let
  ideModule = import ../modules/ide/module.nix { inherit nixvim; };
in
pkgs:
let
  ide = ideModule pkgs;
in
{
  inherit ide;
  withIde = langModule: [
    langModule
    ide
  ];
  withoutIde = langModule: [ langModule ];
}
