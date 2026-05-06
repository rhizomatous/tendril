# the ide module: the configured nvim derivation. composed into each
# tendril shell & image that opts in by `mkComposer`.
#
# shape: `{ nixvim } -> { pkgs } -> module`. takes nixvim once at lib-init
# time, then `pkgs` per-system at composition time. record-arg in both
# stages, matching the language and core-tools modules.

{ nixvim }:

{ pkgs }:
let
  nvim = nixvim.legacyPackages.${pkgs.system}.makeNixvimWithModule {
    inherit pkgs;
    module = import ./nixvim.nix;
  };
in
{
  packages = [ nvim ];
}
