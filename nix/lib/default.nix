# tendril's internal helper library.
#
# takes `nixvim` so it can wire the ide kit into `mkComposer`.

{ nixpkgs, nixvim }:

{
  # the environment helper.
  forAllSystems = import ./forAllSystems.nix { inherit nixpkgs; };

  # `pkgs -> { coreTools, ide, agent, compose }`. the single source of truth
  # for language & ide composition; consumed by the flake outputs.
  mkComposer = import ./mkComposer.nix { inherit nixvim; };
}
