# the ide kit: the configured nvim derivation. composed into each
# tendril shell & image that opts in by `mkComposer`.
#
# shape: `{ nixvim } -> { pkgs } -> kit`. takes nixvim once at lib-init
# time, then `pkgs` per-system at composition time. record-arg in both
# stages, matching the language and core-tools kits.

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
