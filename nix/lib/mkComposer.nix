# `{ nixvim } -> pkgs -> { coreTools, ide, agent, compose }`.
# centralizes tendril's module composition so the flake outputs and
# `mkLanguageLib` can't drift.
#
# composed modules are each evaluated once per call. the resulting
# derivations are shared across every wrapping invocation on that composer,
# so when the flake builds a per-language list of shells, every shell points
# at the same nvim/agent/core-tools derivations.
#
# usage:
#   composer = mkComposer pkgs;
#   composer.coreTools                                    # always-on baseline
#   composer.ide                                          # configured nvim (opt-in)
#   composer.agent                                        # opencode (opt-in)
#   composer.compose { langModule; withIde?; withAgent?; } -> composed module

{ nixvim }:

let
  ideModule = import ../modules/ide/module.nix { inherit nixvim; };
  coreToolsModule = import ../modules/core-tools/module.nix;
  agentModule = import ../modules/agent/module.nix;
in
pkgs:
let
  ide = ideModule { inherit pkgs; };
  coreTools = coreToolsModule { inherit pkgs; };
  agent = agentModule { inherit pkgs; };
in
{
  inherit coreTools ide agent;
  compose =
    {
      langModule,
      withIde ? true,
      withAgent ? true,
    }:
    [
      coreTools
      langModule
    ]
    ++ (if withIde then [ ide ] else [ ])
    ++ (if withAgent then [ agent ] else [ ]);
}
