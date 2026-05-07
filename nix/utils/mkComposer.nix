# `{ nixvim } -> pkgs -> { coreTools, ide, agent, compose }`.
# centralizes tendril's kit composition,  so each flavour is
# composed the same way.
#
# composed kits are each evaluated once per call. the resulting
# derivations are shared across every wrapping invocation on that composer,
# so when the flake builds a per-language list of shells, every shell points
# at the same nvim/agent/core-tools derivations.
#
# usage:
#   composer = mkComposer pkgs;
#   composer.coreTools                                     # always-on baseline
#   composer.ide                                           # configured nvim (opt-in)
#   composer.agent                                         # OpenCode (opt-in)
#   composer.compose { [ langKits ]; withIde?; withAgent?; } -> composed kit list

{ nixvim }:

let
  ideKit = import ../kits/ide.nix { inherit nixvim; };
  coreToolsKit = import ../kits/core-tools.nix;
  agentKit = import ../kits/agent.nix;
in
pkgs:
let
  ide = ideKit { inherit pkgs; };
  coreTools = coreToolsKit { inherit pkgs; };
  agent = agentKit { inherit pkgs; };
in
{
  inherit coreTools ide agent;
  compose =
    {
      langKits,
      withIde ? true,
      withAgent ? true,
    }:
    [ coreTools ]
    ++ langKits
    ++ (if withIde then [ ide ] else [ ])
    ++ (if withAgent then [ agent ] else [ ]);
}
